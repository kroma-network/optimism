// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IKromaL2OutputOracle } from "interfaces/L1/IKromaL2OutputOracle.sol";
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";
import { IKromaGovernanceToken } from "interfaces/governance/IKromaGovernanceToken.sol";

struct KromaDeployInput {
    // AssetManager
    IERC721 kgh;
    address vault;
    uint128 minDelegationPeriod;
    uint128 bondAmount;
    // Colosseum
    IKromaL2OutputOracle l2OutputOracle;
    uint256 submissionInterval;
    uint256 creationPeriodSeconds;
    uint256 bisectionTimeout;
    uint256 provingTimeout;
    uint256[] segmentsLengths;
    // SecurityCouncil
    uint256 timeLockMinDelaySeconds;
    // UpgradeGovernor
    uint256 initialVotingDelay;
    uint256 initialVotingPeriod;
    uint256 initialProposalThreshold;
    uint256 votesQuorumFraction;
    // ValidatorManager
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
    // ZKProofVerifier
    address zkProofVerifierSP1Verifier;
    bytes32 zkProofVerifierVKey;
}

struct KromaDeployOutput {
    // Proxy
    IAssetManager assetManagerProxy;
    IColosseum colosseumProxy;
    ISecurityCouncil securityCouncilProxy;
    ISecurityCouncilToken securityCouncilTokenProxy;
    ITimeLock timeLockProxy;
    IUpgradeGovernor upgradeGovernorProxy;
    IValidatorManager validatorManagerProxy;
    IZKProofVerifier zkProofVerifierProxy;
    IKromaGovernanceToken kromaGovernanceTokenProxy;
    // Impl
    IAssetManager assetManagerImpl;
    IColosseum colosseumImpl;
    ISecurityCouncil securityCouncilImpl;
    ISecurityCouncilToken securityCouncilTokenImpl;
    ITimeLock timeLockImpl;
    IUpgradeGovernor upgradeGovernorImpl;
    IValidatorManager validatorManagerImpl;
    IZKProofVerifier zkProofVerifierImpl;
    IKromaGovernanceToken kromaGovernanceTokenImpl;
}
