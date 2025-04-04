// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Contracts
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Libraries
import { Constants } from "src/libraries/Constants.sol";
import { KromaConstants } from "src/libraries/KromaConstants.sol";
import { KromaTypes } from "src/libraries/KromaTypes.sol";

// Interfaces
import { ISemver } from "interfaces/universal/ISemver.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";

/// @custom:proxied
/// @title KromaL2OutputOracle
/// @notice The KromaL2OutputOracle contains an array of L2 state outputs, where each output is a
///         commitment to the state of the L2 chain. Other contracts like the OptimismPortal use
///         these outputs to verify information about the state of L2.
contract KromaL2OutputOracle is Initializable, ISemver {
    /// @notice The number of the first L2 block recorded in this contract.
    uint256 public startingBlockNumber;

    /// @notice The timestamp of the first L2 block recorded in this contract.
    uint256 public startingTimestamp;

    /// @notice Array of L2 checkpoint outputs.
    KromaTypes.CheckpointOutput[] internal l2Outputs;

    /// @notice The output index of the next finalization target output.
    uint256 public nextFinalizeOutputIndex;

    /// @notice The address of the validator manager contract. Can be updated via upgrade.
    IValidatorManager public validatorManager;

    /// @notice The address of the colosseum contract. Can be updated via upgrade.
    address public colosseum;

    /// @notice The interval in L2 blocks at which checkpoints must be submitted. Although this is
    ///         immutable, it can be modified by upgrading the implementation contract.
    ///         Note that nodes that fetch and use this value need to restart when it is modified.
    uint256 public submissionInterval;

    /// @notice The time between L2 blocks in seconds. Once set, this value MUST NOT be modified.
    uint256 public l2BlockTime;

    /// @notice Minimum time (in seconds) that must elapse before a withdrawal can be finalized.
    uint256 public finalizationPeriodSeconds;

    /// @notice Emitted when an output is submitted.
    /// @param outputRoot    The output root.
    /// @param l2OutputIndex The index of the output in the l2Outputs array.
    /// @param l2BlockNumber The L2 block number of the output root.
    /// @param l1Timestamp   The L1 timestamp when submitted.
    event OutputSubmitted(
        bytes32 indexed outputRoot, uint256 indexed l2OutputIndex, uint256 indexed l2BlockNumber, uint256 l1Timestamp
    );

    /// @notice Emitted when an output is replaced.
    /// @param outputIndex   Replaced L2 output index.
    /// @param newSubmitter  Output submitter after replacement.
    /// @param newOutputRoot L2 output root after replacement.
    event OutputReplaced(uint256 indexed outputIndex, address indexed newSubmitter, bytes32 newOutputRoot);

    /// @notice Semantic version.
    /// @custom:semver 1.2.0
    string public constant version = "1.2.0";

    /// @notice Constructs the L2OutputOracle contract. Initializes variables to the same values as
    ///         in the getting-started config.
    constructor() {
        initialize({
            _validatorManager: IValidatorManager(address(0)),
            _colosseum: address(0),
            _submissionInterval: 1,
            _l2BlockTime: 1,
            _startingBlockNumber: 0,
            _startingTimestamp: 0,
            _finalizationPeriodSeconds: 0
        });
    }

    /// @notice Initializer
    /// @param _validatorManager          The address of the ValidatorManager contract.
    /// @param _colosseum                 The address of the Colosseum contract.
    /// @param _submissionInterval        Interval in blocks at which checkpoints must be submitted.
    /// @param _l2BlockTime               The time per L2 block, in seconds.
    /// @param _startingBlockNumber       The number of the first L2 block.
    /// @param _startingTimestamp         The timestamp of the first L2 block.
    /// @param _finalizationPeriodSeconds Output finalization time in seconds.
    function initialize(
        IValidatorManager _validatorManager,
        address _colosseum,
        uint256 _submissionInterval,
        uint256 _l2BlockTime,
        uint256 _startingBlockNumber,
        uint256 _startingTimestamp,
        uint256 _finalizationPeriodSeconds
    )
        public
        reinitializer(2)
    {
        require(_l2BlockTime > 0, "L2OutputOracle: L2 block time must be greater than 0");
        require(_submissionInterval > 0, "L2OutputOracle: submission interval must be greater than 0");
        require(
            _startingTimestamp <= block.timestamp,
            "L2OutputOracle: starting L2 timestamp must be less than current time"
        );
        validatorManager = IValidatorManager(_validatorManager);
        colosseum = _colosseum;
        submissionInterval = _submissionInterval;
        l2BlockTime = _l2BlockTime;
        startingBlockNumber = _startingBlockNumber;
        startingTimestamp = _startingTimestamp;
        finalizationPeriodSeconds = _finalizationPeriodSeconds;
    }

    /// @notice Getter for the validatorManager address.
    ///         Public getter is legacy and will be removed in the future. Use `validatorManager` instead.
    /// @return Address of the validatorManager.
    /// @custom:legacy
    function VALIDATOR_MANAGER() external view returns (IValidatorManager) {
        return validatorManager;
    }

    /// @notice Getter for the colosseum address.
    ///         Public getter is legacy and will be removed in the future. Use `colosseum` instead.
    /// @return Address of the colosseum.
    /// @custom:legacy
    function COLOSSEUM() external view returns (address) {
        return colosseum;
    }

    /// @notice Getter for the submissionInterval.
    ///         Public getter is legacy and will be removed in the future. Use `submissionInterval` instead.
    /// @return Submission interval.
    /// @custom:legacy
    function SUBMISSION_INTERVAL() external view returns (uint256) {
        return submissionInterval;
    }

    /// @notice Getter for the l2BlockTime.
    ///         Public getter is legacy and will be removed in the future. Use `l2BlockTime` instead.
    /// @return L2 block time.
    /// @custom:legacy
    function L2_BLOCK_TIME() external view returns (uint256) {
        return l2BlockTime;
    }

    /// @notice Getter for the finalizationPeriodSeconds.
    ///         Public getter is legacy and will be removed in the future. Use `finalizationPeriodSeconds` instead.
    /// @return Finalization period in seconds.
    /// @custom:legacy
    function FINALIZATION_PERIOD_SECONDS() external view returns (uint256) {
        return finalizationPeriodSeconds;
    }

    /// @notice Replaces the output that corresponds to the given output index.
    ///         Only the Colosseum contract can replace an output.
    /// @param _l2OutputIndex Index of the L2 output to be replaced.
    /// @param _newOutputRoot The L2 output root to replace the existing one.
    /// @param _submitter     Address of the L2 output submitter.
    function replaceL2Output(uint256 _l2OutputIndex, bytes32 _newOutputRoot, address _submitter) external {
        require(msg.sender == colosseum, "L2OutputOracle: only the colosseum contract can replace an output");

        require(_submitter != address(0), "L2OutputOracle: submitter address cannot be zero");

        // Make sure we're not *increasing* the length of the array.
        require(
            _l2OutputIndex < l2Outputs.length, "L2OutputOracle: cannot replace an output after the latest output index"
        );

        KromaTypes.CheckpointOutput storage output = l2Outputs[_l2OutputIndex];
        // Do not allow replacing any outputs that have already been finalized.
        require(
            block.timestamp - output.timestamp < finalizationPeriodSeconds,
            "L2OutputOracle: cannot replace an output that has already been finalized"
        );

        output.outputRoot = _newOutputRoot;
        output.submitter = _submitter;

        emit OutputReplaced(_l2OutputIndex, _submitter, _newOutputRoot);
    }

    /// @notice Accepts an outputRoot and the block number of the corresponding L2 block.
    ///         The block number must be equal to the current value returned by `nextBlockNumber()`
    ///         in order to be accepted. This function may only be called by the validator.
    /// @param _outputRoot    The L2 output of the checkpoint block.
    /// @param _l2BlockNumber The L2 block number that resulted in _outputRoot.
    /// @param _l1BlockHash   A block hash which must be included in the current chain.
    /// @param _l1BlockNumber The block number with the specified block hash.
    function submitL2Output(
        bytes32 _outputRoot,
        uint256 _l2BlockNumber,
        bytes32 _l1BlockHash,
        uint256 _l1BlockNumber
    )
        external
        payable
    {
        validatorManager.checkSubmissionEligibility(msg.sender);

        require(
            _l2BlockNumber == nextBlockNumber(),
            "L2OutputOracle: block number must be equal to next expected block number"
        );

        require(nextOutputMinL2Timestamp() <= block.timestamp, "L2OutputOracle: cannot submit L2 output in the future");

        require(_outputRoot != bytes32(0), "L2OutputOracle: L2 checkpoint output cannot be the zero hash");

        if (_l1BlockHash != bytes32(0) && blockhash(_l1BlockNumber) != bytes32(0)) {
            // This check allows the validator to submit an output based on a given L1 block,
            // without fear that it will be reorged out.
            // It will be skipped if the blockheight provided is more than 256 blocks behind the
            // chain tip (as the hash will return as zero).
            require(
                blockhash(_l1BlockNumber) == _l1BlockHash,
                "L2OutputOracle: block hash does not match the hash at the expected height"
            );
        }

        uint256 outputIndex = nextOutputIndex();

        l2Outputs.push(
            KromaTypes.CheckpointOutput({
                submitter: msg.sender,
                outputRoot: _outputRoot,
                timestamp: uint128(block.timestamp),
                l2BlockNumber: uint128(_l2BlockNumber)
            })
        );

        emit OutputSubmitted(_outputRoot, outputIndex, _l2BlockNumber, block.timestamp);

        validatorManager.afterSubmitL2Output(outputIndex);
    }

    /// @notice Updates the next output index to be finalized.
    /// @param _outputIndex Index of the next output to be finalized.
    function setNextFinalizeOutputIndex(uint256 _outputIndex) external {
        require(
            msg.sender == address(validatorManager),
            "L2OutputOracle: only the validator manager contract can set next finalize output index"
        );

        nextFinalizeOutputIndex = _outputIndex;
    }

    /// @notice Returns an output by index. Reverts if output is not found at the given index.
    /// @param _l2OutputIndex Index of the output to return.
    /// @return The output at the given index.
    function getL2Output(uint256 _l2OutputIndex) external view returns (KromaTypes.CheckpointOutput memory) {
        return l2Outputs[_l2OutputIndex];
    }

    /// @notice Returns the index of the L2 output that checkpoints a given L2 block number. Uses a
    ///         binary search to find the first output greater than or equal to the given block.
    /// @param _l2BlockNumber L2 block number to find a checkpoint for.
    /// @return Index of the first checkpoint that commits to the given L2 block number.
    function getL2OutputIndexAfter(uint256 _l2BlockNumber) public view returns (uint256) {
        // Make sure an output for this block number has actually been submitted.
        require(
            _l2BlockNumber <= latestBlockNumber(),
            "L2OutputOracle: cannot get output for a block that has not been submitted"
        );

        // Make sure there's at least one output submitted.
        require(l2Outputs.length > 0, "L2OutputOracle: cannot get output as no outputs have been submitted yet");

        // Find the output via binary search, guaranteed to exist.
        uint256 lo = 0;
        uint256 hi = l2Outputs.length;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (l2Outputs[mid].l2BlockNumber < _l2BlockNumber) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }

        return lo;
    }

    /// @notice Returns the L2 checkpoint output that checkpoints a given L2 block number.
    /// @param _l2BlockNumber L2 block number to find a checkpoint for.
    /// @return First checkpoint that commits to the given L2 block number.
    function getL2OutputAfter(uint256 _l2BlockNumber) external view returns (KromaTypes.CheckpointOutput memory) {
        return l2Outputs[getL2OutputIndexAfter(_l2BlockNumber)];
    }

    /// @notice Returns the index of the latest submitted output. Will revert if no outputs
    ///         have been submitted yet.
    /// @return The index of the latest submitted output.
    function latestOutputIndex() external view returns (uint256) {
        return l2Outputs.length - 1;
    }

    /// @notice Returns the index of the next output to be submitted.
    /// @return The index of the next output to be submitted.
    function nextOutputIndex() public view returns (uint256) {
        return l2Outputs.length;
    }

    /// @notice Returns the block number of the latest submitted L2 checkpoint output. If no outputs
    ///         have been submitted yet then this function will return the starting block number.
    /// @return Latest submitted L2 block number.
    function latestBlockNumber() public view returns (uint256) {
        return l2Outputs.length == 0 ? startingBlockNumber : l2Outputs[l2Outputs.length - 1].l2BlockNumber;
    }

    /// @notice Computes the block number of the next L2 block that needs to be checkpointed. If no
    ///         outputs have been submitted yet then this function will return the latest block
    ///         number, which is the starting block number.
    /// @return Next L2 block number.
    function nextBlockNumber() public view returns (uint256) {
        return l2Outputs.length == 0 ? latestBlockNumber() : latestBlockNumber() + submissionInterval;
    }

    /// @notice Returns the L2 timestamp corresponding to a given L2 block number.
    /// @param _l2BlockNumber The L2 block number of the target block.
    /// @return L2 timestamp of the given block.
    function computeL2Timestamp(uint256 _l2BlockNumber) public view returns (uint256) {
        return startingTimestamp + ((_l2BlockNumber - startingBlockNumber) * l2BlockTime);
    }

    /// @notice Returns the L2 timestamp corresponding to the right next block of the block that
    ///         needs to be checkpointed.
    ///         Note that the added one is because of the existence of next block hash in the output.
    /// @return L2 timestamp of the right next block of the block that needs to be checkpointed.
    function nextOutputMinL2Timestamp() public view returns (uint256) {
        return computeL2Timestamp(nextBlockNumber() + 1);
    }

    /// @notice Returns the address of the L2 output submitter.
    /// @param _outputIndex Index of an output.
    /// @return Address of the submitter.
    function getSubmitter(uint256 _outputIndex) external view returns (address) {
        //        if (_outputIndex == 0) {
        //            return validatorManager.trustedValidator();
        //        }
        return l2Outputs[_outputIndex].submitter;
    }

    /// @notice Returns if the output of given index is finalized.
    /// @param _outputIndex Index of an output.
    /// @return If the given output is finalized or not.
    function isFinalized(uint256 _outputIndex) external view returns (bool) {
        return finalizedAt(_outputIndex) <= block.timestamp;
    }

    /// @notice Returns the finalization time of given output index.
    /// @param _outputIndex Index of an output.
    /// @return The finalization time of given output index.
    function finalizedAt(uint256 _outputIndex) public view returns (uint256) {
        return l2Outputs[_outputIndex].timestamp + finalizationPeriodSeconds;
    }
}
