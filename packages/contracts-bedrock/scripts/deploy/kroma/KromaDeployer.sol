// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Scripts
import { Vm } from "forge-std/Vm.sol";
import { console2 as console } from "forge-std/console2.sol";
import { Artifacts } from "scripts/Artifacts.s.sol";

// Libraries
import { KromaDeployUtils } from "scripts/libraries/KromaDeployUtils.sol";
import { KromaInitializers } from "scripts/deploy/kroma/KromaInitializers.sol";
import { DeployConfig } from "scripts/deploy/DeployConfig.s.sol";
import { KromaChainAssertions } from "scripts/deploy/kroma/KromaChainAssertions.sol";

// Interfaces
import { IProxyAdmin } from "interfaces/universal/IProxyAdmin.sol";
import { IProxy } from "interfaces/universal/IProxy.sol";
import { ISP1Verifier } from "interfaces/vendor/sp1/ISP1Verifier.sol";
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { IOptimismPortal } from "interfaces/L1/IOptimismPortal.sol";
import { IKromaL2OutputOracle } from "interfaces/L1/IKromaL2OutputOracle.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";
import { IKromaGovernanceToken } from "interfaces/governance/IKromaGovernanceToken.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";

/// @title KromaDeployer
/// @notice Library for deploying and initializing all Kroma L1 contracts.
/// @dev Called from top-level deployment script (e.g. Deploy.s.sol).
library KromaDeployer {
    /// @notice Deploys all implementation contracts.
    function deployImpls(DeployConfig _cfg, Artifacts artifacts, Vm vm) internal {
        console.log("   > Deploying all implementation contracts");

        deployImpl("KromaL2OutputOracle", abi.encode(), artifacts, vm);
        deployImpl("OptimismPortal", abi.encode(), artifacts, vm);
        deployImpl("AssetManager", abi.encode(), artifacts, vm);
        deployImpl("Colosseum", abi.encode(), artifacts, vm);
        deployImpl("SecurityCouncil", abi.encode(), artifacts, vm);
        deployImpl("SecurityCouncilToken", abi.encode(), artifacts, vm);
        deployImpl("TimeLock", abi.encode(), artifacts, vm);
        deployImpl("UpgradeGovernor", abi.encode(), artifacts, vm);
        deployImpl("ValidatorManager", abi.encode(), artifacts, vm);
        deployImpl(
            "ZKProofVerifier",
            KromaDeployUtils.encodeConstructor(
                abi.encodeCall(
                    IZKProofVerifier.__constructor__,
                    (ISP1Verifier(_cfg.zkProofVerifierSP1Verifier()), _cfg.zkProofVerifierVKey())
                )
            ),
            artifacts,
            vm
        );
    }

    /// @notice Deploys all proxy contracts.
    function deployProxies(address proxyAdmin, Artifacts artifacts, Vm vm) internal {
        console.log("   > [Proxy] Deploying proxy contracts");
        deployERC1967ProxyWithOwner("KromaL2OutputOracleProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("OptimismPortalProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("AssetManagerProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("ColosseumProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("SecurityCouncilProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("SecurityCouncilTokenProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("TimeLockProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("UpgradeGovernorProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("ValidatorManagerProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("ZKProofVerifierProxy", proxyAdmin, artifacts, vm);
        deployERC1967ProxyWithOwner("KromaGovernanceTokenProxy", proxyAdmin, artifacts, vm);
        console.log("    > All proxy contracts deployed");
    }

    /// @notice Upgrades and initializes all proxy contracts with their implementations.
    function upgradeAndInitializeProxies(
        DeployConfig config,
        function(string memory) view returns (address payable) mustGetAddress,
        Vm vm
    )
        internal
    {
        console.log("   > [Upgrade] Initializing and upgrading proxies");
        vm.startBroadcast(msg.sender);
        IProxyAdmin proxyAdmin = IProxyAdmin(payable(mustGetAddress("ProxyAdmin")));
        proxyAdmin.upgradeAndCall({
            _proxy: payable(mustGetAddress("KromaL2OutputOracleProxy")),
            _implementation: mustGetAddress("KromaL2OutputOracle"),
            _data: abi.encodeCall(
                IKromaL2OutputOracle.initialize,
                (
                    mustGetAddress("ValidatorManagerProxy"),
                    mustGetAddress("ColosseumProxy"),
                    config.l2OutputOracleSubmissionInterval(),
                    config.l2BlockTime(),
                    config.l2OutputOracleStartingBlockNumber(),
                    config.l2OutputOracleStartingTimestamp(),
                    config.finalizationPeriodSeconds()
                )
            )
        });
        proxyAdmin.upgradeAndCall({
            _proxy: payable(mustGetAddress("OptimismPortalProxy")),
            _implementation: mustGetAddress("OptimismPortal"),
            _data: abi.encodeCall(
                IOptimismPortal.initialize,
                (
                    IKromaL2OutputOracle(mustGetAddress("KromaL2OutputOracleProxy")),
                    ISystemConfig(mustGetAddress("SystemConfigProxy")),
                    ISuperchainConfig(mustGetAddress("SuperchainConfigProxy"))
                )
            )
        });
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("AssetManagerProxy")),
            mustGetAddress("AssetManager"),
            KromaInitializers.encodeAssetManagerInitializer(config, mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("ColosseumProxy")),
            mustGetAddress("Colosseum"),
            KromaInitializers.encodeColosseumInitializer(config, mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("SecurityCouncilProxy")),
            mustGetAddress("SecurityCouncil"),
            KromaInitializers.encodeSecurityCouncilInitializer(mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("SecurityCouncilTokenProxy")),
            mustGetAddress("SecurityCouncilToken"),
            KromaInitializers.encodeSecurityCouncilTokenInitializer(mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("TimeLockProxy")),
            mustGetAddress("TimeLock"),
            KromaInitializers.encodeTimeLockInitializer(config, mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("UpgradeGovernorProxy")),
            mustGetAddress("UpgradeGovernor"),
            KromaInitializers.encodeUpgradeGovernorInitializer(config, mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("ValidatorManagerProxy")),
            mustGetAddress("ValidatorManager"),
            KromaInitializers.encodeValidatorManagerInitializer(config, mustGetAddress)
        );

        proxyAdmin.upgrade(payable(mustGetAddress("ZKProofVerifierProxy")), mustGetAddress("ZKProofVerifier"));
        vm.stopBroadcast();
        console.log("    > All proxies upgraded and initialized");
    }

    function initializeOptimismPortal(
        DeployConfig,
        Vm vm,
        function(string memory) returns (address) mustGetAddress
    )
        internal
    {
        console.log("Initializing OptimismPortal");
        vm.startBroadcast(msg.sender);
        address optimismPortalProxy = mustGetAddress("OptimismPortalProxy");
        address systemConfigProxy = mustGetAddress("SystemConfigProxy");
        address superchainConfigProxy = mustGetAddress("SuperchainConfigProxy");
        address optimismPortal = mustGetAddress("OptimismPortal");
        address l2OutputOracleProxy = mustGetAddress("KromaL2OutputOracleProxy");

        IProxyAdmin proxyAdmin = IProxyAdmin(payable(mustGetAddress("ProxyAdmin")));
        proxyAdmin.upgradeAndCall({
            _proxy: payable(optimismPortalProxy),
            _implementation: optimismPortal,
            _data: abi.encodeCall(
                IOptimismPortal.initialize,
                (
                    IKromaL2OutputOracle(l2OutputOracleProxy),
                    ISystemConfig(systemConfigProxy),
                    ISuperchainConfig(superchainConfigProxy)
                )
            )
        });
        vm.stopBroadcast();
    }

    ////////////////////////////////////////////////////////////////
    //                   Deployment Functions                     //
    ////////////////////////////////////////////////////////////////

    function deployImpl(
        string memory _name,
        bytes memory _data,
        Artifacts artifacts,
        Vm vm
    )
        internal
        returns (address)
    {
        console.log("Deploying implementation: %s", _name);
        vm.startBroadcast(msg.sender);
        address impl = KromaDeployUtils.create1AndSave(artifacts, _name, _data);
        vm.stopBroadcast();
        vm.label(impl, _name);
        return impl;
    }

    function deployERC1967ProxyWithOwner(
        string memory _name,
        address _proxyOwner,
        Artifacts artifacts,
        Vm vm
    )
        internal
        returns (address addr_)
    {
        console.log("Deploying proxy with owner %s: %s", _proxyOwner, _name);
        vm.startBroadcast(msg.sender);
        IProxy proxy = IProxy(
            KromaDeployUtils.create2AndSave({
                _save: artifacts,
                _salt: keccak256(abi.encode(_proxySalt(), _name)),
                _name: "Proxy",
                _nick: _name,
                _args: KromaDeployUtils.encodeConstructor(abi.encodeCall(IProxy.__constructor__, (_proxyOwner)))
            })
        );
        vm.stopBroadcast();
        addr_ = address(proxy);
    }

    ////////////////////////////////////////////////////////////////
    //                        Accessors                           //
    ////////////////////////////////////////////////////////////////

    /// @notice The CREATE2 salt to be used when deploying the proxy.
    function _proxySalt() internal pure returns (string memory env_) {
        env_ = string("kroma proxy");
    }
}
