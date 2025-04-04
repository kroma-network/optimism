// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Testing
import { Vm } from "forge-std/Vm.sol";
import { console2 as console } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";

// Scripts
import { Artifacts } from "scripts/Artifacts.s.sol";
import { Config } from "scripts/libraries/Config.sol";
import { Deployer } from "scripts/deploy/Deployer.sol";
import { KromaDeployer } from "scripts/deploy/kroma/KromaDeployer.sol";
import { KromaChainAssertions } from "scripts/deploy/kroma/KromaChainAssertions.sol";
import { Deploy } from "scripts/deploy/Deploy.s.sol";
import { Deployment } from "scripts/Artifacts.s.sol";

// Contracts
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { KromaL2OutputOracle } from "src/L1/KromaL2OutputOracle.sol";

// Interfaces
import { IKromaL2OutputOracle } from "interfaces/L1/IKromaL2OutputOracle.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IProxy } from "interfaces/universal/IProxy.sol";
import { IProxyAdmin } from "interfaces/universal/IProxyAdmin.sol";
import { IStaticERC1967Proxy } from "interfaces/universal/IStaticERC1967Proxy.sol";
import { IOptimismPortal } from "interfaces/L1/IOptimismPortal.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";

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
    //                    SetUp and Run                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Used for L1 alloc generation.
    function run(Deployment[] memory deployments) public {
        run(deployments, false);
    }

    /// @notice Used for L1 alloc generation.
    function run(Deployment[] memory deployments, bool useMockAssets) public {
        vm.chainId(cfg.l1ChainID());

        // save deployments from previous deploy
        _saveDeployments(deployments);

        _run(useMockAssets);
    }

    /// @notice Used for L1 alloc generation.
    function runWithStateDump(Deployment[] memory deployments) public {
        runWithStateDump(deployments, false);
    }

    /// @notice Used for L1 alloc generation.
    function runWithStateDump(Deployment[] memory deployments, bool useMockAssets) public {
        run(deployments, useMockAssets);
        vm.dumpState(Config.stateDumpPath(""));
    }

    function _run(bool useMockAssets) public {
        console.log("-- [Step 0] Transfer ProxyAdmin ownership");
        IProxyAdmin proxyAdmin = IProxyAdmin(mustGetAddress("ProxyAdmin"));
        vm.startPrank(cfg.finalSystemOwner());
        proxyAdmin.transferOwnership(msg.sender);
        vm.stopPrank();
        console.log("   > Ownership transferred to: %s", msg.sender);

        console.log("-- [Step 1] Deploy implementation contracts");
        // Since the contract is already deployed via deploy.s.sol, we reset the artifacts to start fresh.
        removeDeploymentByName("OptimismPortal");
        KromaDeployer.deployImpls(cfg, Artifacts(this), vm);

        console.log("-- [Step 2] Deploy proxy contracts");
        // Since the contract is already deployed via deploy.s.sol, we reset the artifacts to start fresh.
        removeDeploymentByName("OptimismPortalProxy");
        KromaDeployer.deployProxies(mustGetAddress("ProxyAdmin"), Artifacts(this), vm);
        // update OptimismPortal address in SystemConfig
        bytes32 OPTIMISM_PORTAL_SLOT = ISystemConfig(mustGetAddress("SystemConfigProxy")).OPTIMISM_PORTAL_SLOT();
        vm.store(
            mustGetAddress("SystemConfigProxy"),
            bytes32(OPTIMISM_PORTAL_SLOT),
            bytes32(uint256(uint160(address(mustGetAddress("OptimismPortalProxy")))))
        );

        // update OptimismPortal address in L1CrossDomainMessenger
        vm.store(
            mustGetAddress("L1CrossDomainMessengerProxy"),
            bytes32(uint256(150)),
            bytes32(uint256(uint160(address(mustGetAddress("OptimismPortalProxy")))))
        );

        console.log("-- [Step 3] Adjust tokens for the AssetManager. useMockAssets : %s", useMockAssets);
        if (useMockAssets) {
            MyERC20 assetToken = new MyERC20("Kroma Token", "KRO");
            MyERC721 kgh = new MyERC721("Kroma NFT", "KGH");
            save("AssetToken", address(assetToken));
            save("KGH", address(kgh));
        } else {
            save("AssetToken", cfg.assetManagerToken());
            save("KGH", cfg.assetManagerKgh());
        }

        console.log("-- [Step 4] Upgrade and initialize all proxies");
        KromaDeployer.upgradeAndInitializeProxies(cfg, mustGetAddress, vm);

        console.log("-- [Step 5] Run post-deployment assertions");
        KromaChainAssertions.runPostDeployAssertions(cfg, mustGetAddress, false);
        KromaChainAssertions.runPostDeployAssertions(cfg, mustGetAddress, true);

        console.log("== Deployment completed ==");
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

    function _saveDeployments(Deployment[] memory deployments) internal {
        for (uint256 i = 0; i < deployments.length; i++) {
            save(deployments[i].name, deployments[i].addr);
        }
    }
}

contract MyERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }
}

contract MyERC721 is ERC721 {
    uint256 public nextTokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) { }

    function mint(address to) external {
        _safeMint(to, nextTokenId);
        nextTokenId++;
    }
}
