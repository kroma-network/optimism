// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AssetManager } from "src/L1/AssetManager.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";

/// @title IValidatorManager
/// @notice Interface for ValidatorManager contract.
interface IValidatorManager {
    enum ValidatorStatus {
        NONE,
        EXITED,
        REGISTERED,
        READY,
        INACTIVE,
        ACTIVE
    }

    struct ConstructorParams {
        L2OutputOracle _l2Oracle;
        AssetManager _assetManager;
        address _trustedValidator;
        uint128 _commissionChangeDelaySeconds;
        uint128 _roundDurationSeconds;
        uint128 _softJailPeriodSeconds;
        uint128 _hardJailPeriodSeconds;
        uint128 _jailThreshold;
        uint128 _maxOutputFinalizations;
        uint128 _baseReward;
        uint128 _minRegisterAmount;
        uint128 _minActivateAmount;
    }

    error ImproperValidatorStatus();
    error InsufficientAsset();
    error InvalidConstructorParams();
    error MaxCommissionRateExceeded();
    error NotAllowedCaller();
    error NotElapsedCommissionChangeDelay();
    error NotElapsedJailPeriod();
    error NotInitiatedCommissionChange();
    error NotSelectedPriorityValidator();
    error SameCommissionRate();

    event ChallengeRewardDistributed(uint256 indexed outputIndex, address indexed recipient, uint128 amount);
    event RewardDistributed(
        uint256 indexed outputIndex,
        address indexed validator,
        uint128 validatorReward,
        uint128 baseReward,
        uint128 boostedReward
    );
    event SlashReverted(uint256 indexed outputIndex, address indexed loser, uint128 amount);
    event Slashed(uint256 indexed outputIndex, address indexed loser, uint128 amount);
    event ValidatorActivated(address indexed validator, uint256 activatedAt);
    event ValidatorCommissionChangeFinalized(
        address indexed validator, uint8 oldCommissionRate, uint8 newCommissionRate
    );
    event ValidatorCommissionChangeInitiated(
        address indexed validator, uint8 oldCommissionRate, uint8 newCommissionRate
    );
    event ValidatorJailed(address indexed validator, uint128 expiresAt);
    event ValidatorRegistered(address indexed validator, bool activated, uint8 commissionRate, uint128 assets);
    event ValidatorStopped(address indexed validator, uint256 stopsAt);
    event ValidatorUnjailed(address indexed validator);

    function ASSET_MANAGER() external view returns (AssetManager);
    function BASE_REWARD() external view returns (uint128);
    function BOOSTED_REWARD_DENOM() external view returns (uint128);
    function BOOSTED_REWARD_NUMERATOR() external view returns (uint128);
    function COMMISSION_CHANGE_DELAY_SECONDS() external view returns (uint128);
    function COMMISSION_RATE_DENOM() external view returns (uint128);
    function HARD_JAIL_PERIOD_SECONDS() external view returns (uint128);
    function JAIL_THRESHOLD() external view returns (uint128);
    function L2_ORACLE() external view returns (L2OutputOracle);
    function MAX_OUTPUT_FINALIZATIONS() external view returns (uint128);
    function MIN_ACTIVATE_AMOUNT() external view returns (uint128);
    function MIN_REGISTER_AMOUNT() external view returns (uint128);
    function ROUND_DURATION_SECONDS() external view returns (uint128);
    function SOFT_JAIL_PERIOD_SECONDS() external view returns (uint128);
    function TRUSTED_VALIDATOR() external view returns (address);
    function activateValidator() external;
    function activatedValidatorCount() external view returns (uint32);
    function activatedValidatorTotalWeight() external view returns (uint120);
    function afterSubmitL2Output(uint256 outputIndex) external;
    function bondValidatorKro(address validator) external;
    function canFinalizeCommissionChangeAt(address validator) external view returns (uint128);
    function checkSubmissionEligibility(address validator) external view;
    function finalizeCommissionChange() external;
    function getCommissionRate(address validator) external view returns (uint8);
    function getPendingCommissionRate(address validator) external view returns (uint8);
    function getStatus(address validator) external view returns (ValidatorStatus);
    function getWeight(address validator) external view returns (uint120);
    function inJail(address validator) external view returns (bool);
    function initCommissionChange(uint8 newCommissionRate) external;
    function isActive(address validator) external view returns (bool);
    function jailExpiresAt(address validator) external view returns (uint128);
    function nextValidator() external view returns (address);
    function noSubmissionCount(address validator) external view returns (uint8);
    function registerValidator(uint128 assets, uint8 commissionRate, address withdrawAccount) external;
    function revertSlash(uint256 outputIndex, address loser) external;
    function slash(uint256 outputIndex, address winner, address loser) external;
    function tryActivateValidator(address validator) external;
    function tryUnjail() external;
    function unbondValidatorKro(address validator) external;
    function updateValidatorTree(address validator, bool tryRemove) external;
    function version() external view returns (string memory);

    function __constructor__(ConstructorParams calldata _constructorParams) external;
}
