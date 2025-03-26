// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Script } from "forge-std/Script.sol";
import { LibString } from "@solady/utils/LibString.sol";

import { IResourceMetering } from "interfaces/L1/IResourceMetering.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IProtocolVersions } from "interfaces/L1/IProtocolVersions.sol";

import { Constants } from "src/libraries/Constants.sol";
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Bytes } from "src/libraries/Bytes.sol";

import { IDelayedWETH } from "interfaces/dispute/IDelayedWETH.sol";
import { IPreimageOracle } from "interfaces/cannon/IPreimageOracle.sol";
import { IMIPS } from "interfaces/cannon/IMIPS.sol";
import { IDisputeGameFactory } from "interfaces/dispute/IDisputeGameFactory.sol";

import { OPContractsManager } from "src/L1/OPContractsManager.sol";
import { IOptimismPortal2 } from "interfaces/L1/IOptimismPortal2.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";
import { IL1CrossDomainMessenger } from "interfaces/L1/IL1CrossDomainMessenger.sol";
import { IL1ERC721Bridge } from "interfaces/L1/IL1ERC721Bridge.sol";
import { IL1StandardBridge } from "interfaces/L1/IL1StandardBridge.sol";
import { IOptimismMintableERC20Factory } from "interfaces/universal/IOptimismMintableERC20Factory.sol";

import { OPContractsManagerInterop } from "src/L1/OPContractsManagerInterop.sol";
import { IOptimismPortalInterop } from "interfaces/L1/IOptimismPortalInterop.sol";
import { ISystemConfigInterop } from "interfaces/L1/ISystemConfigInterop.sol";

import { Blueprint } from "src/libraries/Blueprint.sol";

import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { Solarray } from "scripts/libraries/Solarray.sol";
import { BaseDeployIO } from "scripts/deploy/BaseDeployIO.sol";

import { AssetManager } from "src/L1/AssetManager.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { SystemConfig } from "src/L1/SystemConfig.sol";
import { ZKProofVerifier } from "src/L1/ZKProofVerifier.sol";
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

// See DeploySuperchain.s.sol for detailed comments on the script architecture used here.
contract DeployImplementationsInput is BaseDeployIO {
    bytes32 internal _salt;
    uint256 internal _withdrawalDelaySeconds;
    uint256 internal _minProposalSizeBytes;
    uint256 internal _challengePeriodSeconds;
    uint256 internal _proofMaturityDelaySeconds;
    uint256 internal _disputeGameFinalityDelaySeconds;
    uint256 internal _mipsVersion;

    // [Kroma: START]
    /// @notice Deploy configs for ZKProofVerifier.
    ISP1Verifier internal _sp1Verifier;
    bytes32 internal _vKey;
    // [Kroma: END]

    // This is used in opcm to signal which version of the L1 smart contracts is deployed.
    // It takes the format of `op-contracts/v*.*.*`.
    string internal _l1ContractsRelease;

    // Outputs from DeploySuperchain.s.sol.
    ISuperchainConfig internal _superchainConfigProxy;
    IProtocolVersions internal _protocolVersionsProxy;

    string internal _standardVersionsToml;

    function set(bytes4 _sel, uint256 _value) public {
        require(_value != 0, "DeployImplementationsInput: cannot set zero value");

        if (_sel == this.withdrawalDelaySeconds.selector) {
            _withdrawalDelaySeconds = _value;
        } else if (_sel == this.minProposalSizeBytes.selector) {
            _minProposalSizeBytes = _value;
        } else if (_sel == this.challengePeriodSeconds.selector) {
            require(_value <= type(uint64).max, "DeployImplementationsInput: challengePeriodSeconds too large");
            _challengePeriodSeconds = _value;
        } else if (_sel == this.proofMaturityDelaySeconds.selector) {
            _proofMaturityDelaySeconds = _value;
        } else if (_sel == this.disputeGameFinalityDelaySeconds.selector) {
            _disputeGameFinalityDelaySeconds = _value;
        } else if (_sel == this.mipsVersion.selector) {
            _mipsVersion = _value;
        } else {
            revert("DeployImplementationsInput: unknown selector");
        }
    }

    function set(bytes4 _sel, string memory _value) public {
        require(!LibString.eq(_value, ""), "DeployImplementationsInput: cannot set empty string");
        if (_sel == this.l1ContractsRelease.selector) _l1ContractsRelease = _value;
        else if (_sel == this.standardVersionsToml.selector) _standardVersionsToml = _value;
        else revert("DeployImplementationsInput: unknown selector");
    }

    function set(bytes4 _sel, address _addr) public {
        require(_addr != address(0), "DeployImplementationsInput: cannot set zero address");
        if (_sel == this.superchainConfigProxy.selector) _superchainConfigProxy = ISuperchainConfig(_addr);
        else if (_sel == this.protocolVersionsProxy.selector) _protocolVersionsProxy = IProtocolVersions(_addr);
        // [Kroma: START]
        else if (_sel == this.sp1Verifier.selector) _sp1Verifier = ISP1Verifier(_addr);
        // [Kroma: END]
        else revert("DeployImplementationsInput: unknown selector");
    }

    function set(bytes4 _sel, bytes32 _value) public {
        if (_sel == this.salt.selector) _salt = _value;
        // [Kroma: START]
        else if (_sel == this.vKey.selector) _vKey = _value;
        // [Kroma: END]
        else revert("DeployImplementationsInput: unknown selector");
    }

    function salt() public view returns (bytes32) {
        // TODO check if implementations are deployed based on code+salt and skip deploy if so.
        return _salt;
    }

    function withdrawalDelaySeconds() public view returns (uint256) {
        require(_withdrawalDelaySeconds != 0, "DeployImplementationsInput: not set");
        return _withdrawalDelaySeconds;
    }

    function minProposalSizeBytes() public view returns (uint256) {
        require(_minProposalSizeBytes != 0, "DeployImplementationsInput: not set");
        return _minProposalSizeBytes;
    }

    function challengePeriodSeconds() public view returns (uint256) {
        require(_challengePeriodSeconds != 0, "DeployImplementationsInput: not set");
        require(
            _challengePeriodSeconds <= type(uint64).max, "DeployImplementationsInput: challengePeriodSeconds too large"
        );
        return _challengePeriodSeconds;
    }

    function proofMaturityDelaySeconds() public view returns (uint256) {
        require(_proofMaturityDelaySeconds != 0, "DeployImplementationsInput: not set");
        return _proofMaturityDelaySeconds;
    }

    function disputeGameFinalityDelaySeconds() public view returns (uint256) {
        require(_disputeGameFinalityDelaySeconds != 0, "DeployImplementationsInput: not set");
        return _disputeGameFinalityDelaySeconds;
    }

    function mipsVersion() public view returns (uint256) {
        require(_mipsVersion != 0, "DeployImplementationsInput: not set");
        return _mipsVersion;
    }

    function l1ContractsRelease() public view returns (string memory) {
        require(!LibString.eq(_l1ContractsRelease, ""), "DeployImplementationsInput: not set");
        return _l1ContractsRelease;
    }

    function standardVersionsToml() public view returns (string memory) {
        require(!LibString.eq(_standardVersionsToml, ""), "DeployImplementationsInput: not set");
        return _standardVersionsToml;
    }

    function superchainConfigProxy() public view returns (ISuperchainConfig) {
        require(address(_superchainConfigProxy) != address(0), "DeployImplementationsInput: not set");
        return _superchainConfigProxy;
    }

    function protocolVersionsProxy() public view returns (IProtocolVersions) {
        require(address(_protocolVersionsProxy) != address(0), "DeployImplementationsInput: not set");
        return _protocolVersionsProxy;
    }

    function sp1Verifier() public view returns (ISP1Verifier) {
        require(address(_sp1Verifier) != address(0), "DeployImplementationsInput: sp1Verifier not set");
        return _sp1Verifier;
    }

    function vKey() public view returns (bytes32) {
        require(_vKey != bytes32(0), "DeployImplementationsInput: vKey not set");
        return _vKey;
    }
    // [Kroma: END]
}

contract DeployImplementationsOutput is BaseDeployIO {
    OPContractsManager internal _opcm;
    IDelayedWETH internal _delayedWETHImpl;
    IOptimismPortal2 internal _optimismPortalImpl;
    IPreimageOracle internal _preimageOracleSingleton;
    IMIPS internal _mipsSingleton;
    ISystemConfig internal _systemConfigImpl;
    IL1CrossDomainMessenger internal _l1CrossDomainMessengerImpl;
    IL1ERC721Bridge internal _l1ERC721BridgeImpl;
    IL1StandardBridge internal _l1StandardBridgeImpl;
    IOptimismMintableERC20Factory internal _optimismMintableERC20FactoryImpl;
    IDisputeGameFactory internal _disputeGameFactoryImpl;

    // [Kroma: START]
    IAssetManager internal _assetManagerImpl;
    IColosseum internal _colosseumImpl;
    IL2OutputOracle internal _l2OutputOracleImpl;
    ISecurityCouncil internal _securityCouncilImpl;
    ISecurityCouncilToken internal _securityCouncilTokenImpl;
    ITimeLock internal _timeLockImpl;
    IUpgradeGovernor internal _upgradeGovernorImpl;
    IValidatorManager internal _validatorManagerImpl;
    IZKProofVerifier internal _zkProofVerifierImpl;
    // [Kroma: END]

    function set(bytes4 _sel, address _addr) public {
        require(_addr != address(0), "DeployImplementationsOutput: cannot set zero address");

        // forgefmt: disable-start
        if (_sel == this.opcm.selector) _opcm = OPContractsManager(_addr);
        else if (_sel == this.optimismPortalImpl.selector) _optimismPortalImpl = IOptimismPortal2(payable(_addr));
        else if (_sel == this.delayedWETHImpl.selector) _delayedWETHImpl = IDelayedWETH(payable(_addr));
        else if (_sel == this.preimageOracleSingleton.selector) _preimageOracleSingleton = IPreimageOracle(_addr);
        else if (_sel == this.mipsSingleton.selector) _mipsSingleton = IMIPS(_addr);
        else if (_sel == this.systemConfigImpl.selector) _systemConfigImpl = ISystemConfig(_addr);
        else if (_sel == this.l1CrossDomainMessengerImpl.selector) _l1CrossDomainMessengerImpl = IL1CrossDomainMessenger(_addr);
        else if (_sel == this.l1ERC721BridgeImpl.selector) _l1ERC721BridgeImpl = IL1ERC721Bridge(_addr);
        else if (_sel == this.l1StandardBridgeImpl.selector) _l1StandardBridgeImpl = IL1StandardBridge(payable(_addr));
        else if (_sel == this.optimismMintableERC20FactoryImpl.selector) _optimismMintableERC20FactoryImpl = IOptimismMintableERC20Factory(_addr);
        else if (_sel == this.disputeGameFactoryImpl.selector) _disputeGameFactoryImpl = IDisputeGameFactory(_addr);
        // [Kroma: START]
        else if (_sel == this.assetManagerImpl.selector) _assetManagerImpl = IAssetManager(_addr);
        else if (_sel == this.colosseumImpl.selector) _colosseumImpl = IColosseum(_addr);
        else if (_sel == this.l2OutputOracleImpl.selector) _l2OutputOracleImpl = IL2OutputOracle(_addr);
        else if (_sel == this.securityCouncilImpl.selector) _securityCouncilImpl = ISecurityCouncil(_addr);
        else if (_sel == this.securityCouncilTokenImpl.selector) _securityCouncilTokenImpl = ISecurityCouncilToken(_addr);
        else if (_sel == this.timeLockImpl.selector) _timeLockImpl = ITimeLock(payable(_addr));
        else if (_sel == this.upgradeGovernorImpl.selector) _upgradeGovernorImpl = IUpgradeGovernor(payable(_addr));
        else if (_sel == this.validatorManagerImpl.selector) _validatorManagerImpl = IValidatorManager(_addr);
        else if (_sel == this.zkProofVerifierImpl.selector) _zkProofVerifierImpl = IZKProofVerifier(_addr);
        // [Kroma: END]
        else revert("DeployImplementationsOutput: unknown selector");
        // forgefmt: disable-end
    }

    function checkOutput(DeployImplementationsInput _dii) public view {
        // With 12 addresses, we'd get a stack too deep error if we tried to do this inline as a
        // single call to `Solarray.addresses`. So we split it into two calls.
        address[] memory addrs1 = Solarray.addresses(
            address(this.opcm()),
            address(this.optimismPortalImpl()),
            address(this.delayedWETHImpl()),
            address(this.preimageOracleSingleton()),
            address(this.mipsSingleton())
        );

        address[] memory addrs2 = Solarray.addresses(
            address(this.systemConfigImpl()),
            address(this.l1CrossDomainMessengerImpl()),
            address(this.l1ERC721BridgeImpl()),
            address(this.l1StandardBridgeImpl()),
            address(this.optimismMintableERC20FactoryImpl()),
            address(this.disputeGameFactoryImpl())
        );

        address[] memory addrs3 = Solarray.addresses(
            address(this.assetManagerImpl()),
            address(this.colosseumImpl()),
            address(this.securityCouncilImpl()),
            address(this.securityCouncilTokenImpl()),
            address(this.timeLockImpl()),
            address(this.upgradeGovernorImpl()),
            address(this.validatorManagerImpl()),
            address(this.zkProofVerifierImpl())
        );

        DeployUtils.assertValidContractAddresses(Solarray.extend(Solarray.extend(addrs1, addrs2), addrs3));

        assertValidDeploy(_dii);
    }

    function opcm() public view returns (OPContractsManager) {
        DeployUtils.assertValidContractAddress(address(_opcm));
        return _opcm;
    }

    function optimismPortalImpl() public view returns (IOptimismPortal2) {
        DeployUtils.assertValidContractAddress(address(_optimismPortalImpl));
        return _optimismPortalImpl;
    }

    function delayedWETHImpl() public view returns (IDelayedWETH) {
        DeployUtils.assertValidContractAddress(address(_delayedWETHImpl));
        return _delayedWETHImpl;
    }

    function preimageOracleSingleton() public view returns (IPreimageOracle) {
        DeployUtils.assertValidContractAddress(address(_preimageOracleSingleton));
        return _preimageOracleSingleton;
    }

    function mipsSingleton() public view returns (IMIPS) {
        DeployUtils.assertValidContractAddress(address(_mipsSingleton));
        return _mipsSingleton;
    }

    function systemConfigImpl() public view returns (ISystemConfig) {
        DeployUtils.assertValidContractAddress(address(_systemConfigImpl));
        return _systemConfigImpl;
    }

    function l1CrossDomainMessengerImpl() public view returns (IL1CrossDomainMessenger) {
        DeployUtils.assertValidContractAddress(address(_l1CrossDomainMessengerImpl));
        return _l1CrossDomainMessengerImpl;
    }

    function l1ERC721BridgeImpl() public view returns (IL1ERC721Bridge) {
        DeployUtils.assertValidContractAddress(address(_l1ERC721BridgeImpl));
        return _l1ERC721BridgeImpl;
    }

    function l1StandardBridgeImpl() public view returns (IL1StandardBridge) {
        DeployUtils.assertValidContractAddress(address(_l1StandardBridgeImpl));
        return _l1StandardBridgeImpl;
    }

    function optimismMintableERC20FactoryImpl() public view returns (IOptimismMintableERC20Factory) {
        DeployUtils.assertValidContractAddress(address(_optimismMintableERC20FactoryImpl));
        return _optimismMintableERC20FactoryImpl;
    }

    function disputeGameFactoryImpl() public view returns (IDisputeGameFactory) {
        DeployUtils.assertValidContractAddress(address(_disputeGameFactoryImpl));
        return _disputeGameFactoryImpl;
    }

    // [Kroma: START]
    function assetManagerImpl() public view returns (IAssetManager) {
        require(address(_assetManagerImpl) != address(0), "DeployImplementationsOutput: assetManagerImpl not set");
        return _assetManagerImpl;
    }

    function colosseumImpl() public view returns (IColosseum) {
        require(address(_colosseumImpl) != address(0), "DeployImplementationsOutput: colosseumImpl not set");
        return _colosseumImpl;
    }

    function l2OutputOracleImpl() public view returns (IL2OutputOracle) {
        require(address(_l2OutputOracleImpl) != address(0), "DeployImplementationsOutput: l2OutputOracleImpl not set");
        return _l2OutputOracleImpl;
    }

    function securityCouncilImpl() public view returns (ISecurityCouncil) {
        require(address(_securityCouncilImpl) != address(0), "DeployImplementationsOutput: securityCouncilImpl not set");
        return _securityCouncilImpl;
    }

    function securityCouncilTokenImpl() public view returns (ISecurityCouncilToken) {
        require(
            address(_securityCouncilTokenImpl) != address(0),
            "DeployImplementationsOutput: securityCouncilTokenImpl not set"
        );
        return _securityCouncilTokenImpl;
    }

    function timeLockImpl() public view returns (ITimeLock) {
        require(address(_timeLockImpl) != address(0), "DeployImplementationsOutput: timeLockImpl not set");
        return _timeLockImpl;
    }

    function upgradeGovernorImpl() public view returns (IUpgradeGovernor) {
        require(address(_upgradeGovernorImpl) != address(0), "DeployImplementationsOutput: upgradeGovernorImpl not set");
        return _upgradeGovernorImpl;
    }

    function validatorManagerImpl() public view returns (IValidatorManager) {
        require(
            address(_validatorManagerImpl) != address(0), "DeployImplementationsOutput: validatorManagerImpl not set"
        );
        return _validatorManagerImpl;
    }

    function zkProofVerifierImpl() public view returns (IZKProofVerifier) {
        require(address(_zkProofVerifierImpl) != address(0), "DeployImplementationsOutput: zkProofVerifierImpl not set");
        return _zkProofVerifierImpl;
    }
    // [Kroma: END]

    // -------- Deployment Assertions --------
    function assertValidDeploy(DeployImplementationsInput _dii) public view {
        assertValidDelayedWETHImpl(_dii);
        assertValidDisputeGameFactoryImpl(_dii);
        assertValidL1CrossDomainMessengerImpl(_dii);
        assertValidL1ERC721BridgeImpl(_dii);
        assertValidL1StandardBridgeImpl(_dii);
        assertValidMipsSingleton(_dii);
        assertValidOpcm(_dii);
        assertValidOptimismMintableERC20FactoryImpl(_dii);
        assertValidOptimismPortalImpl(_dii);
        assertValidPreimageOracleSingleton(_dii);
        assertValidSystemConfigImpl(_dii);
        // [Kroma: START]
        assertValidAssetManager(_dii);
        assertValidColosseum(_dii);
        assertValidSecurityCouncil(_dii);
        assertValidSecurityCouncilToken(_dii);
        assertValidTimeLock(_dii);
        assertValidUpgradeGovernor(_dii);
        assertValidValidatorManager(_dii);
        assertValidZKProofVerifier(_dii);
        // [Kroma: END]
    }

    function assertValidOpcm(DeployImplementationsInput _dii) internal view {
        OPContractsManager impl = OPContractsManager(address(opcm()));
        require(address(impl.superchainConfig()) == address(_dii.superchainConfigProxy()), "OPCMI-10");
        require(address(impl.protocolVersions()) == address(_dii.protocolVersionsProxy()), "OPCMI-20");
    }

    function assertValidOptimismPortalImpl(DeployImplementationsInput) internal view {
        IOptimismPortal2 portal = optimismPortalImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(portal), _slot: 0, _offset: 0 });

        require(address(portal.disputeGameFactory()) == address(0), "PORTAL-10");
        require(address(portal.systemConfig()) == address(0), "PORTAL-20");
        require(address(portal.superchainConfig()) == address(0), "PORTAL-30");
        require(portal.l2Sender() == Constants.DEFAULT_L2_SENDER, "PORTAL-40");

        // This slot is the custom gas token _balance and this check ensures
        // that it stays unset for forwards compatibility with custom gas token.
        require(vm.load(address(portal), bytes32(uint256(61))) == bytes32(0), "PORTAL-50");
    }

    function assertValidDelayedWETHImpl(DeployImplementationsInput _dii) internal view {
        IDelayedWETH delayedWETH = delayedWETHImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(delayedWETH), _slot: 0, _offset: 0 });

        require(delayedWETH.owner() == address(0), "DW-10");
        require(delayedWETH.delay() == _dii.withdrawalDelaySeconds(), "DW-20");
        require(delayedWETH.config() == ISuperchainConfig(address(0)), "DW-30");
    }

    function assertValidPreimageOracleSingleton(DeployImplementationsInput _dii) internal view {
        IPreimageOracle oracle = preimageOracleSingleton();

        require(oracle.minProposalSize() == _dii.minProposalSizeBytes(), "PO-10");
        require(oracle.challengePeriod() == _dii.challengePeriodSeconds(), "PO-20");
    }

    function assertValidMipsSingleton(DeployImplementationsInput) internal view {
        IMIPS mips = mipsSingleton();
        require(address(mips.oracle()) == address(preimageOracleSingleton()), "MIPS-10");
    }

    function assertValidSystemConfigImpl(DeployImplementationsInput) internal view {
        ISystemConfig systemConfig = systemConfigImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(systemConfig), _slot: 0, _offset: 0 });

        require(systemConfig.owner() == address(0xdead), "SYSCON-10");
        require(systemConfig.overhead() == 0, "SYSCON-20");
        require(systemConfig.scalar() == uint256(0x01) << 248, "SYSCON-30");
        require(systemConfig.basefeeScalar() == 0, "SYSCON-40");
        require(systemConfig.blobbasefeeScalar() == 0, "SYSCON-50");
        require(systemConfig.batcherHash() == bytes32(0), "SYSCON-60");
        require(systemConfig.gasLimit() == 1, "SYSCON-70");
        require(systemConfig.unsafeBlockSigner() == address(0), "SYSCON-80");

        IResourceMetering.ResourceConfig memory resourceConfig = systemConfig.resourceConfig();
        require(resourceConfig.maxResourceLimit == 1, "SYSCON-90");
        require(resourceConfig.elasticityMultiplier == 1, "SYSCON-100");
        require(resourceConfig.baseFeeMaxChangeDenominator == 2, "SYSCON-110");
        require(resourceConfig.systemTxMaxGas == 0, "SYSCON-120");
        require(resourceConfig.minimumBaseFee == 0, "SYSCON-130");
        require(resourceConfig.maximumBaseFee == 0, "SYSCON-140");

        require(systemConfig.startBlock() == type(uint256).max, "SYSCON-150");
        require(systemConfig.batchInbox() == address(0), "SYSCON-160");
        require(systemConfig.l1CrossDomainMessenger() == address(0), "SYSCON-170");
        require(systemConfig.l1ERC721Bridge() == address(0), "SYSCON-180");
        require(systemConfig.l1StandardBridge() == address(0), "SYSCON-190");
        require(systemConfig.disputeGameFactory() == address(0), "SYSCON-200");
        require(systemConfig.optimismPortal() == address(0), "SYSCON-210");
        require(systemConfig.optimismMintableERC20Factory() == address(0), "SYSCON-220");
    }

    function assertValidL1CrossDomainMessengerImpl(DeployImplementationsInput) internal view {
        IL1CrossDomainMessenger messenger = l1CrossDomainMessengerImpl();

        // [Kroma: START]
        DeployUtils.assertInitialized({ _contractAddress: address(messenger), _slot: 0, _offset: 0 });
        // [Kroma: END]
        require(address(messenger.OTHER_MESSENGER()) == Predeploys.L2_CROSS_DOMAIN_MESSENGER, "L1xDM-10");
        require(address(messenger.otherMessenger()) == Predeploys.L2_CROSS_DOMAIN_MESSENGER, "L1xDM-20");
        require(address(messenger.PORTAL()) == address(0), "L1xDM-30");
        require(address(messenger.portal()) == address(0), "L1xDM-40");
        require(address(messenger.superchainConfig()) == address(0), "L1xDM-50");

        // [Kroma: START]
        bytes32 xdmSenderSlot = vm.load(address(messenger), bytes32(uint256(102)));
        // [Kroma: END]
        require(address(uint160(uint256(xdmSenderSlot))) == Constants.DEFAULT_L2_SENDER, "L1xDM-60");
    }

    function assertValidL1ERC721BridgeImpl(DeployImplementationsInput) internal view {
        IL1ERC721Bridge bridge = l1ERC721BridgeImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(bridge), _slot: 0, _offset: 0 });

        require(address(bridge.OTHER_BRIDGE()) == Predeploys.L2_ERC721_BRIDGE, "L721B-10");
        require(address(bridge.otherBridge()) == Predeploys.L2_ERC721_BRIDGE, "L721B-20");
        require(address(bridge.MESSENGER()) == address(0), "L721B-30");
        require(address(bridge.messenger()) == address(0), "L721B-40");
        require(address(bridge.superchainConfig()) == address(0), "L721B-50");
    }

    function assertValidL1StandardBridgeImpl(DeployImplementationsInput) internal view {
        IL1StandardBridge bridge = l1StandardBridgeImpl();

        // [Kroma: START]
        DeployUtils.assertInitialized({ _contractAddress: address(bridge), _slot: 2, _offset: 20 });
        // [Kroma: END]

        require(address(bridge.MESSENGER()) == address(0), "L1SB-10");
        require(address(bridge.messenger()) == address(0), "L1SB-20");
        require(address(bridge.OTHER_BRIDGE()) == Predeploys.L2_STANDARD_BRIDGE, "L1SB-30");
        require(address(bridge.otherBridge()) == Predeploys.L2_STANDARD_BRIDGE, "L1SB-40");
        require(address(bridge.superchainConfig()) == address(0), "L1SB-50");
    }

    function assertValidOptimismMintableERC20FactoryImpl(DeployImplementationsInput) internal view {
        IOptimismMintableERC20Factory factory = optimismMintableERC20FactoryImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(factory), _slot: 0, _offset: 0 });

        require(address(factory.BRIDGE()) == address(0), "MERC20F-10");
        require(address(factory.bridge()) == address(0), "MERC20F-20");
    }

    function assertValidDisputeGameFactoryImpl(DeployImplementationsInput) internal view {
        IDisputeGameFactory factory = disputeGameFactoryImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(factory), _slot: 0, _offset: 0 });

        require(address(factory.owner()) == address(0), "DG-10");
    }

    // [Kroma: START]
    function assertValidAssetManager(DeployImplementationsInput) public view {
        IAssetManager assetManager = assetManagerImpl();
        uint256 slot = uint256(keccak256("initializable.dynamic.initialized")) - 1;
        DeployUtils.assertInitialized({ _contractAddress: address(assetManager), _slot: slot, _offset: 0 });

        require(address(assetManager.ASSET_TOKEN()) == address(0), "ASSETMGR-10");
        require(address(assetManager.assetToken()) == address(0), "ASSETMGR-20");
        require(address(assetManager.KGH()) == address(0), "ASSETMGR-30");
        require(address(assetManager.kgh()) == address(0), "ASSETMGR-40");
        require(address(assetManager.SECURITY_COUNCIL()) == address(0), "ASSETMGR-50");
        require(address(assetManager.securityCouncil()) == address(0), "ASSETMGR-60");
        require(address(assetManager.VALIDATOR_REWARD_VAULT()) == address(0), "ASSETMGR-70");
        require(address(assetManager.validatorRewardVault()) == address(0), "ASSETMGR-80");
        require(address(assetManager.VALIDATOR_MANAGER()) == address(0), "ASSETMGR-90");
        require(address(assetManager.validatorManager()) == address(0), "ASSETMGR-100");
        require(assetManager.MIN_DELEGATION_PERIOD() == 0, "ASSETMGR-110");
        require(assetManager.minDelegationPeriod() == 0, "ASSETMGR-120");
        require(assetManager.BOND_AMOUNT() == 0, "ASSETMGR-130");
        require(assetManager.bondAmount() == 0, "ASSETMGR-140");
    }

    function assertValidColosseum(DeployImplementationsInput) public view {
        IColosseum colosseum = colosseumImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(colosseum), _slot: 0, _offset: 0 });

        require(address(colosseum.L2_ORACLE()) == address(0), "COLOSSEUM-10");
        require(address(colosseum.l2Oracle()) == address(0), "COLOSSEUM-20");
        require(address(colosseum.ZK_PROOF_VERIFIER()) == address(0), "COLOSSEUM-30");
        require(address(colosseum.zkProofVerifier()) == address(0), "COLOSSEUM-40");
        require(colosseum.L2_ORACLE_SUBMISSION_INTERVAL() == 0, "COLOSSEUM-50");
        require(colosseum.l2OracleSubmissionInterval() == 0, "COLOSSEUM-60");
        require(colosseum.CREATION_PERIOD_SECONDS() == 0, "COLOSSEUM-70");
        require(colosseum.creationPeriodSeconds() == 0, "COLOSSEUM-80");
        require(colosseum.BISECTION_TIMEOUT() == 0, "COLOSSEUM-90");
        require(colosseum.bisectionTimeout() == 0, "COLOSSEUM-100");
        require(colosseum.PROVING_TIMEOUT() == 0, "COLOSSEUM-110");
        require(colosseum.provingTimeout() == 0, "COLOSSEUM-120");
        require(colosseum.segmentsLengths(0) == 0, "COLOSSEUM-130");
        require(address(colosseum.SECURITY_COUNCIL()) == address(0), "COLOSSEUM-140");
        require(address(colosseum.securityCouncil()) == address(0), "COLOSSEUM-150");
    }

    function assertValidSecurityCouncil(DeployImplementationsInput) public view {
        ISecurityCouncil securityCouncil = securityCouncilImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(securityCouncil), _slot: 0, _offset: 0 });

        require(securityCouncil.COLOSSEUM() == address(0), "SC-10");
        require(securityCouncil.colosseum() == address(0), "SC-20");
        require(address(securityCouncil.GOVERNOR()) == address(0), "SC-30");
        require(address(securityCouncil.governor()) == address(0), "SC-40");
    }

    function assertValidSecurityCouncilToken(DeployImplementationsInput) public view {
        ISecurityCouncilToken securityCouncilToken = securityCouncilTokenImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(securityCouncilToken), _slot: 0, _offset: 0 });

        require(address(securityCouncilToken.owner()) == address(0), "SCT-10");
    }

    function assertValidTimeLock(DeployImplementationsInput) public view {
        ITimeLock timeLock = timeLockImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(timeLock), _slot: 0, _offset: 0 });

        require(timeLock.getMinDelay() == 0, "TL-10");
    }

    function assertValidUpgradeGovernor(DeployImplementationsInput) public view {
        IUpgradeGovernor upgradeGovernor = upgradeGovernorImpl();

        DeployUtils.assertInitialized({ _contractAddress: address(upgradeGovernor), _slot: 0, _offset: 0 });

        require(address(upgradeGovernor.token()) == address(0), "UG-10");
        require(address(upgradeGovernor.timelock()) == address(0), "UG-20");
        require(upgradeGovernor.votingDelay() == 0, "UG-30");
        require(upgradeGovernor.votingPeriod() == 0, "UG-40");
        require(upgradeGovernor.proposalThreshold() == 0, "UG-50");
        require(upgradeGovernor.quorumNumerator() == 0, "UG-60");
    }

    function assertValidValidatorManager(DeployImplementationsInput) public view {
        IValidatorManager validatorManager = validatorManagerImpl();

        uint256 slot = uint256(keccak256("initializable.dynamic.initialized")) - 1;
        DeployUtils.assertInitialized({ _contractAddress: address(validatorManager), _slot: slot, _offset: 0 });

        require(address(validatorManager.L2_ORACLE()) == address(0), "VM-10");
        require(address(validatorManager.l2Oracle()) == address(0), "VM-20");
        require(address(validatorManager.ASSET_MANAGER()) == address(0), "VM-30");
        require(address(validatorManager.assetManager()) == address(0), "VM-40");
        require(validatorManager.TRUSTED_VALIDATOR() == address(0), "VM-50");
        require(validatorManager.trustedValidator() == address(0), "VM-60");
        require(validatorManager.COMMISSION_CHANGE_DELAY_SECONDS() == 0, "VM-70");
        require(validatorManager.commissionChangeDelaySeconds() == 0, "VM-80");
        require(validatorManager.ROUND_DURATION_SECONDS() == 0, "VM-90");
        require(validatorManager.roundDurationSeconds() == 0, "VM-100");
        require(validatorManager.SOFT_JAIL_PERIOD_SECONDS() == 0, "VM-110");
        require(validatorManager.softJailPeriodSeconds() == 0, "VM-120");
        require(validatorManager.HARD_JAIL_PERIOD_SECONDS() == 0, "VM-130");
        require(validatorManager.hardJailPeriodSeconds() == 0, "VM-140");
        require(validatorManager.JAIL_THRESHOLD() == 0, "VM-150");
        require(validatorManager.jailThreshold() == 0, "VM-160");
        require(validatorManager.MAX_OUTPUT_FINALIZATIONS() == 0, "VM-170");
        require(validatorManager.maxOutputFinalizations() == 0, "VM-180");
        require(validatorManager.BASE_REWARD() == 0, "VM-190");
        require(validatorManager.baseReward() == 0, "VM-200");
        require(validatorManager.MIN_REGISTER_AMOUNT() == 0, "VM-210");
        require(validatorManager.minRegisterAmount() == 0, "VM-220");
        require(validatorManager.MIN_ACTIVATE_AMOUNT() == 0, "VM-230");
        require(validatorManager.minActiveAmount() == 0, "VM-240");
    }

    function assertValidZKProofVerifier(DeployImplementationsInput _dii) public view {
        IZKProofVerifier zkProofVerifier = zkProofVerifierImpl();

        require(address(zkProofVerifier.sp1Verifier()) == address(_dii.sp1Verifier()), "ZKP-10");
        require(zkProofVerifier.zkVmProgramVKey() == _dii.vKey(), "ZKP-20");
    }
    // [Kroma: END]
}

contract DeployImplementations is Script {
    //    /// @notice Dummy selector for the virtual constructor function.
    //    bytes4 internal constant DUMMY_CONSTRUCTOR_SELECTOR = 0xffffffff;
    // -------- Core Deployment Methods --------

    function run(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public {
        // Deploy the implementations.
        deploySystemConfigImpl(_dii, _dio);
        deployL1CrossDomainMessengerImpl(_dii, _dio);
        deployL1ERC721BridgeImpl(_dii, _dio);
        deployL1StandardBridgeImpl(_dii, _dio);
        deployOptimismMintableERC20FactoryImpl(_dii, _dio);
        deployOptimismPortalImpl(_dii, _dio);
        deployDelayedWETHImpl(_dii, _dio);
        deployPreimageOracleSingleton(_dii, _dio);
        deployMipsSingleton(_dii, _dio);
        deployDisputeGameFactoryImpl(_dii, _dio);

        // [Kroma: START]
        deployAssetManagerImpl(_dii, _dio);
        deployColosseumImpl(_dii, _dio);
        deploySecurityCouncilImpl(_dii, _dio);
        deploySecurityCouncilTokenImpl(_dii, _dio);
        deployTimeLockImpl(_dii, _dio);
        deployUpgradeGovernorImpl(_dii, _dio);
        deployValidatorManagerImpl(_dii, _dio);
        deployZKProofVerifierImpl(_dii, _dio);
        // [Kroma: END]

        // Deploy the OP Contracts Manager with the new implementations set.
        deployOPContractsManager(_dii, _dio);

        _dio.checkOutput(_dii);
    }

    // -------- Deployment Steps --------

    // --- OP Contracts Manager ---

    function createOPCMContract(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio,
        OPContractsManager.Blueprints memory _blueprints,
        string memory _l1ContractsRelease
    )
        internal
        virtual
        returns (OPContractsManager opcm_)
    {
        ISuperchainConfig superchainConfigProxy = _dii.superchainConfigProxy();
        IProtocolVersions protocolVersionsProxy = _dii.protocolVersionsProxy();

        OPContractsManager.Implementations memory implementations = OPContractsManager.Implementations({
            l1ERC721BridgeImpl: address(_dio.l1ERC721BridgeImpl()),
            optimismPortalImpl: address(_dio.optimismPortalImpl()),
            systemConfigImpl: address(_dio.systemConfigImpl()),
            optimismMintableERC20FactoryImpl: address(_dio.optimismMintableERC20FactoryImpl()),
            l1CrossDomainMessengerImpl: address(_dio.l1CrossDomainMessengerImpl()),
            l1StandardBridgeImpl: address(_dio.l1StandardBridgeImpl()),
            disputeGameFactoryImpl: address(_dio.disputeGameFactoryImpl()),
            delayedWETHImpl: address(_dio.delayedWETHImpl()),
            mipsImpl: address(_dio.mipsSingleton()),
            // [Kroma: START]
            assetManagerImpl: address(_dio.assetManagerImpl()),
            colosseumImpl: address(_dio.colosseumImpl()),
            securityCouncilImpl: address(_dio.securityCouncilImpl()),
            securityCouncilTokenImpl: address(_dio.securityCouncilTokenImpl()),
            timeLockImpl: address(_dio.timeLockImpl()),
            upgradeGovernorImpl: address(_dio.upgradeGovernorImpl()),
            validatorManagerImpl: address(_dio.validatorManagerImpl()),
            zkProofVerifierImpl: address(_dio.zkProofVerifierImpl())
        });
        // [Kroma: END]

        vm.broadcast(msg.sender);
        opcm_ = new OPContractsManager(
            superchainConfigProxy, protocolVersionsProxy, _l1ContractsRelease, _blueprints, implementations
        );

        vm.label(address(opcm_), "OPContractsManager");
        _dio.set(_dio.opcm.selector, address(opcm_));
    }

    function deployOPContractsManager(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory l1ContractsRelease = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "op_contracts_manager";
        OPContractsManager opcm;

        address existingImplementation = getReleaseAddress(l1ContractsRelease, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            opcm = OPContractsManager(existingImplementation);
        } else {
            // First we deploy the blueprints for the singletons deployed by OPCM.
            // forgefmt: disable-start
            bytes32 salt = _dii.salt();
            OPContractsManager.Blueprints memory blueprints;

            vm.startBroadcast(msg.sender);
            blueprints.addressManager = deployBytecode(Blueprint.blueprintDeployerBytecode(vm.getCode("AddressManager")), salt);
            blueprints.proxy = deployBytecode(Blueprint.blueprintDeployerBytecode(vm.getCode("Proxy")), salt);
            blueprints.proxyAdmin = deployBytecode(Blueprint.blueprintDeployerBytecode(vm.getCode("ProxyAdmin")), salt);
            blueprints.l1ChugSplashProxy = deployBytecode(Blueprint.blueprintDeployerBytecode(vm.getCode("L1ChugSplashProxy")), salt);
            blueprints.resolvedDelegateProxy = deployBytecode(Blueprint.blueprintDeployerBytecode(vm.getCode("ResolvedDelegateProxy")), salt);
            blueprints.anchorStateRegistry = deployBytecode(Blueprint.blueprintDeployerBytecode(vm.getCode("AnchorStateRegistry")), salt);
            (blueprints.permissionedDisputeGame1, blueprints.permissionedDisputeGame2)  = deployBigBytecode(vm.getCode("PermissionedDisputeGame"), salt);
            vm.stopBroadcast();
            // forgefmt: disable-end

            opcm = createOPCMContract(_dii, _dio, blueprints, l1ContractsRelease);
        }

        vm.label(address(opcm), "OPContractsManager");
        _dio.set(_dio.opcm.selector, address(opcm));
    }

    // --- Core Contracts ---

    function deploySystemConfigImpl(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public virtual {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        // Using snake case for contract name to match the TOML file in superchain-registry.
        string memory contractName = "system_config";
        ISystemConfig impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = ISystemConfig(existingImplementation);
        } else {
            // Deploy a new implementation for development builds.
            vm.broadcast(msg.sender);
            impl = ISystemConfig(
                DeployUtils.create1({
                    _name: "SystemConfig",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(ISystemConfig.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "SystemConfigImpl");
        _dio.set(_dio.systemConfigImpl.selector, address(impl));
    }

    function deployL1CrossDomainMessengerImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "l1_cross_domain_messenger";
        IL1CrossDomainMessenger impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IL1CrossDomainMessenger(existingImplementation);
        } else {
            vm.broadcast(msg.sender);
            impl = IL1CrossDomainMessenger(
                DeployUtils.create1({
                    _name: "L1CrossDomainMessenger",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IL1CrossDomainMessenger.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "L1CrossDomainMessengerImpl");
        _dio.set(_dio.l1CrossDomainMessengerImpl.selector, address(impl));
    }

    function deployL1ERC721BridgeImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "l1_erc721_bridge";
        IL1ERC721Bridge impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IL1ERC721Bridge(existingImplementation);
        } else {
            vm.broadcast(msg.sender);
            impl = IL1ERC721Bridge(
                DeployUtils.create1({
                    _name: "L1ERC721Bridge",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IL1ERC721Bridge.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "L1ERC721BridgeImpl");
        _dio.set(_dio.l1ERC721BridgeImpl.selector, address(impl));
    }

    function deployL1StandardBridgeImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "l1_standard_bridge";
        IL1StandardBridge impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IL1StandardBridge(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = IL1StandardBridge(
                DeployUtils.create1({
                    _name: "L1StandardBridge",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IL1StandardBridge.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "L1StandardBridgeImpl");
        _dio.set(_dio.l1StandardBridgeImpl.selector, address(impl));
    }

    function deployOptimismMintableERC20FactoryImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "optimism_mintable_erc20_factory";
        IOptimismMintableERC20Factory impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IOptimismMintableERC20Factory(existingImplementation);
        } else {
            vm.broadcast(msg.sender);
            impl = IOptimismMintableERC20Factory(
                DeployUtils.create1({
                    _name: "OptimismMintableERC20Factory",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IOptimismMintableERC20Factory.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "OptimismMintableERC20FactoryImpl");
        _dio.set(_dio.optimismMintableERC20FactoryImpl.selector, address(impl));
    }

    // --- Fault Proofs Contracts ---

    // The fault proofs contracts are configured as follows:
    // | Contract                | Proxied | Deployment                        | MCP Ready  |
    // |-------------------------|---------|-----------------------------------|------------|
    // | DisputeGameFactory      | Yes     | Bespoke                           | Yes        |
    // | AnchorStateRegistry     | Yes     | Bespoke                           | No         |
    // | FaultDisputeGame        | No      | Bespoke                           | No         | Not yet supported by OPCM
    // | PermissionedDisputeGame | No      | Bespoke                           | No         |
    // | DelayedWETH             | Yes     | Two bespoke (one per DisputeGame) | Yes *️⃣     |
    // | PreimageOracle          | No      | Shared                            | N/A        |
    // | MIPS                    | No      | Shared                            | N/A        |
    // | OptimismPortal2         | Yes     | Shared                            | Yes *️⃣     |
    //
    // - *️⃣ These contracts have immutable values which are intended to be constant for all contracts within a
    //   Superchain, and are therefore MCP ready for any chain using the Standard Configuration.
    //
    // This script only deploys the shared contracts. The bespoke contracts are deployed by
    // `DeployOPChain.s.sol`. When the shared contracts are proxied, the contracts deployed here are
    // "implementations", and when shared contracts are not proxied, they are "singletons". So
    // here we deploy:
    //
    //   - DisputeGameFactory (implementation)
    //   - OptimismPortal2 (implementation)
    //   - DelayedWETH (implementation)
    //   - PreimageOracle (singleton)
    //   - MIPS (singleton)
    //
    // For contracts which are not MCP ready neither the Proxy nor the implementation can be shared, therefore they
    // are deployed by `DeployOpChain.s.sol`.
    // These are:
    // - AnchorStateRegistry (proxy and implementation)
    // - FaultDisputeGame (not proxied)
    // - PermissionedDisputeGame (not proxied)
    // - DelayedWeth (proxies only)
    // - OptimismPortal2 (proxies only)

    function deployOptimismPortalImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "optimism_portal";
        IOptimismPortal2 impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IOptimismPortal2(payable(existingImplementation));
        } else {
            uint256 proofMaturityDelaySeconds = _dii.proofMaturityDelaySeconds();
            uint256 disputeGameFinalityDelaySeconds = _dii.disputeGameFinalityDelaySeconds();
            vm.broadcast(msg.sender);
            impl = IOptimismPortal2(
                DeployUtils.create1({
                    _name: "OptimismPortal2",
                    _args: DeployUtils.encodeConstructor(
                        abi.encodeCall(
                            IOptimismPortal2.__constructor__, (proofMaturityDelaySeconds, disputeGameFinalityDelaySeconds)
                        )
                    )
                })
            );
        }

        vm.label(address(impl), "OptimismPortalImpl");
        _dio.set(_dio.optimismPortalImpl.selector, address(impl));
    }

    function deployDelayedWETHImpl(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public virtual {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "delayed_weth";
        IDelayedWETH impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IDelayedWETH(payable(existingImplementation));
        } else {
            uint256 withdrawalDelaySeconds = _dii.withdrawalDelaySeconds();
            vm.broadcast(msg.sender);
            impl = IDelayedWETH(
                DeployUtils.create1({
                    _name: "DelayedWETH",
                    _args: DeployUtils.encodeConstructor(
                        abi.encodeCall(IDelayedWETH.__constructor__, (withdrawalDelaySeconds))
                    )
                })
            );
        }

        vm.label(address(impl), "DelayedWETHImpl");
        _dio.set(_dio.delayedWETHImpl.selector, address(impl));
    }

    function deployPreimageOracleSingleton(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "preimage_oracle";
        IPreimageOracle singleton;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            singleton = IPreimageOracle(payable(existingImplementation));
        } else {
            uint256 minProposalSizeBytes = _dii.minProposalSizeBytes();
            uint256 challengePeriodSeconds = _dii.challengePeriodSeconds();
            vm.broadcast(msg.sender);
            singleton = IPreimageOracle(
                DeployUtils.create1({
                    _name: "PreimageOracle",
                    _args: DeployUtils.encodeConstructor(
                        abi.encodeCall(IPreimageOracle.__constructor__, (minProposalSizeBytes, challengePeriodSeconds))
                    )
                })
            );
        }

        vm.label(address(singleton), "PreimageOracleSingleton");
        _dio.set(_dio.preimageOracleSingleton.selector, address(singleton));
    }

    function deployMipsSingleton(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public virtual {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "mips";
        IMIPS singleton;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            singleton = IMIPS(payable(existingImplementation));
        } else {
            uint256 mipsVersion = _dii.mipsVersion();
            IPreimageOracle preimageOracle = IPreimageOracle(address(_dio.preimageOracleSingleton()));
            vm.broadcast(msg.sender);
            singleton = IMIPS(
                DeployUtils.create1({
                    _name: mipsVersion == 1 ? "MIPS" : "MIPS64",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IMIPS.__constructor__, (preimageOracle)))
                })
            );
        }

        vm.label(address(singleton), "MIPSSingleton");
        _dio.set(_dio.mipsSingleton.selector, address(singleton));
    }

    function deployDisputeGameFactoryImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "dispute_game_factory";
        IDisputeGameFactory impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IDisputeGameFactory(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = IDisputeGameFactory(
                DeployUtils.create1({
                    _name: "DisputeGameFactory",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IDisputeGameFactory.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "DisputeGameFactoryImpl");
        _dio.set(_dio.disputeGameFactoryImpl.selector, address(impl));
    }

    // [Kroma: START]
    function deployAssetManagerImpl(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public virtual {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "assetManager";
        IAssetManager impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IAssetManager(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = IAssetManager(
                DeployUtils.create1({
                    _name: "AssetManager",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IAssetManager.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "AssetManagerImpl");
        _dio.set(_dio.assetManagerImpl.selector, address(impl));
    }

    function deployColosseumImpl(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public virtual {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "colosseum";
        IColosseum impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IColosseum(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = IColosseum(
                DeployUtils.create1({
                    _name: "Colosseum",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IColosseum.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "ColosseumImpl");
        _dio.set(_dio.colosseumImpl.selector, address(impl));
    }

    function deploySecurityCouncilImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "security_council";
        ISecurityCouncil impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = ISecurityCouncil(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = ISecurityCouncil(
                DeployUtils.create1({
                    _name: "SecurityCouncil",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(ISecurityCouncil.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "SecurityCouncilImpl");
        _dio.set(_dio.securityCouncilImpl.selector, address(impl));
    }

    function deploySecurityCouncilTokenImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "security_council_token";
        ISecurityCouncilToken impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = ISecurityCouncilToken(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = ISecurityCouncilToken(
                DeployUtils.create1({
                    _name: "SecurityCouncilToken",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(ISecurityCouncilToken.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "SecurityCouncilTokenImpl");
        _dio.set(_dio.securityCouncilTokenImpl.selector, address(impl));
    }

    function deployTimeLockImpl(DeployImplementationsInput _dii, DeployImplementationsOutput _dio) public virtual {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "time_lock";
        ITimeLock impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = ITimeLock(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = ITimeLock(
                DeployUtils.create1({
                    _name: "TimeLock",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(ITimeLock.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "TimeLockImpl");
        _dio.set(_dio.timeLockImpl.selector, address(impl));
    }

    function deployUpgradeGovernorImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "upgrade_governor";
        IUpgradeGovernor impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IUpgradeGovernor(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = IUpgradeGovernor(
                DeployUtils.create1({
                    _name: "UpgradeGovernor",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IUpgradeGovernor.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "UpgradeGovernorImpl");
        _dio.set(_dio.upgradeGovernorImpl.selector, address(impl));
    }

    function deployValidatorManagerImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "validator_manager";
        IValidatorManager impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IValidatorManager(payable(existingImplementation));
        } else {
            vm.broadcast(msg.sender);
            impl = IValidatorManager(
                DeployUtils.create1({
                    _name: "ValidatorManager",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(IValidatorManager.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "ValidatorManagerImpl");
        _dio.set(_dio.validatorManagerImpl.selector, address(impl));
    }

    function deployZKProofVerifierImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        virtual
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "zk_proof_verifier";
        IZKProofVerifier impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IZKProofVerifier(payable(existingImplementation));
        } else {
            vm.startBroadcast(msg.sender);
            impl = IZKProofVerifier(
                DeployUtils.create1({
                    _name: "ZKProofVerifier",
                    _args: DeployUtils.encodeConstructor(
                        abi.encodeCall(IZKProofVerifier.__constructor__, (_dii.sp1Verifier(), _dii.vKey()))
                    )
                })
            );
            vm.stopBroadcast();
        }

        vm.label(address(impl), "ZKProofVerifierImpl");
        _dio.set(_dio.zkProofVerifierImpl.selector, address(impl));
    }
    // [Kroma: END]

    // -------- Utilities --------

    function etchIOContracts() public returns (DeployImplementationsInput dii_, DeployImplementationsOutput dio_) {
        (dii_, dio_) = getIOContracts();
        vm.etch(address(dii_), type(DeployImplementationsInput).runtimeCode);
        vm.etch(address(dio_), type(DeployImplementationsOutput).runtimeCode);
    }

    function getIOContracts() public view returns (DeployImplementationsInput dii_, DeployImplementationsOutput dio_) {
        dii_ = DeployImplementationsInput(DeployUtils.toIOAddress(msg.sender, "optimism.DeployImplementationsInput"));
        dio_ = DeployImplementationsOutput(DeployUtils.toIOAddress(msg.sender, "optimism.DeployImplementationsOutput"));
    }

    function deployBytecode(bytes memory _bytecode, bytes32 _salt) public returns (address newContract_) {
        assembly ("memory-safe") {
            newContract_ := create2(0, add(_bytecode, 0x20), mload(_bytecode), _salt)
        }
        require(newContract_ != address(0), "DeployImplementations: create2 failed");
    }

    function deployBigBytecode(
        bytes memory _bytecode,
        bytes32 _salt
    )
        public
        returns (address newContract1_, address newContract2_)
    {
        // Preamble needs 3 bytes.
        uint256 maxInitCodeSize = 24576 - 3;
        require(_bytecode.length > maxInitCodeSize, "DeployImplementations: Use deployBytecode instead");

        bytes memory part1Slice = Bytes.slice(_bytecode, 0, maxInitCodeSize);
        bytes memory part1 = Blueprint.blueprintDeployerBytecode(part1Slice);
        bytes memory part2Slice = Bytes.slice(_bytecode, maxInitCodeSize, _bytecode.length - maxInitCodeSize);
        bytes memory part2 = Blueprint.blueprintDeployerBytecode(part2Slice);

        newContract1_ = deployBytecode(part1, _salt);
        newContract2_ = deployBytecode(part2, _salt);
    }

    // Zero address is returned if the address is not found in '_standardVersionsToml'.
    function getReleaseAddress(
        string memory _version,
        string memory _contractName,
        string memory _standardVersionsToml
    )
        internal
        pure
        returns (address addr_)
    {
        string memory baseKey = string.concat('.releases["', _version, '"].', _contractName);
        string memory implAddressKey = string.concat(baseKey, ".implementation_address");
        string memory addressKey = string.concat(baseKey, ".address");
        try vm.parseTomlAddress(_standardVersionsToml, implAddressKey) returns (address parsedAddr_) {
            addr_ = parsedAddr_;
        } catch {
            try vm.parseTomlAddress(_standardVersionsToml, addressKey) returns (address parsedAddr_) {
                addr_ = parsedAddr_;
            } catch {
                addr_ = address(0);
            }
        }
    }
}

// Similar to how DeploySuperchain.s.sol contains a lot of comments to thoroughly document the script
// architecture, this comment block documents how to update the deploy scripts to support new features.
//
// Using the base scripts and contracts (DeploySuperchain, DeployImplementations, DeployOPChain, and
// the corresponding OPContractsManager) deploys a standard chain. For nonstandard and in-development
// features we need to modify some or all of those contracts, and we do that via inheritance. Using
// interop as an example, they've made the following changes to L1 contracts:
//   - `OptimismPortalInterop is OptimismPortal`: A different portal implementation is used, and
//     it's ABI is the same.
//   - `SystemConfigInterop is SystemConfig`: A different system config implementation is used, and
//     it's initializer has a different signature. This signature is different because there is a
//     new input parameter, the `dependencyManager`.
//   - Because of the different system config initializer, there is a new input parameter (dependencyManager).
//
// Similar to how inheritance was used to develop the new portal and system config contracts, we use
// inheritance to modify up to all of the deployer contracts. For this interop example, what this
// means is we need:
//   - An `OPContractsManagerInterop is OPContractsManager` that knows how to encode the calldata for the
//     new system config initializer.
//   - A `DeployImplementationsInterop is DeployImplementations` that:
//     - Deploys OptimismPortalInterop instead of OptimismPortal.
//     - Deploys SystemConfigInterop instead of SystemConfig.
//     - Deploys OPContractsManagerInterop instead of OPContractsManager, which contains the updated logic
//       for encoding the SystemConfig initializer.
//     - Updates the OPCM release setter logic to use the updated initializer.
//  - A `DeployOPChainInterop is DeployOPChain` that allows the updated input parameter to be passed.
//
// Most of the complexity in the above flow comes from the the new input for the updated SystemConfig
// initializer. If all function signatures were the same, all we'd have to change is the contract
// implementations that are deployed then set in the OPCM. For now, to simplify things until we
// resolve https://github.com/ethereum-optimism/optimism/issues/11783, we just assume this new role
// is the same as the proxy admin owner.
contract DeployImplementationsInterop is DeployImplementations {
    function createOPCMContract(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio,
        OPContractsManager.Blueprints memory _blueprints,
        string memory _l1ContractsRelease
    )
        internal
        virtual
        override
        returns (OPContractsManager opcm_)
    {
        ISuperchainConfig superchainConfigProxy = _dii.superchainConfigProxy();
        IProtocolVersions protocolVersionsProxy = _dii.protocolVersionsProxy();

        OPContractsManager.Implementations memory implementations = OPContractsManager.Implementations({
            l1ERC721BridgeImpl: address(_dio.l1ERC721BridgeImpl()),
            optimismPortalImpl: address(_dio.optimismPortalImpl()),
            systemConfigImpl: address(_dio.systemConfigImpl()),
            optimismMintableERC20FactoryImpl: address(_dio.optimismMintableERC20FactoryImpl()),
            l1CrossDomainMessengerImpl: address(_dio.l1CrossDomainMessengerImpl()),
            l1StandardBridgeImpl: address(_dio.l1StandardBridgeImpl()),
            disputeGameFactoryImpl: address(_dio.disputeGameFactoryImpl()),
            delayedWETHImpl: address(_dio.delayedWETHImpl()),
            mipsImpl: address(_dio.mipsSingleton()),
            // [Kroma: START]
            assetManagerImpl: address(_dio.assetManagerImpl()),
            colosseumImpl: address(_dio.colosseumImpl()),
            securityCouncilImpl: address(_dio.securityCouncilImpl()),
            securityCouncilTokenImpl: address(_dio.securityCouncilTokenImpl()),
            timeLockImpl: address(_dio.timeLockImpl()),
            upgradeGovernorImpl: address(_dio.upgradeGovernorImpl()),
            validatorManagerImpl: address(_dio.validatorManagerImpl()),
            zkProofVerifierImpl: address(_dio.zkProofVerifierImpl())
        });
        // [Kroma: END]

        vm.broadcast(msg.sender);
        opcm_ = new OPContractsManagerInterop(
            superchainConfigProxy, protocolVersionsProxy, _l1ContractsRelease, _blueprints, implementations
        );

        vm.label(address(opcm_), "OPContractsManager");
        _dio.set(_dio.opcm.selector, address(opcm_));
    }

    function deployOptimismPortalImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        override
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();
        string memory contractName = "optimism_portal";
        IOptimismPortalInterop impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = IOptimismPortalInterop(payable(existingImplementation));
        } else {
            uint256 proofMaturityDelaySeconds = _dii.proofMaturityDelaySeconds();
            uint256 disputeGameFinalityDelaySeconds = _dii.disputeGameFinalityDelaySeconds();
            vm.broadcast(msg.sender);
            impl = IOptimismPortalInterop(
                DeployUtils.create1({
                    _name: "OptimismPortalInterop",
                    _args: DeployUtils.encodeConstructor(
                        abi.encodeCall(
                            IOptimismPortalInterop.__constructor__,
                            (proofMaturityDelaySeconds, disputeGameFinalityDelaySeconds)
                        )
                    )
                })
            );
        }

        vm.label(address(impl), "OptimismPortalImpl");
        _dio.set(_dio.optimismPortalImpl.selector, address(impl));
    }

    function deploySystemConfigImpl(
        DeployImplementationsInput _dii,
        DeployImplementationsOutput _dio
    )
        public
        override
    {
        string memory release = _dii.l1ContractsRelease();
        string memory stdVerToml = _dii.standardVersionsToml();

        string memory contractName = "system_config";
        ISystemConfigInterop impl;

        address existingImplementation = getReleaseAddress(release, contractName, stdVerToml);
        if (existingImplementation != address(0)) {
            impl = ISystemConfigInterop(existingImplementation);
        } else {
            vm.broadcast(msg.sender);
            impl = ISystemConfigInterop(
                DeployUtils.create1({
                    _name: "SystemConfigInterop",
                    _args: DeployUtils.encodeConstructor(abi.encodeCall(ISystemConfigInterop.__constructor__, ()))
                })
            );
        }

        vm.label(address(impl), "SystemConfigImpl");
        _dio.set(_dio.systemConfigImpl.selector, address(impl));
    }
}
