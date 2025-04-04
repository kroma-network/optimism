// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Testing
import { Setup } from "test/setup/Setup.sol";
import { console2 as console } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

// Scripts
import { Config } from "scripts/libraries/Config.sol";
import { Deployer } from "scripts/deploy/Deployer.sol";
import { Deployment } from "scripts/Artifacts.s.sol";
import { KromaDeployer } from "scripts/deploy/kroma/KromaDeployer.sol";
import { Deploy } from "scripts/deploy/Deploy.s.sol";
import { DeployConfig } from "scripts/deploy/DeployConfig.s.sol";
import { KromaDeploy } from "scripts/deploy/KromaDeploy.s.sol";

// Libraries
import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { StorageSlot, ForgeArtifacts } from "scripts/libraries/ForgeArtifacts.sol";

// Contracts
import { KromaL2OutputOracle } from "src/L1/KromaL2OutputOracle.sol";
import { ProxyAdmin } from "src/universal/ProxyAdmin.sol";

// Interfaces
import { IKromaL2OutputOracle } from "interfaces/L1/IKromaL2OutputOracle.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IProxy } from "interfaces/universal/IProxy.sol";
import { IProxyAdmin } from "interfaces/universal/IProxyAdmin.sol";
import { IOptimismPortal } from "interfaces/L1/IOptimismPortal.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";

/// @title KromaDeployOrchestrator
/// @notice Deployment script for all Kroma L1 contracts.
contract KromaDeployOrchestrator is Script {
    /// @notice The address of the Deploy contract. Set into state with `etch` to avoid
    ///         mutating any nonces. MUST not have constructor logic.
    Deploy internal constant deploy = Deploy(address(uint160(uint256(keccak256(abi.encode("optimism.deploy"))))));
    KromaDeploy internal constant kromaDeploy =
        KromaDeploy(address(uint160(uint256(keccak256(abi.encode("kroma.deploy"))))));

    ////////////////////////////////////////////////////////////////
    //                    SetUp and Run                           //
    ////////////////////////////////////////////////////////////////

    function setUp() public virtual {
        console.log("L1 setup start!");
        vm.etch(address(deploy), vm.getDeployedCode("Deploy.s.sol:Deploy"));
        vm.etch(address(kromaDeploy), vm.getDeployedCode("KromaDeploy.s.sol:KromaDeploy"));
        vm.allowCheatcodes(address(deploy));
        vm.allowCheatcodes(address(kromaDeploy));

        deploy.setUp();
        kromaDeploy.setUp();
    }

    /// @notice Used for L1 alloc generation.
    function runWithStateDump() public {
        deploy.run();
        Deployment[] memory deployments = deploy.newDeployments();
        kromaDeploy.run(deployments, true);
        vm.dumpState(Config.stateDumpPath(""));
    }

    function _run() public {
        deploy.run();
        Deployment[] memory deployments = deploy.newDeployments();
        kromaDeploy.runWithStateDump(deployments, true);
    }
}
