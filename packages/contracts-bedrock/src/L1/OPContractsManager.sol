// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Libraries
import { Blueprint } from "src/libraries/Blueprint.sol";
import { Constants } from "src/libraries/Constants.sol";
import { Claim, Duration, GameType, GameTypes } from "src/dispute/lib/Types.sol";

// Contracts
import { AssetManager } from "src/L1/AssetManager.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { SecurityCouncil } from "src/L1/SecurityCouncil.sol";
import { SystemConfig } from "src/L1/SystemConfig.sol";
import { ZKProofVerifier } from "src/L1/ZKProofVerifier.sol";

// Interfaces
import { ISemver } from "interfaces/universal/ISemver.sol";
import { IResourceMetering } from "interfaces/L1/IResourceMetering.sol";
import { IBigStepper } from "interfaces/dispute/IBigStepper.sol";
import { IDelayedWETH } from "interfaces/dispute/IDelayedWETH.sol";
import { IAnchorStateRegistry } from "interfaces/dispute/IAnchorStateRegistry.sol";
import { IDisputeGame } from "interfaces/dispute/IDisputeGame.sol";
import { IAddressManager } from "interfaces/legacy/IAddressManager.sol";
import { IProxyAdmin } from "interfaces/universal/IProxyAdmin.sol";
import { IDelayedWETH } from "interfaces/dispute/IDelayedWETH.sol";
import { IDisputeGameFactory } from "interfaces/dispute/IDisputeGameFactory.sol";
import { IAnchorStateRegistry } from "interfaces/dispute/IAnchorStateRegistry.sol";
import { IFaultDisputeGame } from "interfaces/dispute/IFaultDisputeGame.sol";
import { IPermissionedDisputeGame } from "interfaces/dispute/IPermissionedDisputeGame.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IProtocolVersions } from "interfaces/L1/IProtocolVersions.sol";
import { IOptimismPortal2 } from "interfaces/L1/IOptimismPortal2.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";
import { IL1CrossDomainMessenger } from "interfaces/L1/IL1CrossDomainMessenger.sol";
import { IL1ERC721Bridge } from "interfaces/L1/IL1ERC721Bridge.sol";
import { IL1StandardBridge } from "interfaces/L1/IL1StandardBridge.sol";
import { IOptimismMintableERC20Factory } from "interfaces/universal/IOptimismMintableERC20Factory.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { IOptimismPortal } from "interfaces/L1/IOptimismPortal.sol";
import { IL2OutputOracle } from "interfaces/L1/IL2OutputOracle.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";
import { ISP1Verifier } from "interfaces/vendor/sp1/ISP1Verifier.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";
import { IKromaGovernanceToken } from "interfaces/governance/IKromaGovernanceToken.sol";

contract OPContractsManager is ISemver {
    // -------- Structs --------

    /// @notice Represents the roles that can be set when deploying a standard OP Stack chain.
    struct Roles {
        address opChainProxyAdminOwner;
        address systemConfigOwner;
        address batcher;
        address unsafeBlockSigner;
        address proposer;
        address challenger;
    }

    /// @notice The full set of inputs to deploy a new OP Stack chain.
    struct DeployInput {
        Roles roles;
        uint32 basefeeScalar;
        uint32 blobBasefeeScalar;
        uint256 l2ChainId;
        // The correct type is AnchorStateRegistry.StartingAnchorRoot[] memory,
        // but OP Deployer does not yet support structs.
        bytes startingAnchorRoots;
        // The salt mixer is used as part of making the resulting salt unique.
        string saltMixer;
        uint64 gasLimit;
        // Configurable dispute game parameters.
        GameType disputeGameType;
        Claim disputeAbsolutePrestate;
        uint256 disputeMaxGameDepth;
        uint256 disputeSplitDepth;
        Duration disputeClockExtension;
        Duration disputeMaxClockDuration;
        // [Kroma: START]
        // Deploy configs for AssetManager.
        IERC721 kgh;
        address vault;
        uint128 minDelegationPeriod;
        uint128 bondAmount;
        // Deploy configs for Colosseum.
        IL2OutputOracle l2OutputOracle;
        uint256 submissionInterval;
        uint256 creationPeriodSeconds;
        uint256 bisectionTimeout;
        uint256 provingTimeout;
        uint256[] segmentsLengths;
        // Deploy configs for SecurityCouncil.
        uint256 timeLockMinDelaySeconds;
        // Deploy configs for UpgradeGovernor.
        uint256 initialVotingDelay;
        uint256 initialVotingPeriod;
        uint256 initialProposalThreshold;
        uint256 votesQuorumFraction;
        // Deploy configs for ValidatorManager.
        address trustedValidator;
        uint128 minRegisterAmount;
        uint128 minActivateAmount;
        uint128 commissionChangeDelaySeconds;
        uint128 roundDurationSeconds;
        uint128 softJailPeriodSeconds;
        uint128 hardJailPeriodSeconds;
        uint128 jailThreshold;
        uint128 maxFinalizations;
        uint128 baseReward;
    }
    // [Kroma: END]

    /// @notice The full set of outputs from deploying a new OP Stack chain.
    struct DeployOutput {
        IProxyAdmin opChainProxyAdmin;
        IAddressManager addressManager;
        IL1ERC721Bridge l1ERC721BridgeProxy;
        ISystemConfig systemConfigProxy;
        IOptimismMintableERC20Factory optimismMintableERC20FactoryProxy;
        IL1StandardBridge l1StandardBridgeProxy;
        IL1CrossDomainMessenger l1CrossDomainMessengerProxy;
        // Fault proof contracts below.
        IOptimismPortal2 optimismPortalProxy;
        IDisputeGameFactory disputeGameFactoryProxy;
        IAnchorStateRegistry anchorStateRegistryProxy;
        IAnchorStateRegistry anchorStateRegistryImpl;
        IFaultDisputeGame faultDisputeGame;
        IPermissionedDisputeGame permissionedDisputeGame;
        IDelayedWETH delayedWETHPermissionedGameProxy;
        IDelayedWETH delayedWETHPermissionlessGameProxy;
        // [Kroma: START]
        IAssetManager assetManagerProxy;
        IColosseum colosseumProxy;
        ISecurityCouncil securityCouncilProxy;
        ISecurityCouncilToken securityCouncilTokenProxy;
        ITimeLock timeLockProxy;
        IUpgradeGovernor upgradeGovernorProxy;
        IValidatorManager validatorManagerProxy;
        IZKProofVerifier zkProofVerifierProxy;
        IKromaGovernanceToken kromaGovernanceTokenProxy;
    }
    // [Kroma: END]

    /// @notice Addresses of ERC-5202 Blueprint contracts. There are used for deploying full size
    /// contracts, to reduce the code size of this factory contract. If it deployed full contracts
    /// using the `new Proxy()` syntax, the code size would get large fast, since this contract would
    /// contain the bytecode of every contract it deploys. Therefore we instead use Blueprints to
    /// reduce the code size of this contract.
    struct Blueprints {
        address addressManager;
        address proxy;
        address proxyAdmin;
        address l1ChugSplashProxy;
        address resolvedDelegateProxy;
        address anchorStateRegistry;
        address permissionedDisputeGame1;
        address permissionedDisputeGame2;
    }

    /// @notice The latest implementation contracts for the OP Stack.
    struct Implementations {
        address l1ERC721BridgeImpl;
        address optimismPortalImpl;
        address systemConfigImpl;
        address optimismMintableERC20FactoryImpl;
        address l1CrossDomainMessengerImpl;
        address l1StandardBridgeImpl;
        address disputeGameFactoryImpl;
        address delayedWETHImpl;
        address mipsImpl;
        // [Kroma: START]
        address assetManagerImpl;
        address colosseumImpl;
        address securityCouncilImpl;
        address securityCouncilTokenImpl;
        address timeLockImpl;
        address upgradeGovernorImpl;
        address validatorManagerImpl;
        address zkProofVerifierImpl;
    }
    // [Kroma: END]

    // -------- Constants and Variables --------

    /// @custom:semver 1.0.0-beta.25
    string public constant version = "1.0.0-beta.25";

    /// @notice Represents the interface version so consumers know how to decode the DeployOutput struct
    /// that's emitted in the `Deployed` event. Whenever that struct changes, a new version should be used.
    uint256 public constant OUTPUT_VERSION = 0;

    /// @notice Address of the SuperchainConfig contract shared by all chains.
    ISuperchainConfig public immutable superchainConfig;

    /// @notice Address of the ProtocolVersions contract shared by all chains.
    IProtocolVersions public immutable protocolVersions;

    /// @notice L1 smart contracts release deployed by this version of OPCM. This is used in opcm to signal which
    /// version of the L1 smart contracts is deployed. It takes the format of `op-contracts/vX.Y.Z`.
    string public l1ContractsRelease;

    /// @notice Addresses of the Blueprint contracts.
    /// This is internal because if public the autogenerated getter method would return a tuple of
    /// addresses, but we want it to return a struct.
    Blueprints internal blueprint;

    /// @notice Addresses of the latest implementation contracts.
    Implementations internal implementation;

    // -------- Events --------

    /// @notice Emitted when a new OP Stack chain is deployed.
    /// @param outputVersion Version that indicates how to decode the `deployOutput` argument.
    /// @param l2ChainId Chain ID of the new chain.
    /// @param deployer Address that deployed the chain.
    /// @param deployOutput ABI-encoded output of the deployment.
    event Deployed(
        uint256 indexed outputVersion, uint256 indexed l2ChainId, address indexed deployer, bytes deployOutput
    );

    // -------- Errors --------

    /// @notice Thrown when an address is the zero address.
    error AddressNotFound(address who);

    /// @notice Throw when a contract address has no code.
    error AddressHasNoCode(address who);

    /// @notice Thrown when a release version is already set.
    error AlreadyReleased();

    /// @notice Thrown when an invalid `l2ChainId` is provided to `deploy`.
    error InvalidChainId();

    /// @notice Thrown when a role's address is not valid.
    error InvalidRoleAddress(string role);

    /// @notice Thrown when the latest release is not set upon initialization.
    error LatestReleaseNotSet();

    /// @notice Thrown when the starting anchor roots are not provided.
    error InvalidStartingAnchorRoots();

    // -------- Methods --------

    constructor(
        ISuperchainConfig _superchainConfig,
        IProtocolVersions _protocolVersions,
        string memory _l1ContractsRelease,
        Blueprints memory _blueprints,
        Implementations memory _implementations
    ) {
        assertValidContractAddress(address(_superchainConfig));
        assertValidContractAddress(address(_protocolVersions));
        superchainConfig = _superchainConfig;
        protocolVersions = _protocolVersions;
        l1ContractsRelease = _l1ContractsRelease;

        blueprint = _blueprints;
        implementation = _implementations;
    }

    function deploy(DeployInput calldata _input) external returns (DeployOutput memory) {
        assertValidInputs(_input);
        uint256 l2ChainId = _input.l2ChainId;
        string memory saltMixer = _input.saltMixer;
        DeployOutput memory output;

        // -------- Deploy Chain Singletons --------

        // The ProxyAdmin is the owner of all proxies for the chain. We temporarily set the owner to
        // this contract, and then transfer ownership to the specified owner at the end of deployment.
        // The AddressManager is used to store the implementation for the L1CrossDomainMessenger
        // due to it's usage of the legacy ResolvedDelegateProxy.
        output.addressManager = IAddressManager(
            Blueprint.deployFrom(
                blueprint.addressManager, computeSalt(l2ChainId, saltMixer, "AddressManager"), abi.encode()
            )
        );
        output.opChainProxyAdmin = IProxyAdmin(
            Blueprint.deployFrom(
                blueprint.proxyAdmin, computeSalt(l2ChainId, saltMixer, "ProxyAdmin"), abi.encode(address(this))
            )
        );
        output.opChainProxyAdmin.setAddressManager(output.addressManager);

        // -------- Deploy Proxy Contracts --------

        // Deploy ERC-1967 proxied contracts.
        output.l1ERC721BridgeProxy =
            IL1ERC721Bridge(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "L1ERC721Bridge"));
        output.optimismPortalProxy =
            IOptimismPortal2(payable(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "OptimismPortal")));
        output.systemConfigProxy =
            ISystemConfig(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "SystemConfig"));
        output.optimismMintableERC20FactoryProxy = IOptimismMintableERC20Factory(
            deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "OptimismMintableERC20Factory")
        );
        output.disputeGameFactoryProxy =
            IDisputeGameFactory(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "DisputeGameFactory"));
        output.anchorStateRegistryProxy =
            IAnchorStateRegistry(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "AnchorStateRegistry"));

        // [Kroma: START]
        output.kromaGovernanceTokenProxy =
            IKromaGovernanceToken(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "KromaGovernanceToken"));
        output.assetManagerProxy =
            IAssetManager(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "AssetManager"));
        output.colosseumProxy = IColosseum(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "Colosseum"));
        output.securityCouncilProxy =
            ISecurityCouncil(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "SecurityCouncil"));
        output.securityCouncilTokenProxy =
            ISecurityCouncilToken(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "SecurityCouncilToken"));
        output.timeLockProxy =
            ITimeLock(payable(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "TimeLock")));
        output.upgradeGovernorProxy =
            IUpgradeGovernor(payable(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "UpgradeGovernor")));
        output.validatorManagerProxy =
            IValidatorManager(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "ValidatorManager"));
        output.zkProofVerifierProxy =
            IZKProofVerifier(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "ZKProofVerifier"));
        // [Kroma: END]

        // Deploy legacy proxied contracts.
        output.l1StandardBridgeProxy = IL1StandardBridge(
            payable(
                Blueprint.deployFrom(
                    blueprint.l1ChugSplashProxy,
                    computeSalt(l2ChainId, saltMixer, "L1StandardBridge"),
                    abi.encode(output.opChainProxyAdmin)
                )
            )
        );
        output.opChainProxyAdmin.setProxyType(address(output.l1StandardBridgeProxy), IProxyAdmin.ProxyType.CHUGSPLASH);
        string memory contractName = "OVM_L1CrossDomainMessenger";
        output.l1CrossDomainMessengerProxy = IL1CrossDomainMessenger(
            Blueprint.deployFrom(
                blueprint.resolvedDelegateProxy,
                computeSalt(l2ChainId, saltMixer, "L1CrossDomainMessenger"),
                abi.encode(output.addressManager, contractName)
            )
        );
        output.opChainProxyAdmin.setProxyType(
            address(output.l1CrossDomainMessengerProxy), IProxyAdmin.ProxyType.RESOLVED
        );
        output.opChainProxyAdmin.setImplementationName(address(output.l1CrossDomainMessengerProxy), contractName);
        // Now that all proxies are deployed, we can transfer ownership of the AddressManager to the ProxyAdmin.
        output.addressManager.transferOwnership(address(output.opChainProxyAdmin));
        // The AnchorStateRegistry Implementation is not MCP Ready, and therefore requires an implementation per chain.
        // It must be deployed after the DisputeGameFactoryProxy so that it can be provided as a constructor argument.
        output.anchorStateRegistryImpl = IAnchorStateRegistry(
            Blueprint.deployFrom(
                blueprint.anchorStateRegistry,
                computeSalt(l2ChainId, saltMixer, "AnchorStateRegistry"),
                abi.encode(output.disputeGameFactoryProxy)
            )
        );

        // Eventually we will switch from DelayedWETHPermissionedGameProxy to DelayedWETHPermissionlessGameProxy.
        output.delayedWETHPermissionedGameProxy = IDelayedWETH(
            payable(deployProxy(l2ChainId, output.opChainProxyAdmin, saltMixer, "DelayedWETHPermissionedGame"))
        );

        // While not a proxy, we deploy the PermissionedDisputeGame here as well because it's bespoke per chain.
        output.permissionedDisputeGame = IPermissionedDisputeGame(
            Blueprint.deployFrom(
                blueprint.permissionedDisputeGame1,
                blueprint.permissionedDisputeGame2,
                computeSalt(l2ChainId, saltMixer, "PermissionedDisputeGame"),
                encodePermissionedDisputeGameConstructor(_input, output)
            )
        );

        // -------- Set and Initialize Proxy Implementations --------
        bytes memory data;

        data = encodeL1ERC721BridgeInitializer(IL1ERC721Bridge.initialize.selector, output);
        upgradeAndCall(
            output.opChainProxyAdmin, address(output.l1ERC721BridgeProxy), implementation.l1ERC721BridgeImpl, data
        );

        data = encodeOptimismPortalInitializer(IOptimismPortal2.initialize.selector, output);
        upgradeAndCall(
            output.opChainProxyAdmin, address(output.optimismPortalProxy), implementation.optimismPortalImpl, data
        );

        // First we upgrade the implementation so it's version can be retrieved, then we initialize
        // it afterwards. See the comments in encodeSystemConfigInitializer to learn more.
        output.opChainProxyAdmin.upgrade(payable(address(output.systemConfigProxy)), implementation.systemConfigImpl);
        data = encodeSystemConfigInitializer(_input, output);
        upgradeAndCall(
            output.opChainProxyAdmin, address(output.systemConfigProxy), implementation.systemConfigImpl, data
        );

        data = encodeOptimismMintableERC20FactoryInitializer(IOptimismMintableERC20Factory.initialize.selector, output);
        upgradeAndCall(
            output.opChainProxyAdmin,
            address(output.optimismMintableERC20FactoryProxy),
            implementation.optimismMintableERC20FactoryImpl,
            data
        );

        data = encodeL1CrossDomainMessengerInitializer(IL1CrossDomainMessenger.initialize.selector, output);
        upgradeAndCall(
            output.opChainProxyAdmin,
            address(output.l1CrossDomainMessengerProxy),
            implementation.l1CrossDomainMessengerImpl,
            data
        );

        data = encodeL1StandardBridgeInitializer(IL1StandardBridge.initialize.selector, output);
        upgradeAndCall(
            output.opChainProxyAdmin, address(output.l1StandardBridgeProxy), implementation.l1StandardBridgeImpl, data
        );

        data = encodeDelayedWETHInitializer(IDelayedWETH.initialize.selector, _input);
        // Eventually we will switch from DelayedWETHPermissionedGameProxy to DelayedWETHPermissionlessGameProxy.
        upgradeAndCall(
            output.opChainProxyAdmin,
            address(output.delayedWETHPermissionedGameProxy),
            implementation.delayedWETHImpl,
            data
        );

        // We set the initial owner to this contract, set game implementations, then transfer ownership.
        data = encodeDisputeGameFactoryInitializer(IDisputeGameFactory.initialize.selector, _input);
        upgradeAndCall(
            output.opChainProxyAdmin,
            address(output.disputeGameFactoryProxy),
            implementation.disputeGameFactoryImpl,
            data
        );
        output.disputeGameFactoryProxy.setImplementation(
            GameTypes.PERMISSIONED_CANNON, IDisputeGame(address(output.permissionedDisputeGame))
        );
        output.disputeGameFactoryProxy.transferOwnership(address(_input.roles.opChainProxyAdminOwner));

        data = encodeAnchorStateRegistryInitializer(IAnchorStateRegistry.initialize.selector, _input);
        upgradeAndCall(
            output.opChainProxyAdmin,
            address(output.anchorStateRegistryProxy),
            address(output.anchorStateRegistryImpl),
            data
        );

        // [Kroma: START]
        data = encodeAssetManagerInitializer(_input, output);
        upgradeAndCall(
            output.opChainProxyAdmin, address(output.assetManagerProxy), implementation.assetManagerImpl, data
        );
        data = encodeColosseumInitializer(_input, output);
        upgradeAndCall(output.opChainProxyAdmin, address(output.colosseumProxy), implementation.colosseumImpl, data);
        data = encodeSecurityCouncilInitializer(_input, output);
        upgradeAndCall(
            output.opChainProxyAdmin, address(output.securityCouncilProxy), implementation.securityCouncilImpl, data
        );
        data = encodeSecurityCouncilTokenInitializer(_input, output);
        upgradeAndCall(
            output.opChainProxyAdmin,
            address(output.securityCouncilTokenProxy),
            implementation.securityCouncilTokenImpl,
            data
        );
        data = encodeTimeLockInitializer(_input, output);
        upgradeAndCall(output.opChainProxyAdmin, address(output.timeLockProxy), implementation.timeLockImpl, data);
        data = encodeUpgradeGovernorInitializer(_input, output);
        upgradeAndCall(
            output.opChainProxyAdmin, address(output.upgradeGovernorProxy), implementation.upgradeGovernorImpl, data
        );
        data = encodeValidatorManagerInitializer(_input, output);
        upgradeAndCall(
            output.opChainProxyAdmin, address(output.validatorManagerProxy), implementation.validatorManagerImpl, data
        );
        upgrade(output.opChainProxyAdmin, address(output.zkProofVerifierProxy), implementation.zkProofVerifierImpl);
        // [Kroma: END]

        // -------- Finalize Deployment --------
        // Transfer ownership of the ProxyAdmin from this contract to the specified owner.
        output.opChainProxyAdmin.transferOwnership(_input.roles.opChainProxyAdminOwner);

        emit Deployed(OUTPUT_VERSION, l2ChainId, msg.sender, abi.encode(output));
        return output;
    }

    // -------- Utilities --------

    /// @notice Verifies that all inputs are valid and reverts if any are invalid.
    /// Typically the proxy admin owner is expected to have code, but this is not enforced here.
    function assertValidInputs(DeployInput calldata _input) internal view {
        if (_input.l2ChainId == 0 || _input.l2ChainId == block.chainid) revert InvalidChainId();

        if (_input.roles.opChainProxyAdminOwner == address(0)) revert InvalidRoleAddress("opChainProxyAdminOwner");
        if (_input.roles.systemConfigOwner == address(0)) revert InvalidRoleAddress("systemConfigOwner");
        if (_input.roles.batcher == address(0)) revert InvalidRoleAddress("batcher");
        if (_input.roles.unsafeBlockSigner == address(0)) revert InvalidRoleAddress("unsafeBlockSigner");
        if (_input.roles.proposer == address(0)) revert InvalidRoleAddress("proposer");
        if (_input.roles.challenger == address(0)) revert InvalidRoleAddress("challenger");

        if (_input.startingAnchorRoots.length == 0) revert InvalidStartingAnchorRoots();
    }

    /// @notice Maps an L2 chain ID to an L1 batch inbox address as defined by the standard
    /// configuration's convention. This convention is `versionByte || keccak256(bytes32(chainId))[:19]`,
    /// where || denotes concatenation`, versionByte is 0x00, and chainId is a uint256.
    /// https://specs.optimism.io/protocol/configurability.html#consensus-parameters
    function chainIdToBatchInboxAddress(uint256 _l2ChainId) public pure returns (address) {
        bytes1 versionByte = 0x00;
        bytes32 hashedChainId = keccak256(bytes.concat(bytes32(_l2ChainId)));
        bytes19 first19Bytes = bytes19(hashedChainId);
        return address(uint160(bytes20(bytes.concat(versionByte, first19Bytes))));
    }

    /// @notice Helper method for computing a salt that's used in CREATE2 deployments.
    /// Including the contract name ensures that the resultant address from CREATE2 is unique
    /// across our smart contract system. For example, we deploy multiple proxy contracts
    /// with the same bytecode from this contract, so they need different salts to avoid an address collision
    function computeSalt(
        uint256 _l2ChainId,
        string memory _saltMixer,
        string memory _contractName
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_l2ChainId, _saltMixer, _contractName));
    }

    /// @notice Deterministically deploys a new proxy contract owned by the provided ProxyAdmin.
    /// The salt is computed as a function of the L2 chain ID, the salt mixer and the contract name.
    /// This is required because we deploy many identical proxies, so they each require a unique salt for determinism.
    function deployProxy(
        uint256 _l2ChainId,
        IProxyAdmin _proxyAdmin,
        string memory _saltMixer,
        string memory _contractName
    )
        internal
        returns (address)
    {
        bytes32 salt = computeSalt(_l2ChainId, _saltMixer, _contractName);
        return Blueprint.deployFrom(blueprint.proxy, salt, abi.encode(_proxyAdmin));
    }

    /// @notice Returns the deterministically computed contract address
    /// that will be deployed by the deployProxy function.
    function computeDeployProxy(
        uint256 _l2ChainId,
        address owner,
        string memory _saltMixer,
        string memory _contractName,
        address _bluePrintTarget,
        address deployer
    )
        public
        view
        returns (address)
    {
        bytes32 salt = computeSalt(_l2ChainId, _saltMixer, _contractName);
        return Blueprint.computeDeployAddress(_bluePrintTarget, salt, abi.encode(owner), deployer);
    }

    // -------- Initializer Encoding --------

    /// @notice Helper method for encoding the L1ERC721Bridge initializer data.
    function encodeL1ERC721BridgeInitializer(
        bytes4 _selector,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        return abi.encodeWithSelector(_selector, _output.l1CrossDomainMessengerProxy, superchainConfig);
    }

    /// @notice Helper method for encoding the OptimismPortal initializer data.
    function encodeOptimismPortalInitializer(
        bytes4 _selector,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            _selector,
            _output.disputeGameFactoryProxy,
            _output.systemConfigProxy,
            superchainConfig,
            GameTypes.PERMISSIONED_CANNON
        );
    }

    /// @notice Helper method for encoding the SystemConfig initializer data.
    function encodeSystemConfigInitializer(
        DeployInput memory _input,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = ISystemConfig.initialize.selector;
        (IResourceMetering.ResourceConfig memory referenceResourceConfig, ISystemConfig.Addresses memory opChainAddrs) =
            defaultSystemConfigParams(selector, _input, _output);

        return abi.encodeWithSelector(
            selector,
            _input.roles.systemConfigOwner,
            _input.basefeeScalar,
            _input.blobBasefeeScalar,
            bytes32(uint256(uint160(_input.roles.batcher))), // batcherHash
            _input.gasLimit,
            _input.roles.unsafeBlockSigner,
            referenceResourceConfig,
            chainIdToBatchInboxAddress(_input.l2ChainId),
            opChainAddrs
        );
    }

    /// @notice Helper method for encoding the OptimismMintableERC20Factory initializer data.
    function encodeOptimismMintableERC20FactoryInitializer(
        bytes4 _selector,
        DeployOutput memory _output
    )
        internal
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encodeWithSelector(_selector, _output.l1StandardBridgeProxy);
    }

    /// @notice Helper method for encoding the L1CrossDomainMessenger initializer data.
    function encodeL1CrossDomainMessengerInitializer(
        bytes4 _selector,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(_selector, superchainConfig, _output.optimismPortalProxy, _output.systemConfigProxy);
    }

    /// @notice Helper method for encoding the L1StandardBridge initializer data.
    function encodeL1StandardBridgeInitializer(
        bytes4 _selector,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            _selector, _output.l1CrossDomainMessengerProxy, superchainConfig, _output.systemConfigProxy
        );
    }

    function encodeDisputeGameFactoryInitializer(
        bytes4 _selector,
        DeployInput memory
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        // This contract must be the initial owner so we can set game implementations, then
        // ownership is transferred after.
        return abi.encodeWithSelector(_selector, address(this));
    }

    function encodeAnchorStateRegistryInitializer(
        bytes4 _selector,
        DeployInput memory _input
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        // this line fails in the op-deployer tests because it is not passing in any data
        IAnchorStateRegistry.StartingAnchorRoot[] memory startingAnchorRoots =
            abi.decode(_input.startingAnchorRoots, (IAnchorStateRegistry.StartingAnchorRoot[]));
        return abi.encodeWithSelector(_selector, startingAnchorRoots, superchainConfig);
    }

    function encodeDelayedWETHInitializer(
        bytes4 _selector,
        DeployInput memory _input
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        return abi.encodeWithSelector(_selector, _input.roles.opChainProxyAdminOwner, superchainConfig);
    }

    function encodePermissionedDisputeGameConstructor(
        DeployInput memory _input,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        return abi.encode(
            _input.disputeGameType,
            _input.disputeAbsolutePrestate,
            _input.disputeMaxGameDepth,
            _input.disputeSplitDepth,
            _input.disputeClockExtension,
            _input.disputeMaxClockDuration,
            IBigStepper(implementation.mipsImpl),
            IDelayedWETH(payable(address(_output.delayedWETHPermissionedGameProxy))),
            IAnchorStateRegistry(address(_output.anchorStateRegistryProxy)),
            _input.l2ChainId,
            _input.roles.proposer,
            _input.roles.challenger
        );
    }

    // [Kroma: START]

    /// @notice Helper method for encoding the AssetManager initializer data.
    function encodeAssetManagerInitializer(
        DeployInput memory _input,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = IAssetManager.initialize.selector;

        return abi.encodeWithSelector(
            selector,
            _output.kromaGovernanceTokenProxy,
            _input.kgh,
            _output.securityCouncilProxy,
            _input.vault,
            _output.validatorManagerProxy,
            _input.minDelegationPeriod,
            _input.bondAmount
        );
    }

    /// @notice Helper method for encoding the Colosseum initializer data.
    function encodeColosseumInitializer(
        DeployInput memory _input,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = IColosseum.initialize.selector;

        return abi.encodeWithSelector(
            selector,
            _input.l2OutputOracle,
            _output.zkProofVerifierProxy,
            _output.securityCouncilProxy,
            _input.submissionInterval,
            _input.creationPeriodSeconds,
            _input.bisectionTimeout,
            _input.provingTimeout,
            _input.segmentsLengths
        );
    }

    /// @notice Helper method for encoding the SecurityCouncil initializer data.
    function encodeSecurityCouncilInitializer(
        DeployInput memory,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = SecurityCouncil.initialize.selector;

        return abi.encodeWithSelector(selector, _output.colosseumProxy, _output.upgradeGovernorProxy);
    }

    /// @notice Helper method for encoding the SecurityCouncilToken initializer data.
    function encodeSecurityCouncilTokenInitializer(
        DeployInput memory,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = ISecurityCouncilToken.initialize.selector;

        return abi.encodeWithSelector(selector, _output.upgradeGovernorProxy);
    }

    /// @notice Helper method for encoding the TimeLock initializer data.
    function encodeTimeLockInitializer(
        DeployInput memory _input,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = ITimeLock.initialize.selector;
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(_output.upgradeGovernorProxy);
        executors[0] = address(_output.upgradeGovernorProxy);

        return abi.encodeWithSelector(
            selector, _input.timeLockMinDelaySeconds, proposers, executors, address(_output.upgradeGovernorProxy)
        );
    }

    /// @notice Helper method for encoding the UpgradeGovernor initializer data.
    function encodeUpgradeGovernorInitializer(
        DeployInput memory _input,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = IUpgradeGovernor.initialize.selector;
        return abi.encodeWithSelector(
            selector,
            _output.securityCouncilTokenProxy,
            _output.timeLockProxy,
            _input.initialVotingDelay,
            _input.initialVotingPeriod,
            _input.initialProposalThreshold,
            _input.votesQuorumFraction
        );
    }

    /// @notice Helper method for encoding the ValidatorManager initializer data.
    function encodeValidatorManagerInitializer(
        DeployInput memory _input,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = IValidatorManager.initialize.selector;

        IValidatorManager.InitializationParams memory params = IValidatorManager.InitializationParams({
            _l2Oracle: _input.l2OutputOracle,
            _assetManager: IAssetManager(_output.assetManagerProxy),
            _trustedValidator: _input.trustedValidator,
            _commissionChangeDelaySeconds: _input.commissionChangeDelaySeconds,
            _roundDurationSeconds: _input.roundDurationSeconds,
            _softJailPeriodSeconds: _input.softJailPeriodSeconds,
            _hardJailPeriodSeconds: _input.hardJailPeriodSeconds,
            _jailThreshold: _input.jailThreshold,
            _maxOutputFinalizations: _input.maxFinalizations,
            _baseReward: _input.baseReward,
            _minRegisterAmount: _input.minRegisterAmount,
            _minActivateAmount: _input.minActivateAmount
        });

        return abi.encodeWithSelector(selector, params);
    }

    /// @notice Helper method for encoding the KromaGovernanceToken initializer data.
    function encodeKromaGovernanceTokenrInitializer(
        DeployInput memory _input,
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes4 selector = IKromaGovernanceToken.initialize.selector;
        return abi.encodeWithSelector(
            selector,
            _output.securityCouncilTokenProxy,
            _output.timeLockProxy,
            _input.initialVotingDelay,
            _input.initialVotingPeriod,
            _input.initialProposalThreshold,
            _input.votesQuorumFraction
        );
    }

    // [Kroma: END]

    /// @notice Returns default, standard config arguments for the SystemConfig initializer.
    /// This is used by subclasses to reduce code duplication.
    function defaultSystemConfigParams(
        bytes4, /* selector */
        DeployInput memory, /* _input */
        DeployOutput memory _output
    )
        internal
        view
        virtual
        returns (IResourceMetering.ResourceConfig memory resourceConfig_, ISystemConfig.Addresses memory opChainAddrs_)
    {
        // We use assembly to easily convert from IResourceMetering.ResourceConfig to ResourceMetering.ResourceConfig.
        // This is required because we have not yet fully migrated the codebase to be interface-based.
        IResourceMetering.ResourceConfig memory resourceConfig = Constants.DEFAULT_RESOURCE_CONFIG();
        assembly ("memory-safe") {
            resourceConfig_ := resourceConfig
        }

        opChainAddrs_ = ISystemConfig.Addresses({
            l1CrossDomainMessenger: address(_output.l1CrossDomainMessengerProxy),
            l1ERC721Bridge: address(_output.l1ERC721BridgeProxy),
            l1StandardBridge: address(_output.l1StandardBridgeProxy),
            disputeGameFactory: address(_output.disputeGameFactoryProxy),
            optimismPortal: address(_output.optimismPortalProxy),
            optimismMintableERC20Factory: address(_output.optimismMintableERC20FactoryProxy),
            gasPayingToken: Constants.ETHER
        });

        assertValidContractAddress(opChainAddrs_.l1CrossDomainMessenger);
        assertValidContractAddress(opChainAddrs_.l1ERC721Bridge);
        assertValidContractAddress(opChainAddrs_.l1StandardBridge);
        assertValidContractAddress(opChainAddrs_.disputeGameFactory);
        assertValidContractAddress(opChainAddrs_.optimismPortal);
        assertValidContractAddress(opChainAddrs_.optimismMintableERC20Factory);
    }

    /// @notice Makes an external call to the target to initialize the proxy with the specified data.
    /// First performs safety checks to ensure the target, implementation, and proxy admin are valid.
    function upgradeAndCall(
        IProxyAdmin _proxyAdmin,
        address _target,
        address _implementation,
        bytes memory _data
    )
        internal
    {
        assertValidContractAddress(address(_proxyAdmin));
        assertValidContractAddress(_target);
        assertValidContractAddress(_implementation);

        _proxyAdmin.upgradeAndCall(payable(address(_target)), _implementation, _data);
    }

    /// @notice Makes an external call to the target to initialize the proxy.
    function upgrade(IProxyAdmin _proxyAdmin, address _target, address _implementation) internal {
        assertValidContractAddress(address(_proxyAdmin));
        assertValidContractAddress(_target);
        assertValidContractAddress(_implementation);

        _proxyAdmin.upgrade(payable(address(_target)), _implementation);
    }

    function assertValidContractAddress(address _who) internal view {
        if (_who == address(0)) revert AddressNotFound(_who);
        if (_who.code.length == 0) revert AddressHasNoCode(_who);
    }

    /// @notice Returns the blueprint contract addresses.
    function blueprints() public view returns (Blueprints memory) {
        return blueprint;
    }

    /// @notice Returns the implementation contract addresses.
    function implementations() public view returns (Implementations memory) {
        return implementation;
    }
}
