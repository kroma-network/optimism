// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import { KromaDeployInput, KromaDeployOutput } from "scripts/deploy/kroma/KromaDeployTypes.sol";

// Interfaces
import { IAssetManager } from "interfaces/L1/IAssetManager.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { ISecurityCouncilToken } from "interfaces/governance/ISecurityCouncilToken.sol";
import { ITimeLock } from "interfaces/governance/ITimeLock.sol";
import { IUpgradeGovernor } from "interfaces/governance/IUpgradeGovernor.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";
import { IKromaGovernanceToken } from "interfaces/governance/IKromaGovernanceToken.sol";

// Contracts
import { SecurityCouncil } from "src/L1/SecurityCouncil.sol";

/// @title KromaInitializers
/// @notice Provides helper methods for encoding initializer calldata for Kroma-specific contracts.
/// @dev Used by KromaDeployer during the upgradeAndCall process for each proxy contract.
library KromaInitializers {
    /// @notice Encodes initializer data for the AssetManager contract.
    function encodeAssetManagerInitializer(
        KromaDeployInput memory input,
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IAssetManager.initialize.selector,
            mustGetAddress("KromaGovernanceTokenProxy"),
            input.kgh,
            mustGetAddress("SecurityCouncilProxy"),
            input.vault,
            mustGetAddress("ValidatorManagerProxy"),
            input.minDelegationPeriod,
            input.bondAmount
        );
    }

    /// @notice Encodes initializer data for the Colosseum contract.
    function encodeColosseumInitializer(
        KromaDeployInput memory input,
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IColosseum.initialize.selector,
            input.l2OutputOracle,
            mustGetAddress("ZKProofVerifierProxy"),
            mustGetAddress("SecurityCouncilProxy"),
            input.submissionInterval,
            input.guardianPeriodSeconds,
            input.maxClockDurationSeconds,
            input.challengeGracePeriodSeconds
        );
    }

    /// @notice Encodes initializer data for the SecurityCouncil contract.
    function encodeSecurityCouncilInitializer(function(string memory) view returns (address payable) mustGetAddress)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            SecurityCouncil.initialize.selector,
            mustGetAddress("ColosseumProxy"),
            mustGetAddress("UpgradeGovernorProxy")
        );
    }

    /// @notice Encodes initializer data for the SecurityCouncilToken contract.
    function encodeSecurityCouncilTokenInitializer(
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(ISecurityCouncilToken.initialize.selector, mustGetAddress("UpgradeGovernorProxy"));
    }

    /// @notice Encodes initializer data for the TimeLock contract.
    function encodeTimeLockInitializer(
        KromaDeployInput memory input,
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        address upgradeGovernorProxy = mustGetAddress("UpgradeGovernorProxy");
        proposers[0] = upgradeGovernorProxy;
        executors[0] = upgradeGovernorProxy;

        return abi.encodeWithSelector(
            ITimeLock.initialize.selector, input.timeLockMinDelaySeconds, proposers, executors, upgradeGovernorProxy
        );
    }

    /// @notice Encodes initializer data for the UpgradeGovernor contract.
    function encodeUpgradeGovernorInitializer(
        KromaDeployInput memory input,
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IUpgradeGovernor.initialize.selector,
            mustGetAddress("SecurityCouncilTokenProxy"),
            mustGetAddress("TimeLockProxy"),
            input.initialVotingDelay,
            input.initialVotingPeriod,
            input.initialProposalThreshold,
            input.votesQuorumFraction
        );
    }

    /// @notice Encodes initializer data for the ValidatorManager contract.
    function encodeValidatorManagerInitializer(
        KromaDeployInput memory input,
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        IValidatorManager.InitializationParams memory params = IValidatorManager.InitializationParams({
            _l2Oracle: input.l2OutputOracle,
            _assetManager: IAssetManager(mustGetAddress("AssetManagerProxy")),
            _trustedValidator: input.trustedValidator,
            _commissionChangeDelaySeconds: input.commissionChangeDelaySeconds,
            _roundDurationSeconds: input.roundDurationSeconds,
            _softJailPeriodSeconds: input.softJailPeriodSeconds,
            _hardJailPeriodSeconds: input.hardJailPeriodSeconds,
            _jailThreshold: input.jailThreshold,
            _maxOutputFinalizations: input.maxFinalizations,
            _baseReward: input.baseReward,
            _minRegisterAmount: input.minRegisterAmount,
            _minActivateAmount: input.minActivateAmount
        });

        return abi.encodeWithSelector(IValidatorManager.initialize.selector, params);
    }
}
