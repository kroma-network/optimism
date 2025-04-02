// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Forge test utilities
import { console2 as console } from "forge-std/console2.sol";

// Libraries
import { DeployUtils } from "scripts/libraries/DeployUtils.sol";

// Interfaces
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";

// Scripts
import { DeployConfig } from "scripts/deploy/DeployConfig.s.sol";
import { KromaDeployOutput, KromaDeployInput } from "scripts/deploy/kroma/KromaDeployTypes.sol";

/// @title KromaPostDeployAssertions
/// @notice Runs post-deployment validation checks on all Kroma contracts
library KromaPostDeployAssertions {
    /// @notice Verifies correctness of deployed contracts, both proxy and implementation
    /// @param input Deployment input configuration
    /// @param output Deployed contract addresses
    /// @param cfg Deployment configuration
    /// @param isProxy Whether the contracts are proxies
    function runPostDeployAssertions(
        KromaDeployInput memory input,
        KromaDeployOutput memory output,
        DeployConfig cfg,
        bool isProxy
    )
        internal
        view
    {
        console.log("[PostDeploy] Running assertions (isProxy: %s)", isProxy);
        KromaChainAssertions.assertValidAssetManager(input, output, cfg, isProxy);
        KromaChainAssertions.assertValidColosseum(input, output, cfg, isProxy);
        KromaChainAssertions.assertValidSecurityCouncil(input, output, cfg, isProxy);
        KromaChainAssertions.assertValidSecurityCouncilToken(input, output, cfg, isProxy);
        KromaChainAssertions.assertValidTimeLock(input, output, cfg, isProxy);
        KromaChainAssertions.assertValidUpgradeGovernor(input, output, cfg, isProxy);
        KromaChainAssertions.assertValidValidatorManager(input, output, cfg, isProxy);
        KromaChainAssertions.assertValidZKProofVerifier(input, output, cfg, isProxy);
    }
}

/// @title KromaChainAssertions
/// @notice Library containing assertion functions for verifying Kroma contract deployment state.
library KromaChainAssertions {
    function assertValidAssetManager(
        KromaDeployInput memory input,
        KromaDeployOutput memory output,
        DeployConfig,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] AssetManager (isProxy: %s)", _isProxy);
        IAssetManager assetManager;
        if (_isProxy) {
            assetManager = IAssetManager(output.assetManagerProxy);
            require(address(assetManager.ASSET_TOKEN()) == address(output.kromaGovernanceTokenProxy), "ASSETMGR-10");
            require(address(assetManager.assetToken()) == address(output.kromaGovernanceTokenProxy), "ASSETMGR-20");
            require(address(assetManager.KGH()) == address(input.kgh), "ASSETMGR-30");
            require(address(assetManager.kgh()) == address(input.kgh), "ASSETMGR-40");
            require(address(assetManager.SECURITY_COUNCIL()) == address(output.securityCouncilProxy), "ASSETMGR-50");
            require(address(assetManager.securityCouncil()) == address(output.securityCouncilProxy), "ASSETMGR-60");
            require(address(assetManager.VALIDATOR_REWARD_VAULT()) == address(input.vault), "ASSETMGR-70");
            require(address(assetManager.validatorRewardVault()) == address(input.vault), "ASSETMGR-80");
            require(address(assetManager.VALIDATOR_MANAGER()) == address(output.validatorManagerProxy), "ASSETMGR-90");
            require(address(assetManager.validatorManager()) == address(output.validatorManagerProxy), "ASSETMGR-100");
            require(assetManager.MIN_DELEGATION_PERIOD() == input.minDelegationPeriod, "ASSETMGR-110");
            require(assetManager.minDelegationPeriod() == input.minDelegationPeriod, "ASSETMGR-120");
            require(assetManager.BOND_AMOUNT() == input.bondAmount, "ASSETMGR-130");
            require(assetManager.bondAmount() == input.bondAmount, "ASSETMGR-140");
        } else {
            assetManager = IAssetManager(output.assetManagerImpl);
            uint256 slot = uint256(keccak256("unstructured.initializable.initialized")) - 1;
            DeployUtils.assertInitialized(address(assetManager), slot, 0);
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
    }

    function assertValidColosseum(
        KromaDeployInput memory input,
        KromaDeployOutput memory output,
        DeployConfig,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] Colosseum (isProxy: %s)", _isProxy);
        IColosseum colosseum;
        if (_isProxy) {
            colosseum = IColosseum(output.colosseumProxy);
            require(address(colosseum.L2_ORACLE()) == address(input.l2OutputOracle), "COLOSSEUM-10");
            require(address(colosseum.l2Oracle()) == address(input.l2OutputOracle), "COLOSSEUM-20");
            require(address(colosseum.ZK_PROOF_VERIFIER()) == address(output.zkProofVerifierProxy), "COLOSSEUM-30");
            require(address(colosseum.zkProofVerifier()) == address(output.zkProofVerifierProxy), "COLOSSEUM-40");
            require(colosseum.L2_ORACLE_SUBMISSION_INTERVAL() == input.submissionInterval, "COLOSSEUM-50");
            require(colosseum.l2OracleSubmissionInterval() == input.submissionInterval, "COLOSSEUM-60");
            require(colosseum.CREATION_PERIOD_SECONDS() == input.creationPeriodSeconds, "COLOSSEUM-70");
            require(colosseum.creationPeriodSeconds() == input.creationPeriodSeconds, "COLOSSEUM-80");
            require(colosseum.BISECTION_TIMEOUT() == input.bisectionTimeout, "COLOSSEUM-90");
            require(colosseum.bisectionTimeout() == input.bisectionTimeout, "COLOSSEUM-100");
            require(colosseum.PROVING_TIMEOUT() == input.provingTimeout, "COLOSSEUM-110");
            require(colosseum.provingTimeout() == input.provingTimeout, "COLOSSEUM-120");
            require(colosseum.segmentsLengths(0) == input.segmentsLengths[0], "COLOSSEUM-130");
            require(address(colosseum.SECURITY_COUNCIL()) == address(output.securityCouncilProxy), "COLOSSEUM-140");
            require(address(colosseum.securityCouncil()) == address(output.securityCouncilProxy), "COLOSSEUM-150");
        } else {
            colosseum = IColosseum(output.colosseumImpl);
            DeployUtils.assertInitialized(address(colosseum), 0, 0);
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
    }

    function assertValidSecurityCouncil(
        KromaDeployInput memory,
        KromaDeployOutput memory output,
        DeployConfig,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] SecurityCouncil (isProxy: %s)", _isProxy);
        ISecurityCouncil securityCouncil;
        if (_isProxy) {
            securityCouncil = ISecurityCouncil(output.securityCouncilProxy);
            require(securityCouncil.COLOSSEUM() == address(output.colosseumProxy), "SC-10");
            require(securityCouncil.colosseum() == address(output.colosseumProxy), "SC-20");
            require(address(securityCouncil.GOVERNOR()) == address(output.upgradeGovernorProxy), "SC-30");
            require(address(securityCouncil.governor()) == address(output.upgradeGovernorProxy), "SC-40");
        } else {
            securityCouncil = ISecurityCouncil(output.securityCouncilImpl);
            DeployUtils.assertInitialized(address(securityCouncil), 0, 0);
            require(securityCouncil.COLOSSEUM() == address(0), "SC-10");
            require(securityCouncil.colosseum() == address(0), "SC-20");
            require(address(securityCouncil.GOVERNOR()) == address(0), "SC-30");
            require(address(securityCouncil.governor()) == address(0), "SC-40");
        }
    }

    function assertValidSecurityCouncilToken(
        KromaDeployInput memory,
        KromaDeployOutput memory output,
        DeployConfig,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] SecurityCouncilToken (isProxy: %s)", _isProxy);
        ISecurityCouncilToken securityCouncilToken;
        if (_isProxy) {
            securityCouncilToken = ISecurityCouncilToken(output.securityCouncilTokenProxy);
            require(address(securityCouncilToken.owner()) == address(output.upgradeGovernorProxy), "SCT-10");
        } else {
            securityCouncilToken = ISecurityCouncilToken(output.securityCouncilTokenImpl);
            DeployUtils.assertInitialized(address(securityCouncilToken), 0, 0);
            require(address(securityCouncilToken.owner()) == address(0), "SCT-10");
        }
    }

    function assertValidTimeLock(
        KromaDeployInput memory input,
        KromaDeployOutput memory output,
        DeployConfig,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] TimeLock (isProxy: %s)", _isProxy);
        ITimeLock timelock;
        if (_isProxy) {
            timelock = ITimeLock(output.timeLockProxy);
            require(timelock.getMinDelay() == input.timeLockMinDelaySeconds, "TL-10");
        } else {
            timelock = ITimeLock(output.timeLockImpl);
            DeployUtils.assertInitialized(address(timelock), 0, 0);
            require(timelock.getMinDelay() == 0, "TL-10");
        }
    }

    function assertValidUpgradeGovernor(
        KromaDeployInput memory input,
        KromaDeployOutput memory output,
        DeployConfig,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] UpgradeGovernor (isProxy: %s)", _isProxy);
        IUpgradeGovernor governor;
        if (_isProxy) {
            governor = IUpgradeGovernor(output.upgradeGovernorProxy);
            require(address(governor.token()) == address(output.securityCouncilTokenProxy), "UG-10");
            require(address(governor.timelock()) == address(output.timeLockProxy), "UG-20");
            require(governor.votingDelay() == input.initialVotingDelay, "UG-30");
            require(governor.votingPeriod() == input.initialVotingPeriod, "UG-40");
            require(governor.proposalThreshold() == input.initialProposalThreshold, "UG-50");
            require(governor.quorumNumerator() == input.votesQuorumFraction, "UG-60");
        } else {
            governor = IUpgradeGovernor(output.upgradeGovernorImpl);
            DeployUtils.assertInitialized(address(governor), 0, 0);
            require(address(governor.token()) == address(0), "UG-10");
            require(address(governor.timelock()) == address(0), "UG-20");
            require(governor.votingDelay() == 0, "UG-30");
            require(governor.votingPeriod() == 0, "UG-40");
            require(governor.proposalThreshold() == 0, "UG-50");
            require(governor.quorumNumerator() == 0, "UG-60");
        }
    }

    function assertValidValidatorManager(
        KromaDeployInput memory input,
        KromaDeployOutput memory output,
        DeployConfig,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] ValidatorManager (isProxy: %s)", _isProxy);
        IValidatorManager validatorManager;
        if (_isProxy) {
            validatorManager = IValidatorManager(output.validatorManagerProxy);
            require(address(validatorManager.L2_ORACLE()) == address(input.l2OutputOracle), "VM-10");
            require(address(validatorManager.l2Oracle()) == address(input.l2OutputOracle), "VM-20");
            require(address(validatorManager.ASSET_MANAGER()) == address(output.assetManagerProxy), "VM-30");
            require(address(validatorManager.assetManager()) == address(output.assetManagerProxy), "VM-40");
            require(validatorManager.TRUSTED_VALIDATOR() == address(input.trustedValidator), "VM-50");
            require(validatorManager.trustedValidator() == address(input.trustedValidator), "VM-60");
            require(validatorManager.COMMISSION_CHANGE_DELAY_SECONDS() == input.commissionChangeDelaySeconds, "VM-70");
            require(validatorManager.commissionChangeDelaySeconds() == input.commissionChangeDelaySeconds, "VM-80");
            require(validatorManager.ROUND_DURATION_SECONDS() == input.roundDurationSeconds, "VM-90");
            require(validatorManager.roundDurationSeconds() == input.roundDurationSeconds, "VM-100");
            require(validatorManager.SOFT_JAIL_PERIOD_SECONDS() == input.softJailPeriodSeconds, "VM-110");
            require(validatorManager.softJailPeriodSeconds() == input.softJailPeriodSeconds, "VM-120");
            require(validatorManager.HARD_JAIL_PERIOD_SECONDS() == input.hardJailPeriodSeconds, "VM-130");
            require(validatorManager.hardJailPeriodSeconds() == input.hardJailPeriodSeconds, "VM-140");
            require(validatorManager.JAIL_THRESHOLD() == input.jailThreshold, "VM-150");
            require(validatorManager.jailThreshold() == input.jailThreshold, "VM-160");
            require(validatorManager.MAX_OUTPUT_FINALIZATIONS() == input.maxFinalizations, "VM-170");
            require(validatorManager.maxOutputFinalizations() == input.maxFinalizations, "VM-180");
            require(validatorManager.BASE_REWARD() == input.baseReward, "VM-190");
            require(validatorManager.baseReward() == input.baseReward, "VM-200");
            require(validatorManager.MIN_REGISTER_AMOUNT() == input.minRegisterAmount, "VM-210");
            require(validatorManager.minRegisterAmount() == input.minRegisterAmount, "VM-220");
            require(validatorManager.MIN_ACTIVATE_AMOUNT() == input.minActivateAmount, "VM-230");
            require(validatorManager.minActiveAmount() == input.minActivateAmount, "VM-240");
        } else {
            validatorManager = IValidatorManager(output.validatorManagerImpl);
            uint256 slot = uint256(keccak256("unstructured.initializable.initialized")) - 1;
            DeployUtils.assertInitialized(address(validatorManager), slot, 0);
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
    }

    function assertValidZKProofVerifier(
        KromaDeployInput memory input,
        KromaDeployOutput memory output,
        DeployConfig,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] ZKProofVerifier (isProxy: %s)", _isProxy);
        IZKProofVerifier zkProofVerifier;
        if (_isProxy) {
            zkProofVerifier = IZKProofVerifier(output.zkProofVerifierProxy);
            require(address(zkProofVerifier.sp1Verifier()) == address(input.zkProofVerifierSP1Verifier), "ZKP-10");
            require(zkProofVerifier.zkVmProgramVKey() == input.zkProofVerifierVKey, "ZKP-20");
        } else {
            zkProofVerifier = IZKProofVerifier(output.zkProofVerifierImpl);
            require(address(zkProofVerifier.sp1Verifier()) == address(input.zkProofVerifierSP1Verifier), "ZKP-10");
            require(zkProofVerifier.zkVmProgramVKey() == input.zkProofVerifierVKey, "ZKP-20");
        }
    }
}
