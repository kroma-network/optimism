// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Scripts
import { DeployConfig } from "scripts/deploy/DeployConfig.s.sol";

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
import { IKromaGovernanceToken } from "interfaces/governance/IKromaGovernanceToken.sol";

// Contracts
import { SecurityCouncil } from "src/L1/SecurityCouncil.sol";

/// @title KromaInitializers
/// @notice Provides helper methods for encoding initializer calldata for Kroma-specific contracts.
/// @dev Used by KromaDeployer during the upgradeAndCall process for each proxy contract.
library KromaInitializers {
    /// @notice Encodes initializer data for the AssetManager contract.
    function encodeAssetManagerInitializer(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IAssetManager.initialize.selector,
            mustGetAddress("AssetToken"),
            mustGetAddress("KGH"),
            mustGetAddress("SecurityCouncilProxy"),
            _cfg.assetManagerVault(),
            mustGetAddress("ValidatorManagerProxy"),
            _cfg.assetManagerMinDelegationPeriod(),
            _cfg.assetManagerBondAmount()
        );
    }

    /// @notice Encodes initializer data for the Colosseum contract.
    function encodeColosseumInitializer(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IColosseum.initialize.selector,
            mustGetAddress("KromaL2OutputOracleProxy"),
            mustGetAddress("ZKProofVerifierProxy"),
            mustGetAddress("SecurityCouncilProxy"),
            _cfg.l2OutputOracleSubmissionInterval(),
            _cfg.colosseumCreationPeriodSeconds(),
            _cfg.colosseumBisectionTimeout(),
            _cfg.colosseumProvingTimeout(),
            _cfg.getColosseumSegmentsLengths()
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
        DeployConfig _cfg,
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
            ITimeLock.initialize.selector, _cfg.timeLockMinDelaySeconds(), proposers, executors, upgradeGovernorProxy
        );
    }

    /// @notice Encodes initializer data for the UpgradeGovernor contract.
    function encodeUpgradeGovernorInitializer(
        DeployConfig _cfg,
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
            _cfg.governorVotingDelayBlocks(),
            _cfg.governorVotingPeriodBlocks(),
            _cfg.governorProposalThreshold(),
            _cfg.governorVotesQuorumFractionPercent()
        );
    }

    /// @notice Encodes initializer data for the ValidatorManager contract.
    function encodeValidatorManagerInitializer(
        DeployConfig _cfg,
        function(string memory) view returns (address payable) mustGetAddress
    )
        internal
        view
        returns (bytes memory)
    {
        IValidatorManager.InitializationParams memory params = IValidatorManager.InitializationParams({
            _l2Oracle: IKromaL2OutputOracle(mustGetAddress("KromaL2OutputOracleProxy")),
            _assetManager: IAssetManager(mustGetAddress("AssetManagerProxy")),
            _trustedValidator: _cfg.validatorManagerTrustedValidator(),
            _commissionChangeDelaySeconds: _cfg.validatorManagerCommissionChangeDelaySeconds(),
            _roundDurationSeconds: _cfg.validatorManagerRoundDurationSeconds(),
            _softJailPeriodSeconds: _cfg.validatorManagerSoftJailPeriodSeconds(),
            _hardJailPeriodSeconds: _cfg.validatorManagerHardJailPeriodSeconds(),
            _jailThreshold: _cfg.validatorManagerJailThreshold(),
            _maxOutputFinalizations: _cfg.validatorManagerMaxFinalizations(),
            _baseReward: _cfg.validatorManagerBaseReward(),
            _minRegisterAmount: _cfg.validatorManagerMinRegisterAmount(),
            _minActivateAmount: _cfg.validatorManagerMinActivateAmount()
        });

        return abi.encodeWithSelector(IValidatorManager.initialize.selector, params);
    }
}
