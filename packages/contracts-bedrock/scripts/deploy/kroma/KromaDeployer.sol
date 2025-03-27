// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Scripts
import { Vm } from "forge-std/Vm.sol";
import { console2 as console } from "forge-std/console2.sol";

// Libraries
import { DeployUtils } from "scripts/libraries/DeployUtils.sol";
import { KromaInitializers } from "scripts/deploy/kroma/KromaInitializers.sol";
import { KromaDeployInput, KromaDeployOutput } from "scripts/deploy/kroma/KromaDeployTypes.sol";
import { KromaChainAssertions } from "scripts/deploy/kroma/KromaChainAssertions.sol";

// Interfaces
import { IProxyAdmin } from "interfaces/universal/IProxyAdmin.sol";
import { IProxy } from "interfaces/universal/IProxy.sol";
import { ISP1Verifier } from "interfaces/vendor/sp1/ISP1Verifier.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IL2OutputOracle } from "interfaces/L1/IL2OutputOracle.sol";
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";
import { IKromaGovernanceToken } from "interfaces/governance/IKromaGovernanceToken.sol";

/// @title KromaDeployer
/// @notice Deploys and initializes all contracts related to the Kroma L1 system.
///         This includes both implementation contracts and proxies.
/// @dev Used as a library from top-level deploy scripts like `deploy.s.sol`.
library KromaDeployer {
    /// @notice Deploys all Kroma L1 contracts as proxy patterns and sets initial logic/ownership.
    /// @param deployProxy Function used to deploy EIP-1967 proxy instances.
    /// @param deployImpl Function used to deploy logic (implementation) contracts.
    /// @param proxyAdmin The ProxyAdmin contract managing upgrade rights.
    /// @param input Struct containing deployment and initialization parameters.
    /// @param vm Forge's cheatcode interface for broadcast control.
    /// @return output Struct containing all deployed proxy contract addresses.
    function deployAll(
        function(string memory) returns (address) deployProxy,
        function(string memory, bytes memory) returns (address) deployImpl,
        IProxyAdmin proxyAdmin,
        KromaDeployInput memory input,
        Vm vm
    )
        internal
        returns (KromaDeployOutput memory output)
    {
        console.log("[Kroma Deploy] Deploying implementations...");

        // ========== Implementation Contracts ========== //
        output.assetManagerImpl = IAssetManager(deployImpl("AssetManager", abi.encode()));
        output.colosseumImpl = IColosseum(deployImpl("Colosseum", abi.encode()));
        output.securityCouncilImpl = ISecurityCouncil(deployImpl("SecurityCouncil", abi.encode()));
        output.securityCouncilTokenImpl = ISecurityCouncilToken(deployImpl("SecurityCouncilToken", abi.encode()));
        output.timeLockImpl = ITimeLock(payable(deployImpl("TimeLock", abi.encode())));
        output.upgradeGovernorImpl = IUpgradeGovernor(payable(deployImpl("UpgradeGovernor", abi.encode())));
        output.validatorManagerImpl = IValidatorManager(deployImpl("ValidatorManager", abi.encode()));

        output.zkProofVerifierImpl = IZKProofVerifier(
            deployImpl(
                "ZKProofVerifier",
                DeployUtils.encodeConstructor(
                    abi.encodeCall(
                        IZKProofVerifier.__constructor__,
                        (ISP1Verifier(input.zkProofVerifierSP1Verifier), input.zkProofVerifierVKey)
                    )
                )
            )
        );

        console.log("[Kroma Deploy] Deploying proxies...");

        output.assetManagerProxy = IAssetManager(payable(deployProxy("AssetManagerProxy")));
        output.colosseumProxy = IColosseum(payable(deployProxy("ColosseumProxy")));
        output.securityCouncilProxy = ISecurityCouncil(payable(deployProxy("SecurityCouncilProxy")));
        output.securityCouncilTokenProxy = ISecurityCouncilToken(payable(deployProxy("SecurityCouncilTokenProxy")));
        output.timeLockProxy = ITimeLock(payable(deployProxy("TimeLockProxy")));
        output.upgradeGovernorProxy = IUpgradeGovernor(payable(deployProxy("UpgradeGovernorProxy")));
        output.validatorManagerProxy = IValidatorManager(payable(deployProxy("ValidatorManagerProxy")));
        output.zkProofVerifierProxy = IZKProofVerifier(payable(deployProxy("ZKProofVerifierProxy")));
        output.kromaGovernanceTokenProxy = IKromaGovernanceToken(payable(deployProxy("KromaGovernanceTokenProxy")));

        console.log("[Kroma Deploy] Proxies deployed.");

        // ========== Proxy Upgrade & Initialization ========== //
        console.log("[Kroma Deploy] Upgrading and initializing proxies...");

        vm.startBroadcast();

        proxyAdmin.upgradeAndCall(
            payable(address(output.assetManagerProxy)),
            address(output.assetManagerImpl),
            KromaInitializers.encodeAssetManagerInitializer(input, output)
        );
        proxyAdmin.upgradeAndCall(
            payable(address(output.colosseumProxy)),
            address(output.colosseumImpl),
            KromaInitializers.encodeColosseumInitializer(input, output)
        );
        proxyAdmin.upgradeAndCall(
            payable(address(output.securityCouncilProxy)),
            address(output.securityCouncilImpl),
            KromaInitializers.encodeSecurityCouncilInitializer(output)
        );
        proxyAdmin.upgradeAndCall(
            payable(address(output.securityCouncilTokenProxy)),
            address(output.securityCouncilTokenImpl),
            KromaInitializers.encodeSecurityCouncilTokenInitializer(output)
        );
        proxyAdmin.upgradeAndCall(
            payable(address(output.timeLockProxy)),
            address(output.timeLockImpl),
            KromaInitializers.encodeTimeLockInitializer(input, output)
        );
        proxyAdmin.upgradeAndCall(
            payable(address(output.upgradeGovernorProxy)),
            address(output.upgradeGovernorImpl),
            KromaInitializers.encodeUpgradeGovernorInitializer(input, output)
        );
        proxyAdmin.upgradeAndCall(
            payable(address(output.validatorManagerProxy)),
            address(output.validatorManagerImpl),
            KromaInitializers.encodeValidatorManagerInitializer(input, output)
        );
        proxyAdmin.upgrade(payable(address(output.zkProofVerifierProxy)), address(output.zkProofVerifierImpl));

        vm.stopBroadcast();

        console.log("[Kroma Deploy] All contracts deployed, initialized, and verified successfully.");

        return output;
    }
}
