// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Contracts
import { AssetManager } from "src/L1/AssetManager.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";

// Libraries
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Atan2 } from "src/libraries/Atan2.sol";
import { BalancedWeightTree } from "src/libraries/BalancedWeightTree.sol";
import { KromaConstants } from "src/libraries/KromaConstants.sol";
import { KromaTypes } from "src/libraries/KromaTypes.sol";
import { Uint128Math } from "src/libraries/Uint128Math.sol";

// Interfaces
import { ISemver } from "interfaces/universal/ISemver.sol";

/// @custom:proxied
/// @title ValidatorManager
/// @notice The ValidatorManager manages validator set and determines the next validator who can
///         submit the checkpoint output to L2OutputOracle.
contract ValidatorManager is ISemver {
    using BalancedWeightTree for BalancedWeightTree.Tree;
    using Uint128Math for uint128;
    using Math for uint256;

    /// @notice Enum of the status of a validator.
    ///
    /// Below is the possible conditions of each status. "initiated" means the validator has been
    /// initiated at least once, "activated" means the validator has been activated and added to the
    /// validator tree. "MIN_REGISTER_AMOUNT" means the total assets of the validator exceeds
    /// MIN_REGISTER_AMOUNT, "MIN_ACTIVATE_AMOUNT" means the same.
    ///
    /// +------------+-----------+-----------+---------------------+---------------------+
    /// | Status     | initiated | activated | MIN_REGISTER_AMOUNT | MIN_ACTIVATE_AMOUNT |
    /// +------------+-----------+-----------+---------------------+---------------------+
    /// | NONE       | X         | X         | X                   | X                   |
    /// | EXITED     | O         | O/X       | X                   | O/X                 |
    /// | REGISTERED | O         | X         | O                   | X                   |
    /// | READY      | O         | X         | O                   | O                   |
    /// | INACTIVE   | O         | O         | O                   | X                   |
    /// | ACTIVE     | O         | O         | O                   | O                   |
    /// +------------+-----------+-----------+---------------------+---------------------+
    enum ValidatorStatus {
        NONE,
        EXITED,
        REGISTERED,
        READY,
        INACTIVE,
        ACTIVE
    }

    /// @notice Constructs the constructor parameters of ValidatorManager contract.
    /// @custom:field _l2Oracle                     Address of the L2OutputOracle contract.
    /// @custom:field _assetManager                 Address of the AssetManager contract.
    /// @custom:field _trustedValidator             Address of the trusted validator.
    /// @custom:field _commissionChangeDelaySeconds The delay to finalize the commission rate change
    ///                                             in seconds.
    /// @custom:field _roundDurationSeconds         The duration of one submission round in seconds.
    /// @custom:field _softJailPeriodSeconds        The minimum duration to get out of jail in
    ///                                             seconds in output non-submissions penalty.
    /// @custom:field _hardJailPeriodSeconds        The minimum duration to get out of jail in
    ///                                             seconds in slashing penalty.
    /// @custom:field _jailThreshold                The maximum allowed number of output
    ///                                             non-submissions before jailed.
    /// @custom:field _maxOutputFinalizations       Max number of finalized outputs.
    /// @custom:field _baseReward                   Base reward for the validator.
    /// @custom:field _minRegisterAmount            Minimum amount to register as a validator.
    /// @custom:field _minActivateAmount            Minimum amount to activate a validator.
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

    /// @notice Constructs the information of a validator.
    /// @custom:field isInitiated                 Whether the validator is initiated.
    /// @custom:field noSubmissionCount           Number of counts that the validator did not submit
    ///                                           the output in priority round.
    /// @custom:field commissionRate              Commission rate of validator.
    /// @custom:field pendingCommissionRate       Pending commission rate of validator.
    /// @custom:field commissionChangeInitiatedAt Timestamp of commission change initialization.
    struct Validator {
        bool isInitiated;
        uint8 noSubmissionCount;
        uint8 commissionRate;
        uint8 pendingCommissionRate;
        uint128 commissionChangeInitiatedAt;
    }

    /// @notice The denominator for the commission rate.
    uint128 public constant COMMISSION_RATE_DENOM = 100;

    /// @notice The numerator for the boosted reward.
    uint128 public constant BOOSTED_REWARD_NUMERATOR = 40;

    /// @notice The denominator for the boosted reward.
    uint128 public constant BOOSTED_REWARD_DENOM = 100;

    /// @notice Address of the L2OutputOracle contract. Can be updated via upgrade.
    L2OutputOracle public immutable L2_ORACLE;

    /// @notice The address of AssetManager contract. Can be updated via upgrade.
    AssetManager public immutable ASSET_MANAGER;

    /// @notice The address of the trusted validator.
    address public immutable TRUSTED_VALIDATOR;

    /// @notice Minimum amount to register as a validator. It should be equal or more than
    ///         ASSET_MANAGER.BOND_AMOUNT.
    uint128 public immutable MIN_REGISTER_AMOUNT;

    /// @notice Minimum amount to activate a validator and add it to the validator tree.
    ///         Note that only the active validators can submit outputs.
    uint128 public immutable MIN_ACTIVATE_AMOUNT;

    /// @notice The delay to finalize the commission rate change of the validator (in seconds).
    uint128 public immutable COMMISSION_CHANGE_DELAY_SECONDS;

    /// @notice The duration of a submission round for one output (in seconds).
    ///         Note that there are two submission rounds for an output: PRIORITY ROUND and PUBLIC
    ///         ROUND.
    uint128 public immutable ROUND_DURATION_SECONDS;

    /// @notice The minimum duration to get out of jail in output non-submissions penalty (in seconds).
    uint128 public immutable SOFT_JAIL_PERIOD_SECONDS;

    /// @notice The maximum duration to get out of jail in slashing penalty (in seconds).
    uint128 public immutable HARD_JAIL_PERIOD_SECONDS;

    /// @notice Maximum allowed number of output non-submissions in priority round before the
    ///         validator goes to jail.
    uint128 public immutable JAIL_THRESHOLD;

    /// @notice The max number of outputs to be finalized at once when distributing rewards.
    uint128 public immutable MAX_OUTPUT_FINALIZATIONS;

    /// @notice Amount of base reward for the validator.
    uint128 public immutable BASE_REWARD;

    /// @notice Address of the next validator with priority for submitting output.
    address internal _nextPriorityValidator;

    /// @notice Weighted tree to store and calculate the probability to be selected as an output submitter.
    BalancedWeightTree.Tree internal _validatorTree;

    /// @notice A mapping of the validator to the validator information.
    mapping(address => Validator) internal _validatorInfo;

    /// @notice A mapping of the jailed validator to the jail expiration timestamp.
    mapping(address => uint128) internal _jail;

    /// @notice A mapping of output index challenged successfully to pending challenge rewards.
    mapping(uint256 => uint128) internal _pendingChallengeReward;

    /// @notice Emitted when registers as a validator.
    /// @param validator      Address of the validator.
    /// @param activated      If the validator is activated or not.
    /// @param commissionRate The commission rate the validator sets.
    /// @param assets         The number of assets the validator deposits.
    event ValidatorRegistered(address indexed validator, bool activated, uint8 commissionRate, uint128 assets);

    /// @notice Emitted when a validator activated, which means added to the validator tree.
    /// @param validator   Address of the validator.
    /// @param activatedAt The timestamp when the validator activated.
    event ValidatorActivated(address indexed validator, uint256 activatedAt);

    /// @notice Emitted when a validator stops, which means removed from the validator tree.
    /// @param validator Address of the validator.
    /// @param stopsAt   The timestamp when the validator stops.
    event ValidatorStopped(address indexed validator, uint256 stopsAt);

    /// @notice Emitted when a validator initiated commission rate change.
    /// @param validator         Address of the validator.
    /// @param oldCommissionRate The old commission rate.
    /// @param newCommissionRate The new commission rate.
    event ValidatorCommissionChangeInitiated(
        address indexed validator, uint8 oldCommissionRate, uint8 newCommissionRate
    );

    /// @notice Emitted when a validator finalized commission rate change.
    /// @param validator         Address of the validator.
    /// @param oldCommissionRate The old commission rate.
    /// @param newCommissionRate The new commission rate.
    event ValidatorCommissionChangeFinalized(
        address indexed validator, uint8 oldCommissionRate, uint8 newCommissionRate
    );

    /// @notice Emitted when a validator is jailed.
    /// @param validator Address of the validator.
    /// @param expiresAt The expiration timestamp of the jail.
    event ValidatorJailed(address indexed validator, uint128 expiresAt);

    /// @notice Emitted when a validator is unjailed.
    /// @param validator Address of the validator.
    event ValidatorUnjailed(address indexed validator);

    /// @notice Emitted when the output reward is distributed.
    /// @param outputIndex     Index of the L2 checkpoint output.
    /// @param validator       Address of the validator whose vault is rewarded.
    /// @param validatorReward The amount of validator reward.
    /// @param baseReward      The amount of base reward for KRO delegators.
    /// @param boostedReward   The amount of boosted reward for KGH delegators.
    event RewardDistributed(
        uint256 indexed outputIndex,
        address indexed validator,
        uint128 validatorReward,
        uint128 baseReward,
        uint128 boostedReward
    );

    /// @notice Emitted when challenge reward for challenge winner is distributed.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param recipient   Address of the reward recipient.
    /// @param amount      The amount of challenge reward.
    event ChallengeRewardDistributed(uint256 indexed outputIndex, address indexed recipient, uint128 amount);

    /// @notice Emitted when the validator is slashed.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param loser       Address of the challenge loser.
    /// @param amount      The amount of KRO slashed.
    event Slashed(uint256 indexed outputIndex, address indexed loser, uint128 amount);

    /// @notice Emitted when the slash is reverted.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param loser       Address of the challenge original loser.
    /// @param amount      The amount of KRO refunded to the loser.
    event SlashReverted(uint256 indexed outputIndex, address indexed loser, uint128 amount);

    /// @notice Reverts when caller is not allowed.
    error NotAllowedCaller();

    /// @notice Reverts when constructor parameters are invalid.
    error InvalidConstructorParams();

    /// @notice Reverts when the status of validator is improper.
    error ImproperValidatorStatus();

    /// @notice Reverts when the asset is insufficient.
    error InsufficientAsset();

    /// @notice Reverts when the commission rate exceeds the max value.
    error MaxCommissionRateExceeded();

    /// @notice Reverts when try to change commission rate with same value as previous.
    error SameCommissionRate();

    /// @notice Reverts when the commission rate change has not been initiated.
    error NotInitiatedCommissionChange();

    /// @notice Reverts when the delay of commission rate change finalization has not elapsed.
    error NotElapsedCommissionChangeDelay();

    /// @notice Reverts when try to unjail before jail period elapsed.
    error NotElapsedJailPeriod();

    /// @notice Reverts if the validator is not selected priority validator.
    error NotSelectedPriorityValidator();

    /// @notice A modifier that only allows L2OutputOracle contract to call.
    modifier onlyL2OutputOracle() {
        if (msg.sender != address(L2_ORACLE)) revert NotAllowedCaller();
        _;
    }

    /// @notice A modifier that only allows Colosseum contract to call.
    modifier onlyColosseum() {
        if (msg.sender != L2_ORACLE.COLOSSEUM()) revert NotAllowedCaller();
        _;
    }

    /// @notice A modifier that only allows AssetManager contract to call.
    modifier onlyAssetManager() {
        if (msg.sender != address(ASSET_MANAGER)) revert NotAllowedCaller();
        _;
    }

    /// @notice Semantic version.
    /// @custom:semver 1.1.0
    string public constant version = "1.1.0";

    /// @notice Constructs the ValidatorManager contract.
    /// @param _constructorParams The constructor parameters.
    constructor(ConstructorParams memory _constructorParams) {
        if (_constructorParams._minRegisterAmount > _constructorParams._minActivateAmount) {
            revert InvalidConstructorParams();
        }

        L2_ORACLE = _constructorParams._l2Oracle;
        ASSET_MANAGER = _constructorParams._assetManager;
        TRUSTED_VALIDATOR = _constructorParams._trustedValidator;
        MIN_REGISTER_AMOUNT = _constructorParams._minRegisterAmount;
        MIN_ACTIVATE_AMOUNT = _constructorParams._minActivateAmount;
        COMMISSION_CHANGE_DELAY_SECONDS = _constructorParams._commissionChangeDelaySeconds;
        // Note that this value MUST be (SUBMISSION_INTERVAL * L2_BLOCK_TIME) / 2.
        ROUND_DURATION_SECONDS = _constructorParams._roundDurationSeconds;
        SOFT_JAIL_PERIOD_SECONDS = _constructorParams._softJailPeriodSeconds;
        HARD_JAIL_PERIOD_SECONDS = _constructorParams._hardJailPeriodSeconds;
        JAIL_THRESHOLD = _constructorParams._jailThreshold;
        MAX_OUTPUT_FINALIZATIONS = _constructorParams._maxOutputFinalizations;
        BASE_REWARD = _constructorParams._baseReward;
    }

    /// @notice Registers as a validator with assets at least MIN_REGISTER_AMOUNT. The validator with
    ///         assets more than MIN_ACTIVATE_AMOUNT can be activated at the same time.
    /// @param assets          The amount of assets to deposit.
    /// @param commissionRate  The commission rate the validator sets.
    /// @param withdrawAccount An account where assets can be withdrawn to. Only this account can
    ///                        withdraw the assets.
    function registerValidator(uint128 assets, uint8 commissionRate, address withdrawAccount) external {
        if (msg.sender.code.length > 0 || msg.sender != tx.origin) revert NotAllowedCaller();
        if (getStatus(msg.sender) != ValidatorStatus.NONE) revert ImproperValidatorStatus();
        if (assets < MIN_REGISTER_AMOUNT) revert InsufficientAsset();
        if (commissionRate > COMMISSION_RATE_DENOM) revert MaxCommissionRateExceeded();

        Validator storage validatorInfo = _validatorInfo[msg.sender];
        validatorInfo.isInitiated = true;
        validatorInfo.commissionRate = commissionRate;

        ASSET_MANAGER.depositToRegister(msg.sender, assets, withdrawAccount);

        bool ready = assets >= MIN_ACTIVATE_AMOUNT;
        if (ready) {
            _activateValidator(msg.sender);
        }

        emit ValidatorRegistered(msg.sender, ready, commissionRate, assets);
    }

    /// @notice Activates a validator and adds the validator to validator tree. To submit outputs,
    ///         the validator should be activated.
    function activateValidator() external {
        if (getStatus(msg.sender) != ValidatorStatus.READY || inJail(msg.sender)) {
            revert ImproperValidatorStatus();
        }

        _activateValidator(msg.sender);
    }

    /// @notice Tries to activate a validator and adds the validator to validator tree. To submit
    ///         outputs, the validator should be activated. This function can only be called by
    ///         AssetManager.
    /// @param validator Address of the validator.
    function tryActivateValidator(address validator) external onlyAssetManager {
        if (getStatus(validator) == ValidatorStatus.READY && !inJail(validator)) {
            _activateValidator(validator);
        }
    }

    /// @notice Handles some essential actions such as reward distribution, jail handling, next
    ///         priority validator selection after output submission. This function can only be
    ///         called by L2OutputOracle.
    /// @param outputIndex Index of the L2 checkpoint output submitted.
    function afterSubmitL2Output(uint256 outputIndex) external onlyL2OutputOracle {
        _distributeReward();

        // Bond validator KRO to reserve slashing amount.
        address submitter = L2_ORACLE.getSubmitter(outputIndex);
        ASSET_MANAGER.bondValidatorKro(submitter);

        if (submitter == _nextPriorityValidator) {
            _resetNoSubmissionCount(submitter);
        } else {
            _tryJail();
        }

        // Select the next priority validator.
        _updatePriorityValidator();
    }

    /// @notice Initiates the commission rate change of a validator. An exited or jailed validator
    ///         cannot initiate it.
    /// @param newCommissionRate The new commission rate to apply.
    function initCommissionChange(uint8 newCommissionRate) external {
        if (getStatus(msg.sender) < ValidatorStatus.REGISTERED || inJail(msg.sender)) {
            revert ImproperValidatorStatus();
        }

        if (newCommissionRate > COMMISSION_RATE_DENOM) revert MaxCommissionRateExceeded();

        Validator storage validatorInfo = _validatorInfo[msg.sender];
        uint8 oldCommissionRate = validatorInfo.commissionRate;
        if (newCommissionRate == oldCommissionRate) revert SameCommissionRate();

        validatorInfo.pendingCommissionRate = newCommissionRate;
        validatorInfo.commissionChangeInitiatedAt = uint128(block.timestamp);

        emit ValidatorCommissionChangeInitiated(msg.sender, oldCommissionRate, newCommissionRate);
    }

    /// @notice Finalizes the commission rate change of a validator. An exited or jailed validator
    ///         cannot finalize it, and a validator can finalize it after
    ///         COMMISION_CHANGE_DELAY_SECONDS elapsed since the initialization of commission change.
    function finalizeCommissionChange() external {
        if (getStatus(msg.sender) < ValidatorStatus.REGISTERED || inJail(msg.sender)) {
            revert ImproperValidatorStatus();
        }

        uint128 canFinalizeAt = canFinalizeCommissionChangeAt(msg.sender);
        if (canFinalizeAt == COMMISSION_CHANGE_DELAY_SECONDS) revert NotInitiatedCommissionChange();
        if (block.timestamp < canFinalizeAt) revert NotElapsedCommissionChangeDelay();

        Validator storage validatorInfo = _validatorInfo[msg.sender];
        uint8 oldCommissionRate = validatorInfo.commissionRate;
        uint8 newCommissionRate = validatorInfo.pendingCommissionRate;

        validatorInfo.commissionRate = newCommissionRate;
        validatorInfo.pendingCommissionRate = 0;
        validatorInfo.commissionChangeInitiatedAt = 0;

        emit ValidatorCommissionChangeFinalized(msg.sender, oldCommissionRate, newCommissionRate);
    }

    /// @notice Attempts to unjail a validator. Only the validator who wants to unjail can call
    ///         itself.
    function tryUnjail() external {
        if (!inJail(msg.sender)) revert ImproperValidatorStatus();
        if (_jail[msg.sender] > block.timestamp) revert NotElapsedJailPeriod();

        _resetNoSubmissionCount(msg.sender);
        delete _jail[msg.sender];

        emit ValidatorUnjailed(msg.sender);

        if (getStatus(msg.sender) == ValidatorStatus.READY) {
            _activateValidator(msg.sender);
        }
    }

    /// @notice Call ASSET_MANAGER.bondValidatorKro(). This function is only called by the Colosseum
    ///         contract.
    /// @param validator Address of the validator.
    function bondValidatorKro(address validator) external onlyColosseum {
        ASSET_MANAGER.bondValidatorKro(validator);
    }

    /// @notice Call ASSET_MANAGER.unbondValidatorKro(). This function is only called by the
    ///         Colosseum contract.
    /// @param validator Address of the validator.
    function unbondValidatorKro(address validator) external onlyColosseum {
        ASSET_MANAGER.unbondValidatorKro(validator);
    }

    /// @notice Slash KRO from the vault of the challenge loser and move the slashing asset to
    ///         pending challenge reward before output rewarded, after directly to winner's asset.
    ///         Since the behavior could threaten the security of the chain, the loser is sent to
    ///         jail for HARD_JAIL_PERIOD_SECONDS. This function is only called by the Colosseum
    ///         contract.
    /// @param outputIndex The index of output challenged.
    /// @param winner      Address of the challenge winner.
    /// @param loser       Address of the challenge loser.
    function slash(uint256 outputIndex, address winner, address loser) external onlyColosseum {
        uint128 challengeReward = ASSET_MANAGER.decreaseBalanceWithChallenge(loser);

        emit Slashed(outputIndex, loser, challengeReward);

        _sendToJail(loser, false);

        if (L2_ORACLE.nextFinalizeOutputIndex() <= outputIndex) {
            // If output is not rewarded yet, add slashing asset to the pending challenge reward.
            unchecked {
                _pendingChallengeReward[outputIndex] += challengeReward;
            }
        } else {
            // If output is already rewarded, add slashing asset to the winner's asset directly.
            challengeReward = ASSET_MANAGER.increaseBalanceWithChallenge(winner, challengeReward);
            updateValidatorTree(winner, false);

            emit ChallengeRewardDistributed(outputIndex, winner, challengeReward);
        }
    }

    /// @notice Revert slash. This function is only called by the Colosseum contract.
    /// @param outputIndex The index of output challenged.
    /// @param loser       Address of the challenge loser.
    function revertSlash(uint256 outputIndex, address loser) external onlyColosseum {
        uint128 challengeReward = ASSET_MANAGER.revertDecreaseBalanceWithChallenge(loser);
        unchecked {
            _pendingChallengeReward[outputIndex] -= challengeReward;
        }

        emit SlashReverted(outputIndex, loser, challengeReward);

        if (inJail(loser)) {
            // Revert jail expiration timestamp of the original loser.
            uint128 expiresAt = _jail[loser] - HARD_JAIL_PERIOD_SECONDS;
            if (block.timestamp < expiresAt) {
                _jail[loser] = expiresAt;

                emit ValidatorJailed(loser, expiresAt);
            } else {
                delete _jail[loser];

                emit ValidatorUnjailed(loser);

                if (getStatus(loser) == ValidatorStatus.READY) {
                    _activateValidator(loser);
                }
            }
        }
    }

    /// @notice Checks the eligibility to submit L2 checkpoint output during output submission.
    ///         Note that only the validator whose status is ACTIVE can submit output. This function
    ///         can only be called by L2OutputOracle during output submission.
    /// @param validator Address of the output submitter.
    function checkSubmissionEligibility(address validator) external view onlyL2OutputOracle {
        address _nextValidator = nextValidator();
        if (_nextValidator != KromaConstants.VALIDATOR_PUBLIC_ROUND_ADDRESS && validator != _nextValidator) {
            revert NotSelectedPriorityValidator();
        }

        if (!isActive(validator)) revert ImproperValidatorStatus();
    }

    /// @notice Returns the commission rate of given validator.
    /// @param validator Address of the validator.
    /// @return The commission rate of given validator.
    function getCommissionRate(address validator) external view returns (uint8) {
        return _validatorInfo[validator].commissionRate;
    }

    /// @notice Returns the pending commission rate of given validator.
    /// @param validator Address of the validator.
    /// @return The pending commission rate of given validator.
    function getPendingCommissionRate(address validator) external view returns (uint8) {
        return _validatorInfo[validator].pendingCommissionRate;
    }

    /// @notice Returns the number of activated validators.
    /// @return The number of activated validators.
    function activatedValidatorCount() external view returns (uint32) {
        return _validatorTree.counter - _validatorTree.removed;
    }

    /// @notice Returns the weight of given validator. It not activated, returns 0.
    ///         Note that `weight / activatedValidatorTotalWeight()` is the probability that the
    ///         validator is selected as a priority validator.
    /// @param validator Address of the validator.
    /// @return The weight of given validator.
    function getWeight(address validator) external view returns (uint120) {
        return _validatorTree.nodes[_validatorTree.nodeMap[validator]].weight;
    }

    /// @notice Returns the jail expiration timestamp of given validator.
    /// @param validator Address of the jailed validator.
    /// @return The jail expiration timestamp of given validator.
    function jailExpiresAt(address validator) external view returns (uint128) {
        return _jail[validator];
    }

    /// @notice Updates the validator tree.
    /// @param validator Address of the validator.
    /// @param tryRemove Flag to try remove the validator from validator tree.
    function updateValidatorTree(address validator, bool tryRemove) public {
        ValidatorStatus status = getStatus(validator);
        if (tryRemove && (status == ValidatorStatus.EXITED || status == ValidatorStatus.INACTIVE)) {
            if (_validatorTree.remove(validator)) emit ValidatorStopped(validator, block.timestamp);
        } else if (status >= ValidatorStatus.INACTIVE) {
            _validatorTree.update(validator, uint120(ASSET_MANAGER.reflectiveWeight(validator)));
        }
    }

    /// @notice Determines who can submit the L2 checkpoint output for the current round.
    /// @return Address of the validator who can submit the L2 checkpoint output for the current
    ///         round.
    function nextValidator() public view returns (address) {
        if (_nextPriorityValidator != address(0)) {
            uint256 l2Timestamp = L2_ORACLE.nextOutputMinL2Timestamp();
            if (block.timestamp >= l2Timestamp) {
                uint256 elapsed = block.timestamp - l2Timestamp;
                // If the current time exceeds one round time, it is a public round.
                if (elapsed > ROUND_DURATION_SECONDS) {
                    return KromaConstants.VALIDATOR_PUBLIC_ROUND_ADDRESS;
                }
            }

            return _nextPriorityValidator;
        } else {
            return TRUSTED_VALIDATOR;
        }
    }

    /// @notice Returns the status of the validator corresponding to the given address.
    /// @param validator Address of the validator.
    /// @return The status of the validator corresponding to the given address.
    function getStatus(address validator) public view returns (ValidatorStatus) {
        if (!_validatorInfo[validator].isInitiated) {
            return ValidatorStatus.NONE;
        }

        if (ASSET_MANAGER.totalValidatorKro(validator) < MIN_REGISTER_AMOUNT) {
            return ValidatorStatus.EXITED;
        }

        bool activated = _validatorTree.nodeMap[validator] > 0;

        if (ASSET_MANAGER.reflectiveWeight(validator) < MIN_ACTIVATE_AMOUNT) {
            if (!activated) {
                return ValidatorStatus.REGISTERED;
            }
            return ValidatorStatus.INACTIVE;
        }

        if (!activated) {
            return ValidatorStatus.READY;
        }
        return ValidatorStatus.ACTIVE;
    }

    /// @notice Returns if the given validator is in jail or not.
    /// @param validator Address of the validator.
    /// @return If the given validator is in jail or not.
    function inJail(address validator) public view returns (bool) {
        return _jail[validator] != 0;
    }

    /// @notice Returns if the status of the given validator is active.
    /// @param validator Address of the validator.
    /// @return If the status of the given validator is active.
    function isActive(address validator) public view returns (bool) {
        if (getStatus(validator) == ValidatorStatus.ACTIVE) return true;
        return false;
    }

    /// @notice Returns the no submission count of given validator.
    /// @param validator Address of the validator.
    /// @return The no submission count of given validator.
    function noSubmissionCount(address validator) public view returns (uint8) {
        return _validatorInfo[validator].noSubmissionCount;
    }

    /// @notice Returns when commission change of given validator can be finalized.
    /// @param validator Address of the validator.
    /// @return When commission change of given validator can be finalized.
    function canFinalizeCommissionChangeAt(address validator) public view returns (uint128) {
        return _validatorInfo[validator].commissionChangeInitiatedAt + COMMISSION_CHANGE_DELAY_SECONDS;
    }

    /// @notice Returns the total weight of activated validators.
    /// @return The total weight of activated validators.
    function activatedValidatorTotalWeight() public view returns (uint120) {
        return _validatorTree.nodes[_validatorTree.root].weightSum;
    }

    /// @notice Private function to activate a validator and adds the validator to validator tree.
    /// @param validator Address of the validator.
    function _activateValidator(address validator) private {
        _validatorTree.insert(validator, uint120(ASSET_MANAGER.reflectiveWeight(validator)));

        emit ValidatorActivated(validator, block.timestamp);
    }

    /// @notice Private function to add output submission rewards to the vaults of finalized output
    ///         submitters.
    /// @return Whether the reward distribution is done at least once or not.
    function _distributeReward() private returns (bool) {
        uint256 outputIndex = L2_ORACLE.nextFinalizeOutputIndex();
        uint256 latestOutputIndex = L2_ORACLE.latestOutputIndex();

        uint128 finalizedOutputNum = 0;
        address submitter;

        while (finalizedOutputNum < MAX_OUTPUT_FINALIZATIONS && outputIndex <= latestOutputIndex) {
            if (L2_ORACLE.isFinalized(outputIndex)) {
                submitter = L2_ORACLE.getSubmitter(outputIndex);

                (uint128 baseReward, uint128 boostedReward, uint128 validatorReward) = _calculateReward(submitter);

                ASSET_MANAGER.increaseBalanceWithReward(submitter, baseReward, boostedReward, validatorReward);

                emit RewardDistributed(outputIndex, submitter, validatorReward, baseReward, boostedReward);

                uint128 challengeReward = _pendingChallengeReward[outputIndex];
                if (challengeReward > 0) {
                    challengeReward = ASSET_MANAGER.increaseBalanceWithChallenge(submitter, challengeReward);
                    delete _pendingChallengeReward[outputIndex];

                    emit ChallengeRewardDistributed(outputIndex, submitter, challengeReward);
                }

                updateValidatorTree(submitter, false);

                unchecked {
                    ++outputIndex;
                    ++finalizedOutputNum;
                }
            } else {
                break;
            }
        }

        if (finalizedOutputNum > 0) {
            L2_ORACLE.setNextFinalizeOutputIndex(outputIndex);

            return true;
        }

        return false;
    }

    /// @notice Internal function to get the boosted reward with the number of KGH.
    /// @param validator Address of the validator.
    /// @return The boosted reward with the number of KGH.
    function _getBoostedReward(address validator) internal view returns (uint128) {
        uint128 numKgh = ASSET_MANAGER.totalKghNum(validator);
        uint128 coefficient = BASE_REWARD.mulDiv(BOOSTED_REWARD_NUMERATOR, BOOSTED_REWARD_DENOM);
        return uint128(Atan2.atan2(numKgh, 100).mulDiv(coefficient, 1 << 40));
    }

    /// @notice Internal function to calculate the reward of the validator when distributing reward.
    /// @param validator Address of the validator.
    /// @return The amount of base reward, excluding base reward for the validator.
    /// @return The amount of boosted reward.
    /// @return The amount of reward from commission and base reward for the validator.
    function _calculateReward(address validator) internal view returns (uint128, uint128, uint128) {
        if (validator == ASSET_MANAGER.SECURITY_COUNCIL()) {
            return (0, 0, BASE_REWARD);
        }

        uint128 commissionRate = _validatorInfo[validator].commissionRate;
        uint128 boostedReward = _getBoostedReward(validator);
        uint128 baseReward;
        uint128 validatorReward;

        unchecked {
            validatorReward = (BASE_REWARD + boostedReward).mulDiv(commissionRate, COMMISSION_RATE_DENOM);
            baseReward = BASE_REWARD.mulDiv(COMMISSION_RATE_DENOM - commissionRate, COMMISSION_RATE_DENOM);
            boostedReward = boostedReward.mulDiv(COMMISSION_RATE_DENOM - commissionRate, COMMISSION_RATE_DENOM);

            uint128 validatorKro = ASSET_MANAGER.totalValidatorKro(validator);
            uint128 totalKro = ASSET_MANAGER.totalKroAssets(validator);
            uint128 validatorBaseReward = baseReward.mulDiv(validatorKro, totalKro + validatorKro);
            // Exclude the base reward for the validator from total base reward given to KRO delegators.
            baseReward -= validatorBaseReward;
            validatorReward += validatorBaseReward;
        }

        return (baseReward, boostedReward, validatorReward);
    }

    /// @notice Updates next priority validator address. Validators with more delegation tokens have
    ///         a higher probability of being selected. The random weight selection is based on the
    ///         last finalized output root.
    function _updatePriorityValidator() private {
        uint120 weightSum = activatedValidatorTotalWeight();
        uint256 nextFinalizeOutputIndex = L2_ORACLE.nextFinalizeOutputIndex();

        if (weightSum > 0 && nextFinalizeOutputIndex > 0) {
            KromaTypes.CheckpointOutput memory output = L2_ORACLE.getL2Output(nextFinalizeOutputIndex - 1);

            uint120 weight = uint120(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            output.outputRoot,
                            block.number,
                            block.coinbase,
                            block.difficulty,
                            blockhash(block.number - 1)
                        )
                    )
                )
            ) % weightSum;

            _nextPriorityValidator = _validatorTree.select(weight);
        } else {
            _nextPriorityValidator = address(0);
        }
    }

    /// @notice Attempts to jail a validator who was selected as a priority validator for this
    ///         submission round but did not submit the output. The period to get out of jail is
    ///         SOFT_JAIL_PERIOD_SECONDS.
    function _tryJail() private {
        if (_nextPriorityValidator == address(0)) return;

        if (_validatorInfo[_nextPriorityValidator].noSubmissionCount >= JAIL_THRESHOLD) {
            _sendToJail(_nextPriorityValidator, true);
        } else {
            unchecked {
                _validatorInfo[_nextPriorityValidator].noSubmissionCount++;
            }
        }
    }

    /// @notice Send the given validator to the jail and remove from the validator tree.
    /// @param validator Address of the validator.
    /// @param isSoft    Whether the jail is soft or hard.
    function _sendToJail(address validator, bool isSoft) private {
        uint128 jailSeconds = isSoft ? SOFT_JAIL_PERIOD_SECONDS : HARD_JAIL_PERIOD_SECONDS;
        uint128 expiresAt = _jail[validator].max(uint128(block.timestamp)) + jailSeconds;
        _jail[validator] = expiresAt;

        emit ValidatorJailed(validator, expiresAt);

        if (_validatorTree.remove(validator)) emit ValidatorStopped(validator, block.timestamp);
    }

    /// @notice Attempts to reset non-submission count of a validator.
    /// @param validator Address of the validator.
    function _resetNoSubmissionCount(address validator) private {
        if (noSubmissionCount(validator) > 0) {
            _validatorInfo[validator].noSubmissionCount = 0;
        }
    }
}
