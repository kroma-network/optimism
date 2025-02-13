// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Testing
import { Vm } from "forge-std/Vm.sol";
import { console2 as console } from "forge-std/console2.sol";

// Scripts
import { DeployConfig } from "scripts/deploy/DeployConfig.s.sol";

// Libraries
import { Constants } from "src/libraries/Constants.sol";
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Types } from "scripts/libraries/Types.sol";

// Interfaces
import { IResourceMetering } from "interfaces/L1/IResourceMetering.sol";
import { ISystemConfig } from "interfaces/L1/ISystemConfig.sol";
// import { IL2OutputOracle } from "interfaces/L1/IL2OutputOracle.sol";
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { IKromaPortal } from "interfaces/L1/IKromaPortal.sol";
import { IL2OutputOracle } from "interfaces/L1/IL2OutputOracle.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";

library KromaChainAssertions {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @notice Asserts the correctness of an L1 deployment. This function expects that all contracts
    ///         within the `prox` ContractSet are proxies that have been setup and initialized.
    function postDeployAssertions(
        Types.ContractSet memory _prox,
        Types.KromaContractSet memory _kromaProx,
        DeployConfig _cfg,
        uint256 _l2OutputOracleStartingTimestamp
    )
        internal
        view
    {
        console.log("Running post-deploy assertions");
        IResourceMetering.ResourceConfig memory rcfg = ISystemConfig(_prox.SystemConfig).resourceConfig();
        IResourceMetering.ResourceConfig memory dflt = Constants.DEFAULT_RESOURCE_CONFIG();
        require(keccak256(abi.encode(rcfg)) == keccak256(abi.encode(dflt)));

        checkAssetManager({ _contracts: _kromaProx, _cfg: _cfg, _isProxy: true });
        checkColosseum({ _contracts: _kromaProx, _cfg: _cfg, _isProxy: true });
        checkKromaPortal({ _contracts: _kromaProx, contracts_: _prox, _isProxy: true });
        // TODO(sm-stack): uncomment this after resolving compile error
        // checkL2OutputOracle({
        //     _contracts: _kromaProx,
        //     _cfg: _cfg,
        //     _l2OutputOracleStartingTimestamp: _l2OutputOracleStartingTimestamp,
        //     _isProxy: true
        // });
        checkSecurityCouncil({ _contracts: _kromaProx, _isProxy: true });
        checkSecurityCouncilToken({ _contracts: _kromaProx, _isProxy: true });
        checkTimeLock({ _contracts: _kromaProx, _cfg: _cfg, _isProxy: true });
        checkUpgradeGovernor({ _contracts: _kromaProx, _cfg: _cfg, _isProxy: true });
        checkValidatorManager({ _contracts: _kromaProx, _cfg: _cfg, _isProxy: true });
        checkZKProofVerifier({ _contracts: _kromaProx, _cfg: _cfg, _isProxy: true });
    }

    /// @notice Asserts that the AssetManager is setup correctly
    function checkAssetManager(
        Types.KromaContractSet memory _contracts,
        DeployConfig _cfg,
        bool _isProxy
    )
        internal
        view
    {
        IAssetManager assetManager = IAssetManager(_contracts.AssetManager);
        console.log(
            "Running chain assertions on the AssetManager %s at %s",
            _isProxy ? "proxy" : "implementation",
            address(assetManager)
        );
        require(address(assetManager) != address(0), "CHECK-AM-10");
        // TODO(sm-stack): Add governance token and fix this
        // require(assetManager.ASSET_TOKEN() == , "CHECK-AM-20");
        require(address(assetManager.KGH()) == _cfg.assetManagerKgh(), "CHECK-AM-30");
        require(assetManager.SECURITY_COUNCIL() == _contracts.SecurityCouncil, "CHECK-AM-40");
        require(assetManager.VALIDATOR_REWARD_VAULT() == _cfg.assetManagerVault(), "CHECK-AM-50");
        require(assetManager.MIN_DELEGATION_PERIOD() == _cfg.assetManagerMinDelegationPeriod(), "CHECK-AM-60");
        require(assetManager.BOND_AMOUNT() == _cfg.assetManagerBondAmount(), "CHECK-AM-70");
    }

    /// @notice Asserts that the Colosseum is setup correctly
    function checkColosseum(Types.KromaContractSet memory _contracts, DeployConfig _cfg, bool _isProxy) internal view {
        IColosseum colosseum = IColosseum(_contracts.Colosseum);
        console.log(
            "Running chain assertions on the Colosseum implementation at %s",
            _isProxy ? "proxy" : "implementation",
            address(colosseum)
        );
        require(address(colosseum) != address(0), "CHECK-CO-10");

        // Check that the contract is initialized
        assertInitializedSlotIsSet({ _contractAddress: address(colosseum), _slot: 0, _offset: 0 });

        require(address(colosseum.L2_ORACLE()) == _contracts.L2OutputOracle, "CHECK-CO-20");
        require(address(colosseum.ZK_PROOF_VERIFIER()) == _contracts.ZKProofVerifier, "CHECK-CO-30");
        require(colosseum.L2_ORACLE_SUBMISSION_INTERVAL() == _cfg.l2OutputOracleSubmissionInterval(), "CHECK-CO-40");
        require(colosseum.CREATION_PERIOD_SECONDS() == _cfg.colosseumCreationPeriodSeconds(), "CHECK-CO-50");
        require(colosseum.BISECTION_TIMEOUT() == _cfg.colosseumBisectionTimeout(), "CHECK-CO-60");
        require(colosseum.PROVING_TIMEOUT() == _cfg.colosseumProvingTimeout(), "CHECK-CO-70");
        require(colosseum.SECURITY_COUNCIL() == _contracts.SecurityCouncil, "CHECK-CO-80");
        if (_isProxy) {
            require(colosseum.segmentsLengths(0) == _cfg.colosseumSegmentsLengths(0), "CHECK-CO-80");
            require(colosseum.segmentsLengths(1) == _cfg.colosseumSegmentsLengths(1), "CHECK-CO-90");
            require(colosseum.segmentsLengths(2) == _cfg.colosseumSegmentsLengths(2), "CHECK-CO-100");
            require(colosseum.segmentsLengths(3) == _cfg.colosseumSegmentsLengths(3), "CHECK-CO-110");
        } else {
            require(colosseum.segmentsLengths(0) == 0, "CHECK-CO-120");
            require(colosseum.segmentsLengths(1) == 0, "CHECK-CO-130");
            require(colosseum.segmentsLengths(2) == 0, "CHECK-CO-140");
            require(colosseum.segmentsLengths(3) == 0, "CHECK-CO-150");
        }
    }

    /// @notice Asserts that the KromaPortal is setup correctly
    function checkKromaPortal(
        Types.KromaContractSet memory _contracts,
        Types.ContractSet memory contracts_,
        bool _isProxy
    )
        internal
        view
    {
        IKromaPortal portal = IKromaPortal(_contracts.KromaPortal);
        console.log(
            "Running chain assertions on the KromaPortal implementation at %s",
            _isProxy ? "proxy" : "implementation",
            address(portal)
        );
        require(address(portal) != address(0), "CHECK-KP-10");

        // Check that the contract is initialized
        assertInitializedSlotIsSet({ _contractAddress: address(portal), _slot: 0, _offset: 0 });

        require(address(portal.L2_ORACLE()) == _contracts.L2OutputOracle, "CHECK-KP-20");
        require(portal.GUARDIAN() == _contracts.SecurityCouncil, "CHECK-KP-30");
        require(address(portal.SYSTEM_CONFIG()) == contracts_.SystemConfig, "CHECK-KP-40");
        require(portal.paused() == false, "CHECK-KP-50");
    }

    /// @notice Asserts that the L2OutputOracle is setup correctly
    /// TODO(sm-stack): resolve compile error by fixing IL2OutputOracle
    // function checkL2OutputOracle(
    //     Types.KromaContractSet memory _contracts,
    //     DeployConfig _cfg,
    //     uint256 _l2OutputOracleStartingTimestamp,
    //     bool _isProxy
    // )
    //     internal
    //     view
    // {
    //     IL2OutputOracle oracle = IL2OutputOracle(_contracts.L2OutputOracle);
    //     console.log(
    //         "Running chain assertions on the L2OutputOracle %s at %s",
    //         _isProxy ? "proxy" : "implementation",
    //         address(oracle)
    //     );
    //     require(address(oracle) != address(0), "CHECK-L2OO-10");

    //     // Check that the contract is initialized
    //     assertInitializedSlotIsSet({ _contractAddress: address(oracle), _slot: 0, _offset: 0 });

    //     require(address(oracle.VALIDATOR_MANAGER()) == _contracts.ValidatorManager, "CHECK-L2OO-20");
    //     require(oracle.COLOSSEUM() == _contracts.Colosseum, "CHECK-L2OO-30");
    //     require(oracle.SUBMISSION_INTERVAL() == _cfg.l2OutputOracleSubmissionInterval(), "CHECK-L2OO-40");
    //     require(oracle.L2_BLOCK_TIME() == _cfg.l2BlockTime(), "CHECK-L2OO-50");
    //     require(oracle.FINALIZATION_PERIOD_SECONDS() == _cfg.finalizationPeriodSeconds(), "CHECK-L2OO-60");
    //     if (_isProxy) {
    //         require(oracle.startingBlockNumber() == _cfg.l2OutputOracleStartingBlockNumber(), "CHECK-L2OO-70");
    //         require(oracle.startingTimestamp() == _l2OutputOracleStartingTimestamp, "CHECK-L2OO-80");
    //     } else {
    //         require(oracle.startingBlockNumber() == 0, "CHECK-L2OO-90");
    //         require(oracle.startingTimestamp() == 0, "CHECK-L2OO-100");
    //     }
    // }

    /// @notice Asserts that the SecurityCouncil is setup correctly
    function checkSecurityCouncil(Types.KromaContractSet memory _contracts, bool _isProxy) internal view {
        ISecurityCouncil council = ISecurityCouncil(_contracts.SecurityCouncil);
        console.log(
            "Running chain assertions on the SecurityCouncil %s at %s",
            _isProxy ? "proxy" : "implementation",
            address(council)
        );

        require(address(council) != address(0), "CHECK-SC-10");

        // Check that the contract is initialized
        assertInitializedSlotIsSet({ _contractAddress: address(council), _slot: 0, _offset: 0 });

        require(council.COLOSSEUM() == _contracts.Colosseum, "CHECK-SC-20");
        require(address(council.GOVERNOR()) == _contracts.UpgradeGovernor, "CHECK-SC-30");
    }

    /// @notice Asserts that the SecurityCouncilToken is setup correctly
    function checkSecurityCouncilToken(Types.KromaContractSet memory _contracts, bool _isProxy) internal view {
        ISecurityCouncilToken token = ISecurityCouncilToken(_contracts.SecurityCouncilToken);
        console.log(
            "Running chain assertions on the SecurityCouncilToken %s at %s",
            _isProxy ? "proxy" : "implementation",
            address(token)
        );

        require(address(token) != address(0), "CHECK-SCT-10");

        // Check that the contract is initialized
        assertInitializedSlotIsSet({ _contractAddress: address(token), _slot: 0, _offset: 0 });

        if (_isProxy) {
            require(token.owner() != address(0), "CHECK-SCT-20");
        } else {
            require(token.owner() == address(0), "CHECK-SCT-30");
        }
    }

    /// @notice Asserts that the TimeLock is setup correctly
    function checkTimeLock(Types.KromaContractSet memory _contracts, DeployConfig _cfg, bool _isProxy) internal view {
        ITimeLock timeLock = ITimeLock(payable(_contracts.TimeLock));
        console.log(
            "Running chain assertions on the TimeLock %s at %s",
            _isProxy ? "proxy" : "implementation",
            address(timeLock)
        );

        require(address(timeLock) != address(0), "CHECK-TL-10");

        // Check that the contract is initialized
        assertInitializedSlotIsSet({ _contractAddress: address(timeLock), _slot: 0, _offset: 0 });

        if (_isProxy) {
            require(timeLock.getMinDelay() == _cfg.timeLockMinDelaySeconds(), "CHECK-TL-20");
        } else {
            require(timeLock.getMinDelay() == 0, "CHECK-TL-30");
        }
    }

    /// @notice Asserts that the UpgradeGovernor is setup correctly
    function checkUpgradeGovernor(
        Types.KromaContractSet memory _contracts,
        DeployConfig _cfg,
        bool _isProxy
    )
        internal
        view
    {
        IUpgradeGovernor governor = IUpgradeGovernor(payable(_contracts.UpgradeGovernor));
        console.log(
            "Running chain assertions on the UpgradeGovernor %s at %s",
            _isProxy ? "proxy" : "implementation",
            address(governor)
        );

        require(address(governor) != address(0), "CHECK-UG-10");

        // Check that the contract is initialized
        assertInitializedSlotIsSet({ _contractAddress: address(governor), _slot: 0, _offset: 0 });

        if (_isProxy) {
            require(governor.token() == _contracts.SecurityCouncilToken, "CHECK-UG-20");
            require(governor.timelock() == _contracts.TimeLock, "CHECK-UG-30");
            require(governor.votingDelay() == _cfg.governorVotingDelayBlocks(), "CHECK-UG-40");
            require(governor.votingPeriod() == _cfg.governorVotingPeriodBlocks(), "CHECK-UG-50");
            require(governor.proposalThreshold() == _cfg.governorProposalThreshold(), "CHECK-UG-50");
            require(governor.quorumNumerator() == _cfg.governorVotesQuorumFractionPercent(), "CHECK-UG-60");
        } else {
            require(governor.token() == address(0), "CHECK-UG-70");
            require(governor.timelock() == address(0), "CHECK-UG-80");
            require(governor.votingDelay() == 0, "CHECK-UG-90");
            require(governor.votingPeriod() == 0, "CHECK-UG-100");
            require(governor.proposalThreshold() == 0, "CHECK-UG-110");
            require(governor.quorumNumerator() == 0, "CHECK-UG-120");
        }
    }

    /// @notice Asserts that the ValidatorManager is setup correctly
    function checkValidatorManager(
        Types.KromaContractSet memory _contracts,
        DeployConfig _cfg,
        bool _isProxy
    )
        internal
        view
    {
        IValidatorManager valMgr = IValidatorManager(_contracts.ValidatorManager);
        console.log(
            "Running chain assertions on the ValidatorManager %s at %s",
            _isProxy ? "proxy" : "implementation",
            address(valMgr)
        );

        require(address(valMgr) != address(0), "CHECK-VM-10");

        require(address(valMgr.L2_ORACLE()) == _contracts.L2OutputOracle, "CHECK-VM-20");
        require(address(valMgr.ASSET_MANAGER()) == _contracts.AssetManager, "CHECK-VM-30");
        require(valMgr.TRUSTED_VALIDATOR() == _cfg.validatorManagerTrustedValidator(), "CHECK-VM-40");
        require(valMgr.MIN_REGISTER_AMOUNT() == _cfg.validatorManagerMinRegisterAmount(), "CHECK-VM-50");
        require(valMgr.MIN_ACTIVATE_AMOUNT() == _cfg.validatorManagerMinActivateAmount(), "CHECK-VM-60");
        require(
            valMgr.COMMISSION_CHANGE_DELAY_SECONDS() == _cfg.validatorManagerCommissionChangeDelaySeconds(),
            "CHECK-VM-70"
        );
        require(valMgr.ROUND_DURATION_SECONDS() == _cfg.validatorManagerRoundDurationSeconds(), "CHECK-VM-80");
        require(valMgr.SOFT_JAIL_PERIOD_SECONDS() == _cfg.validatorManagerSoftJailPeriodSeconds(), "CHECK-VM-90");
        require(valMgr.HARD_JAIL_PERIOD_SECONDS() == _cfg.validatorManagerHardJailPeriodSeconds(), "CHECK-VM-100");
        require(valMgr.JAIL_THRESHOLD() == _cfg.validatorManagerJailThreshold(), "CHECK-VM-110");
        require(valMgr.MAX_OUTPUT_FINALIZATIONS() == _cfg.validatorManagerMaxFinalizations(), "CHECK-VM-120");
        require(valMgr.BASE_REWARD() == _cfg.validatorManagerBaseReward(), "CHECK-VM-130");
    }

    /// @notice Asserts that the ZKProofVerifier is setup correctly
    function checkZKProofVerifier(
        Types.KromaContractSet memory _contracts,
        DeployConfig _cfg,
        bool _isProxy
    )
        internal
        view
    {
        IZKProofVerifier verifier = IZKProofVerifier(_contracts.ZKProofVerifier);
        console.log(
            "Running chain assertions on the ZKProofVerifier %s at %s",
            _isProxy ? "proxy" : "implementation",
            address(verifier)
        );

        require(address(verifier) != address(0), "CHECK-ZKP-10");
        require(address(verifier.sp1Verifier()) == _cfg.zkProofVerifierSP1Verifier(), "CHECK-ZKP-20");
        require(verifier.zkVmProgramVKey() == _cfg.zkProofVerifierVKey(), "CHECK-ZKP-30");
    }

    /// @dev Asserts that for a given contract the value of a storage slot at an offset is 1 or 0xff.
    ///      A call to `initialize` will set it to 1 and a call to _disableInitializers will set it to 0xff.
    function assertInitializedSlotIsSet(address _contractAddress, uint256 _slot, uint256 _offset) internal view {
        bytes32 slotVal = vm.load(_contractAddress, bytes32(_slot));
        uint8 val = uint8((uint256(slotVal) >> (_offset * 8)) & 0xFF);
        require(
            val == uint8(1) || val == uint8(0xff),
            "ChainAssertions: storage value is not 1 or 0xff at the given slot and offset"
        );
    }
}
