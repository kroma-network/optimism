// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Contracts
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Libraries
import { KromaTypes } from "src/libraries/KromaTypes.sol";

// Interfaces
import { ISemver } from "interfaces/universal/ISemver.sol";
import { IKromaL2OutputOracle } from "interfaces/L1/IKromaL2OutputOracle.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";

contract Colosseum is Initializable, ISemver {
    /// @notice The constant value for the first turn.
    uint8 internal constant TURN_INIT = 1;

    /// @notice The constant value for the delete output root.
    bytes32 internal constant DELETED_OUTPUT_ROOT = bytes32(0);

    /// @notice Enum of the challenge status.
    ///
    /// See the https://specs.kroma.network/fault-proof/challenge.html#state-diagram
    /// for more details.
    ///
    /// Belows are possible state transitions at current implementation.
    ///
    ///  1) NONE               → createChallenge()                   → ASSERTER_TURN
    ///  2) ASSERTER_TURN      → bisect()                            → CHALLENGER_TURN
    ///  3) ASSERTER_TURN      → on bisection timeout                → ASSERTER_TIMEOUT
    ///  4) CHALLENGER_TURN    → bisect()                            → ASSERTER_TURN
    ///  5) CHALLENGER_TURN    → when isAbleToBisect() returns false → READY_TO_PROVE
    ///  6) CHALLENGER_TURN    → on bisection timeout                → CHALLENGER_TIMEOUT
    ///  7) ASSERTER_TIMEOUT   → when proveFault() succeeds          → NONE
    ///  8) ASSERTER_TIMEOUT   → on proving timeout                  → CHALLENGER_TIMEOUT
    ///  9) READY_TO_PROVE     → when proveFault() succeeds          → NONE
    /// 10) READY_TO_PROVE     → on proving timeout                  → CHALLENGER_TIMEOUT
    /// 11) CHALLENGER_TIMEOUT → challengerTimeout()                 → NONE
    enum ChallengeStatus {
        NONE,
        CHALLENGER_TURN,
        ASSERTER_TURN,
        CHALLENGER_TIMEOUT,
        ASSERTER_TIMEOUT,
        READY_TO_PROVE
    }

    /// @notice Length of segment array for each turn.
    mapping(uint256 => uint256) public segmentsLengths;

    /// @notice A mapping of the challenge.
    mapping(uint256 => mapping(address => KromaTypes.Challenge)) public challenges;

    /// @notice A mapping indicating whether a public input is verified or not.
    mapping(bytes32 => bool) public verifiedPublicInputs;

    /// @notice A mapping of deleted output index to the deleted output.
    mapping(uint256 => KromaTypes.CheckpointOutput) public deletedOutputs;

    /// @notice Address of the L2OutputOracle.
    IKromaL2OutputOracle public l2Oracle;

    /// @notice Address of the ZKProofVerifier.
    IZKProofVerifier public zkProofVerifier;

    /// @notice Address that has the ability to approve the challenge.
    ISecurityCouncil public securityCouncil;

    /// @notice The period seconds for which challenges can be created per each output.
    uint256 public creationPeriodSeconds;

    /// @notice Timeout seconds for the bisection.
    uint256 public bisectionTimeout;

    /// @notice Timeout seconds for the proving.
    uint256 public provingTimeout;

    /// @notice The interval in L2 blocks at which checkpoints must be
    ///         submitted on L2OutputOracle contract.
    uint256 public l2OracleSubmissionInterval;

    /// @notice Emitted when the challenge is created.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param asserter    Address of the asserter.
    /// @param challenger  Address of the challenger.
    /// @param timestamp   The timestamp when created.
    event ChallengeCreated(
        uint256 indexed outputIndex, address indexed asserter, address indexed challenger, uint256 timestamp
    );

    /// @notice Emitted when segments are bisected.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param challenger  Address of the challenger.
    /// @param turn        The current turn.
    /// @param timestamp   The timestamp when bisected.
    event Bisected(uint256 indexed outputIndex, address indexed challenger, uint8 turn, uint256 timestamp);

    /// @notice Emitted when it is ready to be proved.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param challenger  Address of the challenger.
    event ReadyToProve(uint256 indexed outputIndex, address indexed challenger);

    /// @notice Emitted when proven fault.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param challenger  Address of the challenger.
    /// @param timestamp   The timestamp when proven.
    event Proven(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);

    /// @notice Emitted when challenge is dismissed.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param challenger  Address of the challenger.
    /// @param timestamp   The timestamp when dismissed.
    event ChallengeDismissed(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);

    /// @notice Emitted when challenge is deleted forcefully.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param asseter     Address of the asseter.
    /// @param timestamp   The timestamp when output deleted.
    event OutputForceDeleted(uint256 indexed outputIndex, address indexed asseter, uint256 timestamp);

    /// @notice Emitted when challenge is canceled.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param challenger  Address of the challenger.
    /// @param timestamp   The timestamp when canceled.
    event ChallengeCanceled(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);

    /// @notice Emitted when challenger timed out.
    /// @param outputIndex Index of the L2 checkpoint output.
    /// @param challenger  Address of the challenger.
    /// @param timestamp   The timestamp when deleted.
    event ChallengerTimedOut(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);

    /// @notice Reverts when caller is not allowed.
    error NotAllowedCaller();

    /// @notice Reverts when a non-challenger calls cancel challenge.
    error OnlyChallengerCanCancel();

    /// @notice Reverts when output is already finalized.
    error OutputAlreadyFinalized();

    /// @notice Reverts when output is already deleted.
    error OutputAlreadyDeleted();

    /// @notice Reverts when the status of validator is improper.
    error ImproperValidatorStatus();

    /// @notice Reverts when output is not deleted.
    error OutputNotDeleted();

    /// @notice Reverts when given output is invalid.
    error InvalidOutputGiven();

    /// @notice Reverts when given address is invalid.
    error InvalidAddressGiven();

    /// @notice Reverts when output is genesis output.
    error NotAllowedGenesisOutput();

    /// @notice Reverts when the status of challenge is improper.
    error ImproperChallengeStatus();

    /// @notice Reverts when the status of challenge is improper to cancel challenge.
    error ImproperChallengeStatusToCancel();

    /// @notice Reverts when the creation period is already passed.
    error CreationPeriodPassed();

    /// @notice Reverts when L1 is reorged.
    error L1Reorged();

    /// @notice Reverts when segments length is invalid.
    error InvalidSegmentsLength();

    /// @notice Reverts when the first segment is mismatched.
    error FirstSegmentMismatched();

    /// @notice Reverts when the last segment is matched.
    error LastSegmentMatched();

    /// @notice Reverts when the public input is already verified.
    error AlreadyVerifiedPublicInput();

    /// @notice Reverts when the public input hash is invalid.
    error InvalidPublicInputHash();

    /// @notice Reverts when turn is invalid.
    error InvalidTurn();

    /// @notice Reverts when challenge cannot be cancelled.
    error CannotCancelChallenge();

    /// @notice Semantic version.
    /// @custom:semver 2.1.0
    string public constant version = "2.1.0";

    /// @notice Constructs the Colosseum contract.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializer
    /// @param _l2Oracle              Address of the L2OutputOracle contract.
    /// @param _zkProofVerifier       Address of the ZKProofVerifier contract.
    /// @param _securityCouncil       Address of security council.
    /// @param _submissionInterval    Interval in blocks at which checkpoints must be submitted.
    /// @param _creationPeriodSeconds Seconds The period seconds for which challenges can be created per each output.
    /// @param _bisectionTimeout      Timeout seconds for the bisection.
    /// @param _provingTimeout        Timeout seconds for the proving.
    /// @param _segmentsLengths       Lengths of segments.
    function initialize(
        IKromaL2OutputOracle _l2Oracle,
        IZKProofVerifier _zkProofVerifier,
        ISecurityCouncil _securityCouncil,
        uint256 _submissionInterval,
        uint256 _creationPeriodSeconds,
        uint256 _bisectionTimeout,
        uint256 _provingTimeout,
        uint256[] memory _segmentsLengths
    )
        public
        reinitializer(2)
    {
        l2Oracle = IKromaL2OutputOracle(_l2Oracle);
        zkProofVerifier = IZKProofVerifier(_zkProofVerifier);
        securityCouncil = ISecurityCouncil(_securityCouncil);
        l2OracleSubmissionInterval = _submissionInterval;
        creationPeriodSeconds = _creationPeriodSeconds;
        bisectionTimeout = _bisectionTimeout;
        provingTimeout = _provingTimeout;

        // _segmentsLengths length should be an even number in order to let challenger submit
        // invalidity proof at the last turn.
        if (_segmentsLengths.length % 2 != 0) revert InvalidSegmentsLength();

        uint256 sum = 1;
        for (uint256 i = 0; i < _segmentsLengths.length;) {
            segmentsLengths[i] = _segmentsLengths[i];
            sum = sum * (_segmentsLengths[i] - 1);

            unchecked {
                ++i;
            }
        }

        if (sum != l2OracleSubmissionInterval) revert InvalidSegmentsLength();
    }

    /// @notice Getter for the l2OutputOracle address.
    ///         Public getter is legacy and will be removed in the future. Use `l2Oracle` instead.
    /// @return Address of the l2OutputOracle.
    /// @custom:legacy
    function L2_ORACLE() external view returns (IKromaL2OutputOracle) {
        return l2Oracle;
    }

    /// @notice Getter for the zkProofVerifier address.
    ///         Public getter is legacy and will be removed in the future. Use `zkProofVerifier` instead.
    /// @return Address of the zkProofVerifier.
    /// @custom:legacy
    function ZK_PROOF_VERIFIER() external view returns (IZKProofVerifier) {
        return zkProofVerifier;
    }

    /// @notice Getter for the securityCouncil address.
    ///         Public getter is legacy and will be removed in the future. Use `securityCouncil` instead.
    /// @return Address of the securityCouncil.
    /// @custom:legacy
    function SECURITY_COUNCIL() external view returns (ISecurityCouncil) {
        return securityCouncil;
    }

    /// @notice Getter for the creationPeriodSeconds.
    ///         Public getter is legacy and will be removed in the future. Use `creationPeriodSeconds` instead.
    /// @return The period seconds for which challenges can be created per each output.
    /// @custom:legacy
    function CREATION_PERIOD_SECONDS() external view returns (uint256) {
        return creationPeriodSeconds;
    }

    /// @notice Getter for the bisectionTimeout.
    ///         Public getter is legacy and will be removed in the future. Use `bisectionTimeout` instead.
    /// @return Timeout seconds for the bisection.
    /// @custom:legacy
    function BISECTION_TIMEOUT() external view returns (uint256) {
        return bisectionTimeout;
    }

    /// @notice Getter for the provingTimeout.
    ///         Public getter is legacy and will be removed in the future. Use `provingTimeout` instead.
    /// @return Timeout seconds for the proving.
    /// @custom:legacy
    function PROVING_TIMEOUT() external view returns (uint256) {
        return provingTimeout;
    }

    /// @notice Getter for the l2OracleSubmissionInterval.
    ///         Public getter is legacy and will be removed in the future. Use `l2OracleSubmissionInterval` instead.
    /// @return The interval in L2 blocks at which checkpoints must be submitted on L2OutputOracle contract.
    /// @custom:legacy
    function L2_ORACLE_SUBMISSION_INTERVAL() external view returns (uint256) {
        return l2OracleSubmissionInterval;
    }

    /// @notice Creates a challenge against an invalid output.
    /// @param _outputIndex   Index of the invalid L2 checkpoint output.
    /// @param _l1BlockHash   The block hash of L1 at the time the output L2 block was created.
    /// @param _l1BlockNumber The block number of L1 with the specified L1 block hash.
    /// @param _segments      Array of the segment. A segment is the first output root of a specific range.
    function createChallenge(
        uint256 _outputIndex,
        bytes32 _l1BlockHash,
        uint256 _l1BlockNumber,
        bytes32[] calldata _segments
    )
        external
    {
        if (_outputIndex == 0) revert NotAllowedGenesisOutput();

        // Only the validators whose status is active can create challenge.
        if (!l2Oracle.VALIDATOR_MANAGER().isActive(msg.sender)) {
            revert ImproperValidatorStatus();
        }

        KromaTypes.Challenge storage challenge = challenges[_outputIndex][msg.sender];

        if (challenge.turn >= TURN_INIT) {
            if (_challengeStatus(challenge) != ChallengeStatus.CHALLENGER_TIMEOUT) {
                revert ImproperChallengeStatus();
            }

            _challengerTimeout(_outputIndex, msg.sender);
        }

        KromaTypes.CheckpointOutput memory targetOutput = l2Oracle.getL2Output(_outputIndex);

        if (targetOutput.timestamp + creationPeriodSeconds < block.timestamp) {
            revert CreationPeriodPassed();
        }

        if (targetOutput.outputRoot == DELETED_OUTPUT_ROOT) revert OutputAlreadyDeleted();

        if (msg.sender == targetOutput.submitter) revert NotAllowedCaller();

        if (_l1BlockHash != bytes32(0) && blockhash(_l1BlockNumber) != bytes32(0)) {
            // Like L2OutputOracle, it reverts transactions when L1 reorged.
            if (blockhash(_l1BlockNumber) != _l1BlockHash) revert L1Reorged();
        }

        KromaTypes.CheckpointOutput memory prevOutput = l2Oracle.getL2Output(_outputIndex - 1);

        // If the previous output has been deleted, the first segment will not be compared with the previous output.
        if (prevOutput.outputRoot == DELETED_OUTPUT_ROOT) {
            _validateSegments(TURN_INIT, _segments[0], targetOutput.outputRoot, _segments);
        } else {
            _validateSegments(TURN_INIT, prevOutput.outputRoot, targetOutput.outputRoot, _segments);
        }

        // Bond validator KRO to reserve slashing amount.
        l2Oracle.VALIDATOR_MANAGER().bondValidatorKro(msg.sender);

        _updateSegments(
            challenge, _segments, targetOutput.l2BlockNumber - l2OracleSubmissionInterval, l2OracleSubmissionInterval
        );
        challenge.turn = TURN_INIT;
        challenge.asserter = targetOutput.submitter;
        challenge.challenger = msg.sender;
        challenge.l1Head = blockhash(block.number - 1);
        _updateTimeout(challenge);

        emit ChallengeCreated(_outputIndex, targetOutput.submitter, msg.sender, block.timestamp);
    }

    /// @notice Selects an invalid section and submit segments of that section.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    /// @param _pos         Position of the last valid segment.
    /// @param _segments    Array of the segment. A segment is the first output root of a specific range.
    function bisect(uint256 _outputIndex, address _challenger, uint256 _pos, bytes32[] calldata _segments) external {
        _checkOutputNotFinalized(_outputIndex);

        KromaTypes.Challenge storage challenge = challenges[_outputIndex][_challenger];
        ChallengeStatus status = _challengeStatus(challenge);

        if (_cancelIfOutputDeleted(_outputIndex, challenge.challenger, status)) {
            return;
        }

        address expectedSender;
        if (status == ChallengeStatus.CHALLENGER_TURN) {
            expectedSender = challenge.challenger;
        } else if (status == ChallengeStatus.ASSERTER_TURN) {
            expectedSender = challenge.asserter;
        }
        if (msg.sender != expectedSender) revert NotAllowedCaller();

        uint8 newTurn = challenge.turn + 1;

        _validateSegments(newTurn, challenge.segments[_pos], challenge.segments[_pos + 1], _segments);

        uint256 segSize = _nextSegSize(challenge);
        _updateSegments(challenge, _segments, challenge.segStart + _pos * segSize, segSize);

        challenge.turn = newTurn;
        _updateTimeout(challenge);

        emit Bisected(_outputIndex, _challenger, newTurn, block.timestamp);

        if (!_isAbleToBisect(challenge)) {
            emit ReadyToProve(_outputIndex, _challenger);
        }
    }

    /// @notice Proves that a specific output is invalid using zkVM proof.
    ///         This function can only be called in the READY_TO_PROVE and ASSERTER_TIMEOUT statuses.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _pos         Position of the last valid segment.
    /// @param _zkVmProof   The public input and proof using zkVM.
    function proveFaultWithZkVm(
        uint256 _outputIndex,
        uint256 _pos,
        KromaTypes.ZkVmProof calldata _zkVmProof
    )
        external
    {
        _proveFault(_outputIndex, _pos, _zkVmProof);
    }

    /// @notice Calls a private function that deletes the challenge because the challenger has timed out.
    ///         Reverts if the challenger hasn't timed out.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    function challengerTimeout(uint256 _outputIndex, address _challenger) external {
        if (_challengeStatus(challenges[_outputIndex][_challenger]) != ChallengeStatus.CHALLENGER_TIMEOUT) {
            revert ImproperChallengeStatus();
        }

        _challengerTimeout(_outputIndex, _challenger);
    }

    /// @notice Cancels the challenge.
    ///         Reverts if is not possible to cancel the sender's challenge for the given output index.
    /// @param _outputIndex Index of the L2 checkpoint output.
    function cancelChallenge(uint256 _outputIndex) external {
        KromaTypes.Challenge storage challenge = challenges[_outputIndex][msg.sender];

        if (!_cancelIfOutputDeleted(_outputIndex, challenge.challenger, _challengeStatus(challenge))) {
            revert CannotCancelChallenge();
        }
    }

    /// @notice Dismisses the challenge and rollback l2 output.
    ///         This function can only be called by Security Council contract.
    /// @param _outputIndex      Index of the L2 checkpoint output.
    /// @param _challenger       Address of the challenger.
    /// @param _asserter         Address of the asserter.
    /// @param _outputRoot       The L2 output root to rollback.
    /// @param _publicInputHash  Hash of public input.
    function dismissChallenge(
        uint256 _outputIndex,
        address _challenger,
        address _asserter,
        bytes32 _outputRoot,
        bytes32 _publicInputHash
    )
        external
    {
        _checkSecurityCouncil();
        _checkOutputNotFinalized(_outputIndex);

        if (l2Oracle.getL2Output(_outputIndex).outputRoot != DELETED_OUTPUT_ROOT) {
            revert OutputNotDeleted();
        }
        if (_outputRoot != deletedOutputs[_outputIndex].outputRoot) revert InvalidOutputGiven();
        if (_challenger != l2Oracle.getSubmitter(_outputIndex) || _asserter != deletedOutputs[_outputIndex].submitter) {
            revert InvalidAddressGiven();
        }
        if (!verifiedPublicInputs[_publicInputHash]) revert InvalidPublicInputHash();

        verifiedPublicInputs[_publicInputHash] = false;
        delete deletedOutputs[_outputIndex];

        // Rollback output root.
        l2Oracle.replaceL2Output(_outputIndex, _outputRoot, _asserter);

        // Revert slash asserter.
        l2Oracle.VALIDATOR_MANAGER().revertSlash(_outputIndex, _asserter);
        // Slash challenger.
        l2Oracle.VALIDATOR_MANAGER().slash(_outputIndex, _asserter, _challenger);

        emit ChallengeDismissed(_outputIndex, _challenger, block.timestamp);
    }

    /// @notice Deletes the L2 output root forcefully by the Security Council
    ///         when zk-proving is not possible due to an undeniable bug.
    /// @param _outputIndex Index of the L2 checkpoint output.
    function forceDeleteOutput(uint256 _outputIndex) external {
        _checkSecurityCouncil();
        _checkOutputNotFinalized(_outputIndex);

        // Check if the output is deleted.
        KromaTypes.CheckpointOutput memory output = l2Oracle.getL2Output(_outputIndex);
        if (output.outputRoot == DELETED_OUTPUT_ROOT) revert OutputAlreadyDeleted();

        // Delete output root.
        l2Oracle.replaceL2Output(_outputIndex, DELETED_OUTPUT_ROOT, address(securityCouncil));

        // Slash the asserter's asset and move it to pending challenge reward for the output.
        l2Oracle.VALIDATOR_MANAGER().slash(_outputIndex, address(securityCouncil), output.submitter);

        emit OutputForceDeleted(_outputIndex, output.submitter, block.timestamp);
    }

    /// @notice Reverts if the caller is not security council.
    function _checkSecurityCouncil() internal view {
        if (msg.sender != address(securityCouncil)) revert NotAllowedCaller();
    }

    /// @notice Reverts if the output of given index is already finalized.
    /// @param _outputIndex Index of the L2 checkpoint output.
    function _checkOutputNotFinalized(uint256 _outputIndex) internal view {
        if (l2Oracle.isFinalized(_outputIndex)) revert OutputAlreadyFinalized();
    }

    /// @notice Reverts if the given segments are invalid.
    /// @param _turn      The current turn.
    /// @param _prevFirst The first segment of previous turn.
    /// @param _prevLast  The last segment of previous turn.
    /// @param _segments  Array of the segment.
    function _validateSegments(
        uint8 _turn,
        bytes32 _prevFirst,
        bytes32 _prevLast,
        bytes32[] memory _segments
    )
        internal
        view
    {
        if (segmentsLengths[_turn - 1] != _segments.length) revert InvalidSegmentsLength();
        if (_prevFirst != _segments[0]) revert FirstSegmentMismatched();
        if (_prevLast == _segments[_segments.length - 1]) revert LastSegmentMatched();
    }

    /// @notice Updates the segment information for a given challenge.
    /// @param _challenge The challenge data.
    /// @param _segments  Array of the segment.
    /// @param _segStart  The L2 block number of the first segment.
    /// @param _segSize   The number of L2 blocks.
    function _updateSegments(
        KromaTypes.Challenge storage _challenge,
        bytes32[] memory _segments,
        uint256 _segStart,
        uint256 _segSize
    )
        private
    {
        _challenge.segments = _segments;
        _challenge.segStart = _segStart;
        _challenge.segSize = _segSize;
    }

    /// @notice Updates timestamp of the challenge timeout.
    /// @param _challenge The challenge data to update.
    function _updateTimeout(KromaTypes.Challenge storage _challenge) private {
        if (!_isAbleToBisect(_challenge)) {
            _challenge.timeoutAt = uint64(block.timestamp + provingTimeout);
        } else {
            _challenge.timeoutAt = uint64(block.timestamp + bisectionTimeout);
        }
    }

    /// @notice Proves that a specific output is invalid using ZKP.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _pos         Position of the last valid segment.
    /// @param _zkVmProof   The public input and proof using zkVM.
    function _proveFault(uint256 _outputIndex, uint256 _pos, KromaTypes.ZkVmProof memory _zkVmProof) private {
        _checkOutputNotFinalized(_outputIndex);

        KromaTypes.Challenge storage challenge = challenges[_outputIndex][msg.sender];
        ChallengeStatus status = _challengeStatus(challenge);

        if (_cancelIfOutputDeleted(_outputIndex, challenge.challenger, status)) {
            return;
        }

        if (status != ChallengeStatus.READY_TO_PROVE && status != ChallengeStatus.ASSERTER_TIMEOUT) {
            revert ImproperChallengeStatus();
        }

        bytes32 srcSegment = challenge.segments[_pos];
        // If asserter timeout, the bisection of segments may not have ended.
        // Therefore, segment validation only proceeds when bisection is not possible.
        bytes32 dstSegment;
        if (!_isAbleToBisect(challenge)) dstSegment = challenge.segments[_pos + 1];

        // Verify ZK proof.
        bytes32 publicInputHash = zkProofVerifier.verifyZkVmProof(_zkVmProof, srcSegment, dstSegment, challenge.l1Head);
        if (verifiedPublicInputs[publicInputHash]) revert AlreadyVerifiedPublicInput();

        emit Proven(_outputIndex, msg.sender, block.timestamp);

        // Scope to call the security council, to avoid stack too deep.
        {
            KromaTypes.CheckpointOutput memory output = l2Oracle.getL2Output(_outputIndex);

            bytes memory callbackData = abi.encodeWithSelector(
                this.dismissChallenge.selector,
                _outputIndex,
                msg.sender,
                challenge.asserter,
                output.outputRoot,
                publicInputHash
            );

            // Request outputRoot validation to security council
            securityCouncil.requestValidation(output.outputRoot, output.l2BlockNumber, callbackData);

            deletedOutputs[_outputIndex] = output;
        }

        // Slash the asseter's asset and move it to pending challenge reward for the output.
        l2Oracle.VALIDATOR_MANAGER().slash(_outputIndex, msg.sender, challenge.asserter);

        verifiedPublicInputs[publicInputHash] = true;
        delete challenges[_outputIndex][msg.sender];

        // Delete output root.
        l2Oracle.replaceL2Output(_outputIndex, DELETED_OUTPUT_ROOT, msg.sender);
    }

    /// @notice Cancels the challenge if the output root to be challenged has already been deleted.
    ///         If the output root has been deleted, delete the challenge.
    ///         Reverts when challenger is timed out or called by non-challenger.
    ///
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    /// @param _status      Current status of the challenge.
    /// @return Whether the challenge was canceled.
    function _cancelIfOutputDeleted(
        uint256 _outputIndex,
        address _challenger,
        ChallengeStatus _status
    )
        private
        returns (bool)
    {
        if (l2Oracle.getL2Output(_outputIndex).outputRoot != DELETED_OUTPUT_ROOT) {
            return false;
        }

        // If the output is deleted, the asserter does not need to do anything further.
        if (msg.sender != _challenger) revert OnlyChallengerCanCancel();

        if (_status == ChallengeStatus.NONE || _status == ChallengeStatus.CHALLENGER_TIMEOUT) {
            revert ImproperChallengeStatusToCancel();
        }

        delete challenges[_outputIndex][msg.sender];
        emit ChallengeCanceled(_outputIndex, msg.sender, block.timestamp);

        l2Oracle.VALIDATOR_MANAGER().unbondValidatorKro(msg.sender);

        return true;
    }

    /// @notice Deletes the challenge because the challenger timed out.
    ///         The winner is the asserter, and challenger loses their asset.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    function _challengerTimeout(uint256 _outputIndex, address _challenger) private {
        delete challenges[_outputIndex][_challenger];
        emit ChallengerTimedOut(_outputIndex, _challenger, block.timestamp);

        l2Oracle.VALIDATOR_MANAGER().slash(_outputIndex, l2Oracle.getSubmitter(_outputIndex), _challenger);
    }

    /// @notice Returns the number of L2 blocks for the next turn.
    /// @param _challenge The current challenge data.
    /// @return The number of L2 blocks for the next turn.
    function _nextSegSize(KromaTypes.Challenge storage _challenge) internal view returns (uint256) {
        return _challenge.segSize / (segmentsLengths[_challenge.turn - 1] - 1);
    }

    /// @notice Determines if bisection is possible.
    /// @param _challenge The current challenge data.
    /// @return Whether bisection is possible.
    function _isAbleToBisect(KromaTypes.Challenge storage _challenge) internal view returns (bool) {
        return _nextSegSize(_challenge) > 1;
    }

    /// @notice Returns status of a given challenge.
    /// @param _challenge The challenge data.
    /// @return The status of the challenge.
    function _challengeStatus(KromaTypes.Challenge storage _challenge) internal view returns (ChallengeStatus) {
        if (_challenge.turn < TURN_INIT) {
            return ChallengeStatus.NONE;
        }

        // If the turn is even, it means that the asserter has completed its turn,
        // so the next turn will be the challenger's turn.
        bool isChallengerTurn = _challenge.turn % 2 == 0;

        // Check if it's a timed out challenge.
        if (block.timestamp > _challenge.timeoutAt) {
            // timeout on challenger turn
            if (isChallengerTurn) {
                return ChallengeStatus.CHALLENGER_TIMEOUT;
            }

            // If the asserter times out and the challenger does not prove fault,
            // the challenger is assumed to have timed out.
            if (block.timestamp > _challenge.timeoutAt + provingTimeout) {
                return ChallengeStatus.CHALLENGER_TIMEOUT;
            }

            // timeout on asserter turn
            return ChallengeStatus.ASSERTER_TIMEOUT;
        }

        // If bisection is not possible, the Challenger must execute the fault proof.
        if (!_isAbleToBisect(_challenge)) {
            return ChallengeStatus.READY_TO_PROVE;
        }

        return isChallengerTurn ? ChallengeStatus.CHALLENGER_TURN : ChallengeStatus.ASSERTER_TURN;
    }

    /// @notice Returns the challenge corresponding to the given L2 output index and challenger.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    /// @return The challenge data.
    function getChallenge(
        uint256 _outputIndex,
        address _challenger
    )
        external
        view
        returns (KromaTypes.Challenge memory)
    {
        return challenges[_outputIndex][_challenger];
    }

    /// @notice Returns the challenge status corresponding to the given L2 output index.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    /// @return The status of the challenge.
    function getStatus(uint256 _outputIndex, address _challenger) external view returns (ChallengeStatus) {
        return _challengeStatus(challenges[_outputIndex][_challenger]);
    }

    /// @notice Determines whether current timestamp is in challenge creation period corresponding to the given L2
    /// output
    /// index.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @return Whether current timestamp is in challenge creation period.
    function isInCreationPeriod(uint256 _outputIndex) external view returns (bool) {
        return l2Oracle.getL2Output(_outputIndex).timestamp + creationPeriodSeconds >= block.timestamp;
    }
}
