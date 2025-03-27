// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Scripts
import { KromaDeployInput } from "scripts/deploy/kroma/KromaDeployTypes.sol";
import { DeployConfig } from "scripts/deploy/DeployConfig.s.sol";
import { Deploy } from "scripts/deploy/Deploy.s.sol";

// Interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IL2OutputOracle } from "interfaces/L1/IL2OutputOracle.sol";

/// @title KromaConfigBuilder
/// @notice Builds a KromaDeployInput struct from an existing DeployConfig contract
library KromaConfigBuilder {
    /// @notice Builds a KromaDeployInput from DeployConfig
    /// @param cfg The loaded DeployConfig instance
    /// @return input The populated KromaDeployInput
    function fromConfig(DeployConfig cfg) internal view returns (KromaDeployInput memory) {
        return KromaDeployInput({
            kgh: IERC721(cfg.assetManagerKgh()),
            vault: cfg.assetManagerVault(),
            minDelegationPeriod: cfg.assetManagerMinDelegationPeriod(),
            bondAmount: cfg.assetManagerBondAmount(),
            l2OutputOracle: IL2OutputOracle(address(0)),
            submissionInterval: cfg.l2OutputOracleSubmissionInterval(),
            creationPeriodSeconds: cfg.colosseumCreationPeriodSeconds(),
            bisectionTimeout: cfg.colosseumBisectionTimeout(),
            provingTimeout: cfg.colosseumProvingTimeout(),
            segmentsLengths: cfg.getColosseumSegmentsLengths(),
            timeLockMinDelaySeconds: cfg.timeLockMinDelaySeconds(),
            initialVotingDelay: cfg.governorVotingDelayBlocks(),
            initialVotingPeriod: cfg.governorVotingPeriodBlocks(),
            initialProposalThreshold: cfg.governorProposalThreshold(),
            votesQuorumFraction: cfg.governorVotesQuorumFractionPercent(),
            trustedValidator: cfg.validatorManagerTrustedValidator(),
            minRegisterAmount: cfg.validatorManagerMinRegisterAmount(),
            minActivateAmount: cfg.validatorManagerMinActivateAmount(),
            commissionChangeDelaySeconds: cfg.validatorManagerCommissionChangeDelaySeconds(),
            roundDurationSeconds: cfg.validatorManagerRoundDurationSeconds(),
            softJailPeriodSeconds: cfg.validatorManagerSoftJailPeriodSeconds(),
            hardJailPeriodSeconds: cfg.validatorManagerHardJailPeriodSeconds(),
            jailThreshold: cfg.validatorManagerJailThreshold(),
            maxFinalizations: cfg.validatorManagerMaxFinalizations(),
            baseReward: cfg.validatorManagerBaseReward(),
            zkProofVerifierSP1Verifier: cfg.zkProofVerifierSP1Verifier(),
            zkProofVerifierVKey: cfg.zkProofVerifierVKey()
        });
    }
}
