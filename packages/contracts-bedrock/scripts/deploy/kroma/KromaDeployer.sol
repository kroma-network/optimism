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
/// @notice Library for deploying and initializing all Kroma L1 contracts.
/// @dev Called from top-level deployment script (e.g. Deploy.s.sol).
library KromaDeployer {
    /// @notice Deploys all implementation contracts.
    function deployImpls(
        function(string memory, bytes memory) returns (address) deployImpl,
        KromaDeployInput memory input
    )
        internal
        returns (KromaDeployOutput memory output)
    {
        console.log("   > Deploying all implementation contracts");

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

        return output;
    }

    /// @notice Deploys all proxy contracts.
    function deployProxies(
        function(string memory) returns (address) deployProxy,
        KromaDeployOutput memory output
    )
        internal
        returns (KromaDeployOutput memory)
    {
        console.log("   > [Proxy] Deploying proxy contracts");

        output.assetManagerProxy = IAssetManager(payable(deployProxy("AssetManagerProxy")));
        output.colosseumProxy = IColosseum(payable(deployProxy("ColosseumProxy")));
        output.securityCouncilProxy = ISecurityCouncil(payable(deployProxy("SecurityCouncilProxy")));
        output.securityCouncilTokenProxy = ISecurityCouncilToken(payable(deployProxy("SecurityCouncilTokenProxy")));
        output.timeLockProxy = ITimeLock(payable(deployProxy("TimeLockProxy")));
        output.upgradeGovernorProxy = IUpgradeGovernor(payable(deployProxy("UpgradeGovernorProxy")));
        output.validatorManagerProxy = IValidatorManager(payable(deployProxy("ValidatorManagerProxy")));
        output.zkProofVerifierProxy = IZKProofVerifier(payable(deployProxy("ZKProofVerifierProxy")));
        output.kromaGovernanceTokenProxy = IKromaGovernanceToken(payable(deployProxy("KromaGovernanceTokenProxy")));

        console.log("    > All proxy contracts deployed");
        return output;
    }

    /// @notice Upgrades and initializes all proxy contracts with their implementations.
    function upgradeAndInitializeProxies(
        IProxyAdmin proxyAdmin,
        KromaDeployInput memory input,
        function(string memory) view returns (address payable) mustGetAddress,
        Vm vm
    )
        internal
    {
        console.log("   > [Upgrade] Initializing and upgrading proxies");

        vm.startBroadcast(msg.sender);

        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("AssetManagerProxy")),
            mustGetAddress("AssetManager"),
            KromaInitializers.encodeAssetManagerInitializer(input, mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("ColosseumProxy")),
            mustGetAddress("Colosseum"),
            KromaInitializers.encodeColosseumInitializer(input, mustGetAddress)
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
            KromaInitializers.encodeTimeLockInitializer(input, mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("UpgradeGovernorProxy")),
            mustGetAddress("UpgradeGovernor"),
            KromaInitializers.encodeUpgradeGovernorInitializer(input, mustGetAddress)
        );
        proxyAdmin.upgradeAndCall(
            payable(mustGetAddress("ValidatorManagerProxy")),
            mustGetAddress("ValidatorManager"),
            KromaInitializers.encodeValidatorManagerInitializer(input, mustGetAddress)
        );

        proxyAdmin.upgrade(payable(mustGetAddress("ZKProofVerifierProxy")), mustGetAddress("ZKProofVerifier"));

        vm.stopBroadcast();

        console.log("    > All proxies upgraded and initialized");
    }
}
