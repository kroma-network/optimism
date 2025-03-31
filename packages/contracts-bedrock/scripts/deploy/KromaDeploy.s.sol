// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Testing
import { Vm } from "forge-std/Vm.sol";
import { console2 as console } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { EIP1967Helper } from "test/mocks/EIP1967Helper.sol";

// Scripts
import { Config } from "scripts/libraries/Config.sol";
import { Deployer } from "scripts/deploy/Deployer.sol";
import { KromaDeployer } from "./kroma/KromaDeployer.sol";
import { KromaConfigBuilder } from "./kroma/KromaConfigBuilder.sol";
import { KromaDeployInput, KromaDeployOutput } from "./kroma/KromaDeployTypes.sol";
import { KromaPostDeployAssertions } from "./kroma/KromaChainAssertions.sol";
import { Deploy } from "./Deploy.s.sol";
import { DeployConfig } from "./DeployConfig.s.sol";

// Libraries
import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { StorageSlot, ForgeArtifacts } from "scripts/libraries/ForgeArtifacts.sol";

// Contracts
import { KromaL2OutputOracle } from "src/L1/KromaL2OutputOracle.sol";

// Interfaces
import { IKromaL2OutputOracle } from "interfaces/L1/IKromaL2OutputOracle.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IProxy } from "interfaces/universal/IProxy.sol";
import { IProxyAdmin } from "../../interfaces/universal/IProxyAdmin.sol";
import { IOptimismPortal } from "interfaces/L1/IOptimismPortal.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ProxyAdmin } from "../../src/universal/ProxyAdmin.sol";

/// @title KromaDeploy
/// @notice Deployment script for all Kroma L1 contracts.
contract KromaDeploy is Deployer {

    ////////////////////////////////////////////////////////////////
    //                        Modifiers                           //
    ////////////////////////////////////////////////////////////////

    modifier broadcast() {
        vm.startBroadcast(msg.sender);
        _;
        vm.stopBroadcast();
    }

    ////////////////////////////////////////////////////////////////
    //                        Accessors                           //
    ////////////////////////////////////////////////////////////////

    /// @notice The create2 salt used for deployment of the contract implementations.
    ///         Using this helps to reduce config across networks as the implementation
    ///         addresses will be the same across networks when deployed with create2.
    function _implSalt() internal view returns (bytes32) {
        return keccak256(bytes(Config.implSalt()));
    }

    /// @notice The CREATE2 salt to be used when deploying the proxy.
    function _proxySalt() internal pure returns (string memory env_) {
        env_ = string("kroma proxy");
    }

    ////////////////////////////////////////////////////////////////
    //                    SetUp and Run                           //
    ////////////////////////////////////////////////////////////////

    function runWithStateDump() public {
        console.log("== Starting kroma deployment with state dump ==");
        vm.chainId(cfg.l1ChainID());
        _run();
        vm.dumpState(Config.stateDumpPath(""));
    }

    function run() public {
        console.log("== Starting kroma deployment ==");
        _run();
    }

    function _run() public {
        // load stateDump & deployment addresses
        vm.loadAllocs(Config.stateDumpPath(""));
        string memory addresses = Config.deploymentOutfile();
        if (bytes(addresses).length > 0) {
            console.log("Loading addresses from: %s", addresses);
            _loadAddresses(addresses);
        }

        console.log("-- [Step 0] Transfer ProxyAdmin ownership");
        address finalSystemOwner = cfg.finalSystemOwner();
        vm.startPrank(finalSystemOwner);
        IProxyAdmin proxyAdmin = IProxyAdmin(mustGetAddress("ProxyAdmin"));
        proxyAdmin.transferOwnership(msg.sender);
        console.log("   > Ownership transferred to: %s", msg.sender);
        vm.stopPrank();

        console.log("-- [Step 1] Build deployment input");
        KromaDeployInput memory kromaInput = KromaConfigBuilder.fromConfig(cfg);

        console.log("-- [Step 2] Deploy implementation contracts");
        KromaDeployOutput memory kromaOutput = KromaDeployer.deployImpls(deployImpl, kromaInput);

        console.log("-- [Step 3] Deploy proxy contracts");
        kromaOutput = KromaDeployer.deployProxies(deployERC1967Proxy, kromaOutput);

        console.log("-- [Step 4] Deploy and initialize KromaL2OutputOracle");
        deployERC1967Proxy("KromaL2OutputOracleProxy");
        deployImpl("KromaL2OutputOracle", abi.encode());
        initializeKromaL2OutputOracle();

        console.log("-- [Step 5] Reset and initialize OptimismPortal");
        // Since the contract is already deployed via deploy.s.sol, we reset the artifacts to start fresh.
        removeDeploymentByName("OptimismPortal");
        removeDeploymentByName("OptimismPortalProxy");
        deployERC1967Proxy("OptimismPortalProxy");
        deployImpl("OptimismPortal", abi.encode());
        initializeOptimismPortal();

        console.log("-- [Step 6] Upgrade and initialize all proxies");
        KromaDeployer.upgradeAndInitializeProxies(proxyAdmin, kromaInput, mustGetAddress, vm);

        console.log("-- [Step 7] Run post-deployment assertions");
        KromaPostDeployAssertions.runPostDeployAssertions(kromaInput, kromaOutput, cfg, false);
        KromaPostDeployAssertions.runPostDeployAssertions(kromaInput, kromaOutput, cfg, true);

        console.log("== Deployment completed ==");
    }

    ////////////////////////////////////////////////////////////////
    //                    Initialize Functions                    //
    ////////////////////////////////////////////////////////////////

    function initializeKromaL2OutputOracle() public broadcast {
        console.log("Initializing KromaL2OutputOracle");
        address l2OutputOracleProxy = mustGetAddress("KromaL2OutputOracleProxy");
        address l2OutputOracle = mustGetAddress("KromaL2OutputOracle");
        address validatorManagerProxy = mustGetAddress("ValidatorManagerProxy");
        address colosseumProxy = mustGetAddress("ColosseumProxy");

        IProxyAdmin proxyAdmin = IProxyAdmin(payable(mustGetAddress("ProxyAdmin")));
        proxyAdmin.upgradeAndCall({
            _proxy: payable(l2OutputOracleProxy),
            _implementation: l2OutputOracle,
            _data: abi.encodeCall(
                IKromaL2OutputOracle.initialize,
                (
                    validatorManagerProxy,
                    colosseumProxy,
                    cfg.l2OutputOracleSubmissionInterval(),
                    cfg.l2BlockTime(),
                    cfg.l2OutputOracleStartingBlockNumber(),
                    cfg.l2OutputOracleStartingTimestamp(),
                    cfg.finalizationPeriodSeconds()
                )
            )
        });
    }

    function initializeOptimismPortal() public broadcast {
        console.log("Initializing OptimismPortal");
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
    }

    ////////////////////////////////////////////////////////////////
    //                   Deployment Functions                     //
    ////////////////////////////////////////////////////////////////

    function deployImpl(string memory _name, bytes memory _data) internal returns (address) {
        console.log("Deploying implementation: %s", _name);
        vm.startBroadcast(msg.sender);
        address impl = DeployUtils.create1({ _name: _name, _args: _data });
        save(_name, impl);
        vm.stopBroadcast();
        vm.label(impl, _name);
        return impl;
    }

    function deployERC1967Proxy(string memory _name) public returns (address addr_) {
        console.log("Deploying proxy: %s", _name);
        addr_ = deployERC1967ProxyWithOwner(_name, mustGetAddress("ProxyAdmin"));
    }

    function deployERC1967ProxyWithOwner(
        string memory _name,
        address _proxyOwner
    )
        public
        broadcast
        returns (address addr_)
    {
        console.log("Deploying proxy with owner %s: %s", _proxyOwner, _name);
        IProxy proxy = IProxy(
            DeployUtils.create2AndSave({
                _save: this,
                _salt: keccak256(abi.encode(_proxySalt(), _name)),
                _name: "Proxy",
                _nick: _name,
                _args: DeployUtils.encodeConstructor(abi.encodeCall(IProxy.__constructor__, (_proxyOwner)))
            })
        );
        require(EIP1967Helper.getAdmin(address(proxy)) == _proxyOwner);
        addr_ = address(proxy);
    }

    ////////////////////////////////////////////////////////////////
    //                     Util Functions                         //
    ////////////////////////////////////////////////////////////////

    function removeDeploymentByName(string memory targetName) internal {
        delete _namedDeployments[targetName];
        uint256 len = _newDeployments.length;
        for (uint256 i = 0; i < len; i++) {
            if (keccak256(bytes(_newDeployments[i].name)) == keccak256(bytes(targetName))) {
                // Shift elements to the left
                for (uint256 j = i; j < len - 1; j++) {
                    _newDeployments[j] = _newDeployments[j + 1];
                }
                _newDeployments.pop();
                return;
            }
        }
    }
}
