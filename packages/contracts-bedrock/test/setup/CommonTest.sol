// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Forge
import { Test } from "forge-std/Test.sol";

// Testing
import { console2 as console } from "forge-std/console2.sol";
import { Setup } from "test/setup/Setup.sol";
import { Events } from "test/setup/Events.sol";
import { FFIInterface } from "test/setup/FFIInterface.sol";

// Scripts
import { DeployUtils } from "scripts/libraries/DeployUtils.sol";

// Contracts
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Libraries
import { Constants } from "src/libraries/Constants.sol";

// Interfaces
import { IOptimismMintableERC20Full } from "interfaces/universal/IOptimismMintableERC20Full.sol";
import { ILegacyMintableERC20Full } from "interfaces/legacy/ILegacyMintableERC20Full.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";

/// @title CommonTest
/// @dev An extenstion to `Test` that sets up the optimism smart contracts.
contract CommonTest is Test, Setup, Events {
    address alice;
    address bob;
    // [Kroma: START]
    address trusted;
    address asserter;
    address challenger;
    address delegator;
    address validatorRewardVault;
    address multisig;
    address withdrawAcc;
    // [Kroma: END]

    bytes32 constant nonZeroHash = keccak256(abi.encode("NON_ZERO"));

    FFIInterface constant ffi = FFIInterface(address(uint160(uint256(keccak256(abi.encode("optimism.ffi"))))));

    bool useAltDAOverride;
    bool useLegacyContracts;
    address customGasToken;
    bool useInteropOverride;

    ERC20 L1Token;
    ERC20 BadL1Token;
    IOptimismMintableERC20Full L2Token;
    ILegacyMintableERC20Full LegacyL2Token;
    ERC20 NativeL2Token;
    ERC20 BadL2Token;
    IOptimismMintableERC20Full RemoteL1Token;

    function setUp() public virtual override {
        enableLegacyContracts();

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        trusted = makeAddr("trusted");
        asserter = makeAddr("asserter");
        challenger = makeAddr("challenger");
        delegator = makeAddr("delegator");
        multisig = makeAddr("multisig");
        withdrawAcc = makeAddr("withdrawAcc");

        vm.deal(alice, 10000 ether);
        vm.deal(bob, 10000 ether);
        vm.deal(trusted, 10000 ether);
        vm.deal(asserter, 10000 ether);
        vm.deal(challenger, 10000 ether);
        vm.deal(delegator, 10000 ether);
        vm.deal(multisig, 10000 ether);

        Setup.setUp();

        // Override the config after the deploy script initialized the config
        if (useAltDAOverride) {
            deploy.cfg().setUseAltDA(true);
        }
        // We default to fault proofs unless explicitly disabled by useLegacyContracts
        if (!useLegacyContracts) {
            deploy.cfg().setUseFaultProofs(true);
        }
        if (customGasToken != address(0)) {
            deploy.cfg().setUseCustomGasToken(customGasToken);
        }
        if (useInteropOverride) {
            deploy.cfg().setUseInterop(true);
        }

        vm.etch(address(ffi), vm.getDeployedCode("FFIInterface.sol:FFIInterface"));
        vm.label(address(ffi), "FFIInterface");

        // Exclude contracts for the invariant tests
        excludeContract(address(ffi));
        excludeContract(address(deploy));
        excludeContract(address(deploy.cfg()));
        if (!useInteropOverride) {
            excludeContract(address(kromaDeploy));
            excludeContract(address(kromaDeploy.cfg()));
        }

        // Make sure the base fee is non zero
        vm.fee(1 gwei);

        // Set sane initialize block numbers
        vm.warp(deploy.cfg().l2OutputOracleStartingTimestamp() + 1);
        vm.roll(deploy.cfg().l2OutputOracleStartingBlockNumber() + 1);

        // Deploy L1
        Setup.L1();
        // Deploy L2
        Setup.L2();

        // Call bridge initializer setup function
        bridgeInitializerSetUp();

        // Setup validator
        setupValidator();
    }

    function setupValidator() internal {
        // Set up to give actors some amount
        assetToken.mint(trusted, deploy.cfg().validatorManagerMinActivateAmount() * 10);
        assetToken.mint(asserter, deploy.cfg().validatorManagerMinActivateAmount() * 10);
        assetToken.mint(challenger, deploy.cfg().validatorManagerMinActivateAmount() * 10);
        assetToken.mint(delegator, deploy.cfg().validatorManagerMinActivateAmount() * 10);

        // Set up validatorRewardVault
        assetToken.mint(deploy.cfg().assetManagerVault(), deploy.cfg().validatorManagerBaseReward() * 1000);

        // Give actors some ETH
        vm.deal(trusted, deploy.cfg().assetManagerBondAmount() * 10);
        vm.deal(asserter, deploy.cfg().assetManagerBondAmount() * 10);
        vm.deal(challenger, deploy.cfg().assetManagerBondAmount() * 10);

        // Allow AssetManager contract can get asset token from validatorRewardVault
        vm.startPrank(deploy.cfg().assetManagerVault());
        assetToken.approve(address(assetManager), deploy.cfg().validatorManagerBaseReward() * 1000);
        vm.stopPrank();

        // Set default output submitter as trusted
        uint256 trustedValidatorSlot = 9;
        vm.store(address(validatorManager), bytes32(trustedValidatorSlot), bytes32(uint256(uint160(trusted))));

        // update trusted validator
        registerValidator(trusted, deploy.cfg().validatorManagerMinActivateAmount() * 10);
        warpToSubmitTime();
        submitL2OutputV2(trusted, false);
    }

    function registerValidator(address validator, uint128 assets) internal {
        vm.startPrank(validator, validator);
        assetToken.approve(address(assetManager), uint256(assets));
        validatorManager.registerValidator(assets, 10, withdrawAcc);
        vm.stopPrank();
    }

    function statusToString(IValidatorManager.ValidatorStatus status) internal pure returns (string memory) {
        if (status == IValidatorManager.ValidatorStatus.NONE) return "NONE";
        if (status == IValidatorManager.ValidatorStatus.EXITED) return "EXITED";
        if (status == IValidatorManager.ValidatorStatus.REGISTERED) return "REGISTERED";
        if (status == IValidatorManager.ValidatorStatus.READY) return "READY";
        if (status == IValidatorManager.ValidatorStatus.INACTIVE) return "INACTIVE";
        if (status == IValidatorManager.ValidatorStatus.ACTIVE) return "ACTIVE";
        return "UNKNOWN";
    }

    function submitL2OutputV2(address submitter, bool isPublicRound) internal {
        uint256 nextBlockNumber = l2OutputOracle.nextBlockNumber();
        bytes32 outputRoot = keccak256(abi.encode(nextBlockNumber));

        if (!isPublicRound) {
            vm.prank(validatorManager.nextValidator());
        }

        IValidatorManager.ValidatorStatus status = validatorManager.getStatus(submitter);

        console.log("Validator status: %s", statusToString(status));
        vm.prank(submitter);
        l2OutputOracle.submitL2Output(outputRoot, nextBlockNumber, 0, 0);
    }

    function bridgeInitializerSetUp() public {
        L1Token = new ERC20("Native L1 Token", "L1T");

        LegacyL2Token = ILegacyMintableERC20Full(
            DeployUtils.create1({
                _name: "LegacyMintableERC20",
                _args: DeployUtils.encodeConstructor(
                    abi.encodeCall(
                        ILegacyMintableERC20Full.__constructor__,
                        (
                            address(l2StandardBridge),
                            address(L1Token),
                            string.concat("LegacyL2-", L1Token.name()),
                            string.concat("LegacyL2-", L1Token.symbol())
                        )
                    )
                )
            })
        );
        vm.label(address(LegacyL2Token), "LegacyMintableERC20");

        // Deploy the L2 ERC20 now
        L2Token = IOptimismMintableERC20Full(
            l2OptimismMintableERC20Factory.createStandardL2Token(
                address(L1Token),
                string(abi.encodePacked("L2-", L1Token.name())),
                string(abi.encodePacked("L2-", L1Token.symbol()))
            )
        );

        BadL2Token = ERC20(
            l2OptimismMintableERC20Factory.createStandardL2Token(
                address(1),
                string(abi.encodePacked("L2-", L1Token.name())),
                string(abi.encodePacked("L2-", L1Token.symbol()))
            )
        );

        NativeL2Token = new ERC20("Native L2 Token", "L2T");

        RemoteL1Token = IOptimismMintableERC20Full(
            l1OptimismMintableERC20Factory.createStandardL2Token(
                address(NativeL2Token),
                string(abi.encodePacked("L1-", NativeL2Token.name())),
                string(abi.encodePacked("L1-", NativeL2Token.symbol()))
            )
        );

        BadL1Token = ERC20(
            l1OptimismMintableERC20Factory.createStandardL2Token(
                address(1),
                string(abi.encodePacked("L1-", NativeL2Token.name())),
                string(abi.encodePacked("L1-", NativeL2Token.symbol()))
            )
        );
    }

    /// @dev Helper function that wraps `TransactionDeposited` event.
    ///      The magic `0` is the version.
    function emitTransactionDeposited(
        address _from,
        address _to,
        uint256 _mint,
        uint256 _value,
        uint64 _gasLimit,
        bool _isCreation,
        bytes memory _data
    )
        internal
    {
        emit TransactionDeposited(_from, _to, 0, abi.encodePacked(_mint, _value, _gasLimit, _isCreation, _data));
    }

    // Advance the evm's time to meet the L2OutputOracle's requirements for submitL2Output
    function warpToSubmitTime() public {
        vm.warp(l2OutputOracle.nextOutputMinL2Timestamp());
    }

    // @dev Advance the evm's time to meet the L2OutputOracle's requirements for proposeL2Output
    function warpToProposeTime(uint256 _nextBlockNumber) public {
        vm.warp(l2OutputOracle.computeL2Timestamp(_nextBlockNumber) + 1);
    }

    function enableLegacyContracts() public {
        // Check if the system has already been deployed, based off of the heuristic that alice and bob have not been
        // set by the `setUp` function yet.
        if (!(alice == address(0) && bob == address(0))) {
            revert("CommonTest: Cannot enable fault proofs after deployment. Consider overriding `setUp`.");
        }

        useLegacyContracts = true;
    }

    function enableAltDA() public {
        // Check if the system has already been deployed, based off of the heuristic that alice and bob have not been
        // set by the `setUp` function yet.
        if (!(alice == address(0) && bob == address(0))) {
            revert("CommonTest: Cannot enable altda after deployment. Consider overriding `setUp`.");
        }

        useAltDAOverride = true;
    }

    function enableCustomGasToken(address _token) public {
        // Check if the system has already been deployed, based off of the heuristic that alice and bob have not been
        // set by the `setUp` function yet.
        if (!(alice == address(0) && bob == address(0))) {
            revert("CommonTest: Cannot enable custom gas token after deployment. Consider overriding `setUp`.");
        }
        require(_token != Constants.ETHER);

        customGasToken = _token;
    }

    function enableInterop() public {
        // Check if the system has already been deployed, based off of the heuristic that alice and bob have not been
        // set by the `setUp` function yet.
        if (!(alice == address(0) && bob == address(0))) {
            revert("CommonTest: Cannot enable interop after deployment. Consider overriding `setUp`.");
        }

        useInteropOverride = true;
    }
}

contract MockKro is ERC20 {
    constructor() ERC20("Kroma", "KRO") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockKgh is ERC721 {
    constructor() ERC721("Test", "TST") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
