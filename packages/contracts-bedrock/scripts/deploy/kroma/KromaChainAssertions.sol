// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Forge test utilities
import { console2 as console } from "forge-std/console2.sol";

// Libraries
import { KromaDeployUtils } from "scripts/libraries/KromaDeployUtils.sol";

// Interfaces
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";
import { IKromaL2OutputOracle } from "interfaces/L1/IKromaL2OutputOracle.sol";

// Scripts
import { DeployConfig } from "scripts/deploy/DeployConfig.s.sol";

/// @title KromaChainAssertions
/// @notice Library containing assertion functions for verifying Kroma contract deployment state.
library KromaChainAssertions {
    uint256 internal constant unstructuredSlot = uint256(keccak256("unstructured.initializable.initialized")) - 1;

    /// @notice Verifies correctness of deployed contracts, both proxy and implementation
    /// @param _cfg Deployment configuration
    /// @param isProxy Whether the contracts are proxies
    function runPostDeployAssertions(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress,
        bool isProxy
    )
        internal
    {
        console.log("[PostDeploy] Running assertions (isProxy: %s)", isProxy);
        checkL2OutputOracle(_cfg, mustGetAddress, isProxy);
        checkAssetManager(_cfg, mustGetAddress, isProxy);
        checkColosseum(_cfg, mustGetAddress, isProxy);
        checkSecurityCouncil(_cfg, mustGetAddress, isProxy);
        checkSecurityCouncilToken(_cfg, mustGetAddress, isProxy);
        checkTimeLock(_cfg, mustGetAddress, isProxy);
        checkUpgradeGovernor(_cfg, mustGetAddress, isProxy);
        checkValidatorManager(_cfg, mustGetAddress, isProxy);
        checkZKProofVerifier(_cfg, mustGetAddress, isProxy);
    }

    /// @notice Asserts that the L2OutputOracle is setup correctly
    function checkL2OutputOracle(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
    {
        IKromaL2OutputOracle oracle;
        if (_isProxy) {
            oracle = IKromaL2OutputOracle(mustGetAddress("KromaL2OutputOracleProxy"));
            KromaDeployUtils.assertInitialized(address(oracle), 0, 0);
            require(address(oracle) != address(0), "CHECK-L2OO-10");
            require(oracle.SUBMISSION_INTERVAL() == _cfg.l2OutputOracleSubmissionInterval(), "CHECK-L2OO-20");
            require(oracle.submissionInterval() == _cfg.l2OutputOracleSubmissionInterval(), "CHECK-L2OO-30");
            require(oracle.L2_BLOCK_TIME() == _cfg.l2BlockTime(), "CHECK-L2OO-40");
            require(oracle.l2BlockTime() == _cfg.l2BlockTime(), "CHECK-L2OO-50");
            require(oracle.COLOSSEUM() == mustGetAddress("ColosseumProxy"), "CHECK-L2OO-60");
            require(oracle.colosseum() == mustGetAddress("ColosseumProxy"), "CHECK-L2OO-70");
            require(address(oracle.VALIDATOR_MANAGER()) == mustGetAddress("ValidatorManagerProxy"), "CHECK-L2OO-80");
            require(address(oracle.validatorManager()) == mustGetAddress("ValidatorManagerProxy"), "CHECK-L2OO-90");
            require(oracle.FINALIZATION_PERIOD_SECONDS() == _cfg.finalizationPeriodSeconds(), "CHECK-L2OO-100");
            require(oracle.finalizationPeriodSeconds() == _cfg.finalizationPeriodSeconds(), "CHECK-L2OO-110");
            require(oracle.startingBlockNumber() == _cfg.l2OutputOracleStartingBlockNumber(), "CHECK-L2OO-120");
            require(oracle.startingTimestamp() == _cfg.l2OutputOracleStartingTimestamp(), "CHECK-L2OO-130");
        } else {
            oracle = IKromaL2OutputOracle(mustGetAddress("KromaL2OutputOracle"));
            KromaDeployUtils.assertInitialized(address(oracle), 0, 0);
            require(address(oracle) != address(0), "CHECK-L2OO-140");
            require(oracle.SUBMISSION_INTERVAL() == 1, "CHECK-L2OO-150");
            require(oracle.submissionInterval() == 1, "CHECK-L2OO-160");
            require(oracle.L2_BLOCK_TIME() == 1, "CHECK-L2OO-170");
            require(oracle.l2BlockTime() == 1, "CHECK-L2OO-180");
            require(oracle.COLOSSEUM() == address(0), "CHECK-L2OO-190");
            require(oracle.colosseum() == address(0), "CHECK-L2OO-200");
            require(address(oracle.VALIDATOR_MANAGER()) == address(0), "CHECK-L2OO-210");
            require(address(oracle.validatorManager()) == address(0), "CHECK-L2OO-220");
            require(oracle.FINALIZATION_PERIOD_SECONDS() == 0, "CHECK-L2OO-230");
            require(oracle.finalizationPeriodSeconds() == 0, "CHECK-L2OO-240");
            require(oracle.startingBlockNumber() == 0, "CHECK-L2OO-250");
            require(oracle.startingTimestamp() == 0, "CHECK-L2OO-260");
        }
    }

    function checkAssetManager(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] AssetManager (isProxy: %s)", _isProxy);
        IAssetManager assetManager;
        if (_isProxy) {
            assetManager = IAssetManager(mustGetAddress("AssetManagerProxy"));
            KromaDeployUtils.assertInitialized(address(assetManager), unstructuredSlot, 0);
            require(address(assetManager.ASSET_TOKEN()) == mustGetAddress("AssetToken"), "ASSETMGR-10");
            require(address(assetManager.assetToken()) == mustGetAddress("AssetToken"), "ASSETMGR-20");
            require(address(assetManager.KGH()) == mustGetAddress("KGH"), "ASSETMGR-30");
            require(address(assetManager.kgh()) == mustGetAddress("KGH"), "ASSETMGR-40");
            require(address(assetManager.SECURITY_COUNCIL()) == mustGetAddress("SecurityCouncilProxy"), "ASSETMGR-50");
            require(address(assetManager.securityCouncil()) == mustGetAddress("SecurityCouncilProxy"), "ASSETMGR-60");
            require(address(assetManager.VALIDATOR_REWARD_VAULT()) == _cfg.assetManagerVault(), "ASSETMGR-70");
            require(address(assetManager.validatorRewardVault()) == _cfg.assetManagerVault(), "ASSETMGR-80");
            require(address(assetManager.VALIDATOR_MANAGER()) == mustGetAddress("ValidatorManagerProxy"), "ASSETMGR-90");
            require(address(assetManager.validatorManager()) == mustGetAddress("ValidatorManagerProxy"), "ASSETMGR-100");
            require(assetManager.MIN_DELEGATION_PERIOD() == _cfg.assetManagerMinDelegationPeriod(), "ASSETMGR-110");
            require(assetManager.minDelegationPeriod() == _cfg.assetManagerMinDelegationPeriod(), "ASSETMGR-120");
            require(assetManager.BOND_AMOUNT() == _cfg.assetManagerBondAmount(), "ASSETMGR-130");
            require(assetManager.bondAmount() == _cfg.assetManagerBondAmount(), "ASSETMGR-140");
        } else {
            assetManager = IAssetManager(mustGetAddress("AssetManager"));
            KromaDeployUtils.assertInitialized(address(assetManager), unstructuredSlot, 0);
            require(address(assetManager.ASSET_TOKEN()) == address(0), "ASSETMGR-150");
            require(address(assetManager.assetToken()) == address(0), "ASSETMGR-160");
            require(address(assetManager.KGH()) == address(0), "ASSETMGR-170");
            require(address(assetManager.kgh()) == address(0), "ASSETMGR-180");
            require(address(assetManager.SECURITY_COUNCIL()) == address(0), "ASSETMGR-190");
            require(address(assetManager.securityCouncil()) == address(0), "ASSETMGR-200");
            require(address(assetManager.VALIDATOR_REWARD_VAULT()) == address(0), "ASSETMGR-210");
            require(address(assetManager.validatorRewardVault()) == address(0), "ASSETMGR-220");
            require(address(assetManager.VALIDATOR_MANAGER()) == address(0), "ASSETMGR-230");
            require(address(assetManager.validatorManager()) == address(0), "ASSETMGR-240");
            require(assetManager.MIN_DELEGATION_PERIOD() == 0, "ASSETMGR-250");
            require(assetManager.minDelegationPeriod() == 0, "ASSETMGR-260");
            require(assetManager.BOND_AMOUNT() == 0, "ASSETMGR-270");
            require(assetManager.bondAmount() == 0, "ASSETMGR-280");
        }
    }

    function checkColosseum(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] Colosseum (isProxy: %s)", _isProxy);
        IColosseum colosseum;
        if (_isProxy) {
            colosseum = IColosseum(mustGetAddress("ColosseumProxy"));
            KromaDeployUtils.assertInitialized(address(colosseum), 0, 0);
            require(address(colosseum.L2_ORACLE()) == mustGetAddress("KromaL2OutputOracleProxy"), "COLOSSEUM-10");
            require(address(colosseum.l2Oracle()) == mustGetAddress("KromaL2OutputOracleProxy"), "COLOSSEUM-20");
            require(address(colosseum.ZK_PROOF_VERIFIER()) == mustGetAddress("ZKProofVerifierProxy"), "COLOSSEUM-30");
            require(address(colosseum.zkProofVerifier()) == mustGetAddress("ZKProofVerifierProxy"), "COLOSSEUM-40");
            require(
                colosseum.L2_ORACLE_SUBMISSION_INTERVAL() == _cfg.l2OutputOracleSubmissionInterval(), "COLOSSEUM-50"
            );
            require(colosseum.l2OracleSubmissionInterval() == _cfg.l2OutputOracleSubmissionInterval(), "COLOSSEUM-60");
            require(colosseum.CREATION_PERIOD_SECONDS() == _cfg.colosseumCreationPeriodSeconds(), "COLOSSEUM-70");
            require(colosseum.creationPeriodSeconds() == _cfg.colosseumCreationPeriodSeconds(), "COLOSSEUM-80");
            require(colosseum.BISECTION_TIMEOUT() == _cfg.colosseumBisectionTimeout(), "COLOSSEUM-90");
            require(colosseum.bisectionTimeout() == _cfg.colosseumBisectionTimeout(), "COLOSSEUM-100");
            require(colosseum.PROVING_TIMEOUT() == _cfg.colosseumProvingTimeout(), "COLOSSEUM-110");
            require(colosseum.provingTimeout() == _cfg.colosseumProvingTimeout(), "COLOSSEUM-120");
            require(colosseum.segmentsLengths(0) == _cfg.getColosseumSegmentsLengths()[0], "COLOSSEUM-130");
            require(address(colosseum.SECURITY_COUNCIL()) == mustGetAddress("SecurityCouncilProxy"), "COLOSSEUM-140");
            require(address(colosseum.securityCouncil()) == mustGetAddress("SecurityCouncilProxy"), "COLOSSEUM-150");
        } else {
            colosseum = IColosseum(mustGetAddress("Colosseum"));
            KromaDeployUtils.assertInitialized(address(colosseum), 0, 0);
            require(address(colosseum.L2_ORACLE()) == address(0), "COLOSSEUM-160");
            require(address(colosseum.l2Oracle()) == address(0), "COLOSSEUM-170");
            require(address(colosseum.ZK_PROOF_VERIFIER()) == address(0), "COLOSSEUM-180");
            require(address(colosseum.zkProofVerifier()) == address(0), "COLOSSEUM-190");
            require(colosseum.L2_ORACLE_SUBMISSION_INTERVAL() == 0, "COLOSSEUM-200");
            require(colosseum.l2OracleSubmissionInterval() == 0, "COLOSSEUM-210");
            require(colosseum.CREATION_PERIOD_SECONDS() == 0, "COLOSSEUM-220");
            require(colosseum.creationPeriodSeconds() == 0, "COLOSSEUM-230");
            require(colosseum.BISECTION_TIMEOUT() == 0, "COLOSSEUM-240");
            require(colosseum.bisectionTimeout() == 0, "COLOSSEUM-250");
            require(colosseum.PROVING_TIMEOUT() == 0, "COLOSSEUM-260");
            require(colosseum.provingTimeout() == 0, "COLOSSEUM-270");
            require(colosseum.segmentsLengths(0) == 0, "COLOSSEUM-280");
            require(address(colosseum.SECURITY_COUNCIL()) == address(0), "COLOSSEUM-290");
            require(address(colosseum.securityCouncil()) == address(0), "COLOSSEUM-300");
        }
    }

    function checkSecurityCouncil(
        DeployConfig,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] SecurityCouncil (isProxy: %s)", _isProxy);
        ISecurityCouncil securityCouncil;
        if (_isProxy) {
            securityCouncil = ISecurityCouncil(mustGetAddress("SecurityCouncilProxy"));
            KromaDeployUtils.assertInitialized(address(securityCouncil), 0, 0);
            require(securityCouncil.COLOSSEUM() == mustGetAddress("ColosseumProxy"), "SC-10");
            require(securityCouncil.colosseum() == mustGetAddress("ColosseumProxy"), "SC-20");
            require(address(securityCouncil.GOVERNOR()) == mustGetAddress("UpgradeGovernorProxy"), "SC-30");
            require(address(securityCouncil.governor()) == mustGetAddress("UpgradeGovernorProxy"), "SC-40");
        } else {
            securityCouncil = ISecurityCouncil(mustGetAddress("SecurityCouncil"));
            KromaDeployUtils.assertInitialized(address(securityCouncil), 0, 0);
            require(securityCouncil.COLOSSEUM() == address(0), "SC-50");
            require(securityCouncil.colosseum() == address(0), "SC-60");
            require(address(securityCouncil.GOVERNOR()) == address(0), "SC-70");
            require(address(securityCouncil.governor()) == address(0), "SC-80");
        }
    }

    function checkSecurityCouncilToken(
        DeployConfig,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] SecurityCouncilToken (isProxy: %s)", _isProxy);
        ISecurityCouncilToken securityCouncilToken;
        if (_isProxy) {
            securityCouncilToken = ISecurityCouncilToken(mustGetAddress("SecurityCouncilTokenProxy"));
            KromaDeployUtils.assertInitialized(address(securityCouncilToken), 0, 0);
            require(address(securityCouncilToken.owner()) == mustGetAddress("UpgradeGovernorProxy"), "SCT-10");
        } else {
            securityCouncilToken = ISecurityCouncilToken(mustGetAddress("SecurityCouncilToken"));
            KromaDeployUtils.assertInitialized(address(securityCouncilToken), 0, 0);
            require(address(securityCouncilToken.owner()) == address(0), "SCT-20");
        }
    }

    function checkTimeLock(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] TimeLock (isProxy: %s)", _isProxy);
        ITimeLock timelock;
        if (_isProxy) {
            timelock = ITimeLock(mustGetAddress("TimeLockProxy"));
            KromaDeployUtils.assertInitialized(address(timelock), 0, 0);
            require(timelock.getMinDelay() == _cfg.timeLockMinDelaySeconds(), "TL-10");
        } else {
            timelock = ITimeLock(mustGetAddress("TimeLock"));
            KromaDeployUtils.assertInitialized(address(timelock), 0, 0);
            require(timelock.getMinDelay() == 0, "TL-20");
        }
    }

    function checkUpgradeGovernor(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] UpgradeGovernor (isProxy: %s)", _isProxy);
        IUpgradeGovernor governor;
        if (_isProxy) {
            governor = IUpgradeGovernor(mustGetAddress("UpgradeGovernorProxy"));
            KromaDeployUtils.assertInitialized(address(governor), 0, 0);
            require(address(governor.token()) == mustGetAddress("SecurityCouncilTokenProxy"), "UG-10");
            require(address(governor.timelock()) == mustGetAddress("TimeLockProxy"), "UG-20");
            require(governor.votingDelay() == _cfg.governorVotingDelayBlocks(), "UG-30");
            require(governor.votingPeriod() == _cfg.governorVotingPeriodBlocks(), "UG-40");
            require(governor.proposalThreshold() == _cfg.governorProposalThreshold(), "UG-50");
            require(governor.quorumNumerator() == _cfg.governorVotesQuorumFractionPercent(), "UG-60");
        } else {
            governor = IUpgradeGovernor(mustGetAddress("UpgradeGovernor"));
            KromaDeployUtils.assertInitialized(address(governor), 0, 0);
            require(address(governor.token()) == address(0), "UG-70");
            require(address(governor.timelock()) == address(0), "UG-80");
            require(governor.votingDelay() == 0, "UG-90");
            require(governor.votingPeriod() == 0, "UG-100");
            require(governor.proposalThreshold() == 0, "UG-110");
            require(governor.quorumNumerator() == 0, "UG-120");
        }
    }

    function checkValidatorManager(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] ValidatorManager (isProxy: %s)", _isProxy);
        IValidatorManager validatorManager;
        if (_isProxy) {
            validatorManager = IValidatorManager(mustGetAddress("ValidatorManagerProxy"));
            KromaDeployUtils.assertInitialized(address(validatorManager), unstructuredSlot, 0);
            require(address(validatorManager.L2_ORACLE()) == mustGetAddress("KromaL2OutputOracleProxy"), "VM-10");
            require(address(validatorManager.l2Oracle()) == mustGetAddress("KromaL2OutputOracleProxy"), "VM-20");
            require(address(validatorManager.ASSET_MANAGER()) == mustGetAddress("AssetManagerProxy"), "VM-30");
            require(address(validatorManager.assetManager()) == mustGetAddress("AssetManagerProxy"), "VM-40");
            require(validatorManager.TRUSTED_VALIDATOR() == _cfg.validatorManagerTrustedValidator(), "VM-50");
            require(validatorManager.trustedValidator() == _cfg.validatorManagerTrustedValidator(), "VM-60");
            require(
                validatorManager.COMMISSION_CHANGE_DELAY_SECONDS()
                    == _cfg.validatorManagerCommissionChangeDelaySeconds(),
                "VM-70"
            );
            require(
                validatorManager.commissionChangeDelaySeconds() == _cfg.validatorManagerCommissionChangeDelaySeconds(),
                "VM-80"
            );
            require(validatorManager.ROUND_DURATION_SECONDS() == _cfg.validatorManagerRoundDurationSeconds(), "VM-90");
            require(validatorManager.roundDurationSeconds() == _cfg.validatorManagerRoundDurationSeconds(), "VM-100");
            require(
                validatorManager.SOFT_JAIL_PERIOD_SECONDS() == _cfg.validatorManagerSoftJailPeriodSeconds(), "VM-110"
            );
            require(validatorManager.softJailPeriodSeconds() == _cfg.validatorManagerSoftJailPeriodSeconds(), "VM-120");
            require(
                validatorManager.HARD_JAIL_PERIOD_SECONDS() == _cfg.validatorManagerHardJailPeriodSeconds(), "VM-130"
            );
            require(validatorManager.hardJailPeriodSeconds() == _cfg.validatorManagerHardJailPeriodSeconds(), "VM-140");
            require(validatorManager.JAIL_THRESHOLD() == _cfg.validatorManagerJailThreshold(), "VM-150");
            require(validatorManager.jailThreshold() == _cfg.validatorManagerJailThreshold(), "VM-160");
            require(validatorManager.MAX_OUTPUT_FINALIZATIONS() == _cfg.validatorManagerMaxFinalizations(), "VM-170");
            require(validatorManager.maxOutputFinalizations() == _cfg.validatorManagerMaxFinalizations(), "VM-180");
            require(validatorManager.BASE_REWARD() == _cfg.validatorManagerBaseReward(), "VM-190");
            require(validatorManager.baseReward() == _cfg.validatorManagerBaseReward(), "VM-200");
            require(validatorManager.MIN_REGISTER_AMOUNT() == _cfg.validatorManagerMinRegisterAmount(), "VM-210");
            require(validatorManager.minRegisterAmount() == _cfg.validatorManagerMinRegisterAmount(), "VM-220");
            require(validatorManager.MIN_ACTIVATE_AMOUNT() == _cfg.validatorManagerMinActivateAmount(), "VM-230");
            require(validatorManager.minActiveAmount() == _cfg.validatorManagerMinActivateAmount(), "VM-240");
        } else {
            validatorManager = IValidatorManager(mustGetAddress("ValidatorManager"));
            KromaDeployUtils.assertInitialized(address(validatorManager), unstructuredSlot, 0);
            require(address(validatorManager.L2_ORACLE()) == address(0), "VM-250");
            require(address(validatorManager.l2Oracle()) == address(0), "VM-260");
            require(address(validatorManager.ASSET_MANAGER()) == address(0), "VM-270");
            require(address(validatorManager.assetManager()) == address(0), "VM-280");
            require(validatorManager.TRUSTED_VALIDATOR() == address(0), "VM-290");
            require(validatorManager.trustedValidator() == address(0), "VM-300");
            require(validatorManager.COMMISSION_CHANGE_DELAY_SECONDS() == 0, "VM-310");
            require(validatorManager.commissionChangeDelaySeconds() == 0, "VM-320");
            require(validatorManager.ROUND_DURATION_SECONDS() == 0, "VM-330");
            require(validatorManager.roundDurationSeconds() == 0, "VM-340");
            require(validatorManager.SOFT_JAIL_PERIOD_SECONDS() == 0, "VM-350");
            require(validatorManager.softJailPeriodSeconds() == 0, "VM-360");
            require(validatorManager.HARD_JAIL_PERIOD_SECONDS() == 0, "VM-370");
            require(validatorManager.hardJailPeriodSeconds() == 0, "VM-380");
            require(validatorManager.JAIL_THRESHOLD() == 0, "VM-390");
            require(validatorManager.jailThreshold() == 0, "VM-400");
            require(validatorManager.MAX_OUTPUT_FINALIZATIONS() == 0, "VM-410");
            require(validatorManager.maxOutputFinalizations() == 0, "VM-420");
            require(validatorManager.BASE_REWARD() == 0, "VM-430");
            require(validatorManager.baseReward() == 0, "VM-440");
            require(validatorManager.MIN_REGISTER_AMOUNT() == 0, "VM-450");
            require(validatorManager.minRegisterAmount() == 0, "VM-460");
            require(validatorManager.MIN_ACTIVATE_AMOUNT() == 0, "VM-470");
            require(validatorManager.minActiveAmount() == 0, "VM-480");
        }
    }

    function checkZKProofVerifier(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress,
        bool _isProxy
    )
        internal
        view
    {
        console.log("[ASSERT] ZKProofVerifier (isProxy: %s)", _isProxy);
        IZKProofVerifier zkProofVerifier;
        if (_isProxy) {
            zkProofVerifier = IZKProofVerifier(mustGetAddress("ZKProofVerifierProxy"));
            require(address(zkProofVerifier.sp1Verifier()) == _cfg.zkProofVerifierSP1Verifier(), "ZKP-10");
            require(zkProofVerifier.zkVmProgramVKey() == _cfg.zkProofVerifierVKey(), "ZKP-20");
        } else {
            zkProofVerifier = IZKProofVerifier(mustGetAddress("ZKProofVerifier"));
            require(address(zkProofVerifier.sp1Verifier()) == _cfg.zkProofVerifierSP1Verifier(), "ZKP-30");
            require(zkProofVerifier.zkVmProgramVKey() == _cfg.zkProofVerifierVKey(), "ZKP-40");
        }
    }
}
