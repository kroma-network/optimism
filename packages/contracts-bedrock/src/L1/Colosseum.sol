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

    /// @notice legacy space for the mapping of segmentsLengths.
    uint256 private spacer_1_0_32;

    /// @notice legacy space for the mapping of the challenge.
    uint256 private spacer_2_0_32;

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

    /// @notice The interval in L2 blocks at which checkpoints must be
    ///         submitted on L2OutputOracle contract.
    uint256 public l2OracleSubmissionInterval;

    /// @notice A period during which guardians verify whether the challenge result is correct.
    uint256 public guardianPeriodSeconds;

    /// @notice A duration for asserter(or challenger) timeout.
    uint256 public maxClockDurationSeconds;

    /// @notice The grace period that provides additional time for the challenger's timer
    ///         to allow for zk proof generation.
    uint256 public challengeGracePeriodSeconds;

    /// @notice Maps each output index to its corresponding assertion object.
    mapping(uint256 => KromaTypes.Assertion) public assertions;

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
    event Bisected(uint256 indexed outputIndex, address indexed challenger, uint256 turn, uint256 timestamp);

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

    /// @notice Reverts when L1 is reorged.
    error L1Reorged();

    /// @notice Reverts when the public input is already verified.
    error AlreadyVerifiedPublicInput();

    /// @notice Reverts when the public input hash is invalid.
    error InvalidPublicInputHash();

    /// @notice Reverts when the public input is invalid.
    error InvalidPublicInput();

    /// @notice Reverts when challenge cannot be cancelled.
    error CannotCancelChallenge();

    /// @notice Reverts when assertion for the output is already created
    error AssertionAlreadyCreated();

    /// @notice Reverts when an asserter has timed out
    error AsserterTimeout();

    /// @notice Reverts when a challenger has timed out
    error ChallengerTimeout();

    /// @notice Reverts when a challenge cannot be created or progressed
    error NotChallengeable();

    /// @notice Reverts when the challenge has been already created
    error ChallengeAlreadyCreated();

    /// @notice Reverts when bisecting is attempted when the challenge is already in a "ready to prove" state
    error BisectUnnecessary();

    /// @notice Reverts when pos is invalid in bisect
    error InvalidSegmentPosition();

    /// @notice Reverts when an assertion cannot be accepted due to unmet conditions
    error AssertionNotAcceptable();

    /// @notice Reverts when an assertion doesn't exist
    error AssertionNotFound();

    /// @notice A modifier that only allows L2OutputOracle contract to call.
    modifier onlyL2OutputOracle() {
        if (msg.sender != address(l2Oracle)) revert NotAllowedCaller();
        _;
    }

    /// @notice Semantic version.
    /// @custom:semver 3.0.0
    string public constant version = "3.0.0";

    /// @notice Constructs the Colosseum contract.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializer
    /// @param _l2Oracle                Address of the L2OutputOracle contract
    /// @param _zkProofVerifier         Address of the ZKProofVerifier contract
    /// @param _submissionInterval      Interval in blocks at which checkpoints must be submitted
    /// @param _securityCouncil         Address of security council
    /// @param _guardianPeriod          A period during which guardians verify whether the challenge result is correct
    /// @param _maxClockDurationSeconds A duration for asserter(or challenger) timeout
    /// @param _challengeGracePeriod    The grace period that provides additional time for the challenger's timer
   function initialize(
        address _l2Oracle,
        IZKProofVerifier _zkProofVerifier,
        uint256 _submissionInterval,
        address _securityCouncil,
        uint256 _guardianPeriod,
        uint256 _maxClockDurationSeconds,
        uint256 _challengeGracePeriod
    )
        public
        reinitializer(2)
    {
        l2Oracle = IKromaL2OutputOracle(_l2Oracle);
        zkProofVerifier = IZKProofVerifier(_zkProofVerifier);
        l2OracleSubmissionInterval = _submissionInterval;
        securityCouncil = ISecurityCouncil(_securityCouncil);
        guardianPeriodSeconds = _guardianPeriod;
        maxClockDurationSeconds = _maxClockDurationSeconds;
        challengeGracePeriodSeconds = _challengeGracePeriod;
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

    /// @notice Getter for the l2OracleSubmissionInterval.
    ///         Public getter is legacy and will be removed in the future. Use `l2OracleSubmissionInterval` instead.
    /// @return The interval in L2 blocks at which checkpoints must be submitted on L2OutputOracle contract.
    /// @custom:legacy
    function L2_ORACLE_SUBMISSION_INTERVAL() external view returns (uint256) {
        return l2OracleSubmissionInterval;
    }

    /// @notice Creates a new assertion for a specific L2 output.
    /// @param _outputIndex The index of the L2 output being asserted.
    /// @param asserter     The address of the validator making the assertion.
    function createAssertion(uint256 _outputIndex, address asserter) external onlyL2OutputOracle {
        if (_outputIndex == 0) revert NotAllowedGenesisOutput();

        uint256 latestFinalizedOutputIndex = l2Oracle.getLatestFinalizedOutputIndex();

        KromaTypes.Assertion storage assertion = assertions[_outputIndex];

        if (assertion.asserter != address(0)) {
            revert AssertionAlreadyCreated();
        }

        assertion.latestFinalizedOutputIndex = latestFinalizedOutputIndex;
        assertion.asserter = asserter;
        assertion.assertedAt = block.timestamp;
    }

    /// @notice Creates a challenge against an invalid output.
    /// @param _outputIndex   Index of the invalid L2 checkpoint output.
    /// @param _l1BlockHash   The block hash of L1 at the time the output L2 block was created.
    /// @param _l1BlockNumber The block number of L1 with the specified L1 block hash.
    function createChallenge(
        uint256 _outputIndex,
        bytes32 _l1BlockHash,
        uint256 _l1BlockNumber
    ) external {
        if (_outputIndex == 0) revert NotAllowedGenesisOutput();

        // Only the validators whose status is active can create challenge.
        if (!l2Oracle.validatorManager().isActive(msg.sender))
            revert ImproperValidatorStatus();

        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        KromaTypes.Challenge storage challenge = assertion.challenges[msg.sender];

        if (challenge.turn >= TURN_INIT) {
            if (_challengeStatus(challenge) != ChallengeStatus.CHALLENGER_TIMEOUT) {
                revert ImproperChallengeStatus();
            }
            _challengerTimeout(_outputIndex, msg.sender);
        }

        KromaTypes.AssertionStatus assertionStatus = _assertionStatus(assertion);
        if (
            assertionStatus == KromaTypes.AssertionStatus.REJECTED ||
            assertionStatus == KromaTypes.AssertionStatus.ENFORCED
        ) {
            revert NotChallengeable();
        }

        assertion.numChallenges++;

        KromaTypes.CheckpointOutput memory targetOutput = l2Oracle.getL2Output(_outputIndex);

        if (msg.sender == targetOutput.submitter) revert NotAllowedCaller();

        if (_l1BlockHash != bytes32(0) && blockhash(_l1BlockNumber) != bytes32(0)) {
            // Like L2OutputOracle, it reverts transactions when L1 reorged.
            if (blockhash(_l1BlockNumber) != _l1BlockHash) revert L1Reorged();
        }

        challenge.challenger = msg.sender;
        challenge.asserter = assertion.asserter;
        challenge.turn = TURN_INIT;

        uint256 elapsed = block.timestamp - assertion.assertedAt;
        if (elapsed > maxClockDurationSeconds) {
            revert ChallengerTimeout();
        }

        KromaTypes.CheckpointOutput memory latestFinalizedOutput = l2Oracle.getL2Output(
            assertion.latestFinalizedOutputIndex
        );

        challenge.challengerTimeLeft = maxClockDurationSeconds - elapsed;
        challenge.asserterTimeLeft = maxClockDurationSeconds;
        challenge.updatedAt = block.timestamp;
        challenge.segment.start = latestFinalizedOutput.l2BlockNumber;
        challenge.segment.startOutput = latestFinalizedOutput.outputRoot;
        challenge.segment.end = targetOutput.l2BlockNumber;
        challenge.segment.endOutput = targetOutput.outputRoot;
        challenge.segment.pos = (targetOutput.l2BlockNumber + latestFinalizedOutput.l2BlockNumber) /  2;
        challenge.segment.output = targetOutput.outputRoot;
        challenge.l1Head = blockhash(block.number - 1);

        // Bond validator KRO to reserve slashing amount.
        l2Oracle.validatorManager().bondValidatorKro(msg.sender);

        emit ChallengeCreated(_outputIndex, assertion.asserter, msg.sender, block.timestamp);
    }

    /// @notice Finds the latest block that both parties agree on.
    ///         This function performs a bisection search to locate the most recent block
    ///         where both participants have consensus.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    /// @param _pos         The midpoint position between the current start and end in the bisection process.
    /// @param _output      The output value at the given position `_pos`.
    function bisect(
        uint256 _outputIndex,
        address _challenger,
        uint256 _pos,
        bytes32 _output
    ) external {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];

        // If assertion doesn't exist
        if (assertion.assertedAt == 0) {
            revert InvalidOutputGiven();
        }

        KromaTypes.Challenge storage challenge = assertion.challenges[_challenger];
        ChallengeStatus status = _challengeStatus(challenge);
        if (_cancelIfChallengeImpossible(_outputIndex, challenge.challenger, status)) {
            return;
        }

        KromaTypes.AssertionStatus assertionStatus = _assertionStatus(assertion);
        if (
            assertionStatus == KromaTypes.AssertionStatus.REJECTED ||
            assertionStatus == KromaTypes.AssertionStatus.ENFORCED
        ) {
            revert NotChallengeable();
        }

        if (status == ChallengeStatus.ASSERTER_TURN) {
            if (msg.sender != challenge.asserter) {
                revert NotAllowedCaller();
            }
            uint256 elapsed = block.timestamp - challenge.updatedAt;
            challenge.asserterTimeLeft -= elapsed;
        } else if (status == ChallengeStatus.CHALLENGER_TURN) {
            if (msg.sender != challenge.challenger) {
                revert NotAllowedCaller();
            }
            uint256 elapsed = block.timestamp - challenge.updatedAt;
            challenge.challengerTimeLeft -= elapsed;
        } else if (status == ChallengeStatus.ASSERTER_TIMEOUT) {
            revert AsserterTimeout();
        } else if (status == ChallengeStatus.CHALLENGER_TIMEOUT) {
            revert ChallengerTimeout();
        } else if (status == ChallengeStatus.NONE) {
            revert ImproperChallengeStatus();
        } else if (status == ChallengeStatus.READY_TO_PROVE) {
            revert BisectUnnecessary();
        }

        if (_pos < challenge.segment.pos) {
            challenge.segment.end = challenge.segment.pos;
            challenge.segment.endOutput = challenge.segment.output;
        } else if (_pos > challenge.segment.pos) {
            challenge.segment.start = challenge.segment.pos;
            challenge.segment.startOutput = challenge.segment.output;
        } else {
            revert InvalidSegmentPosition();
        }

        if (_pos != (challenge.segment.start + challenge.segment.end) / 2) {
            revert InvalidSegmentPosition();
        }

        uint256 newTurn = challenge.turn + 1;
        challenge.turn = newTurn;
        challenge.segment.output = _output;
        challenge.updatedAt = block.timestamp;
        challenge.segment.pos = _pos;

        if (_challengeStatus(challenge) == ChallengeStatus.READY_TO_PROVE) {
            emit ReadyToProve(_outputIndex, _challenger);
        }

        emit Bisected(_outputIndex, _challenger, newTurn, block.timestamp);
    }

    /// @notice Proves that a specific output is invalid using zkVM proof.
    ///         This function can only be called in the READY_TO_PROVE and ASSERTER_TIMEOUT statuses.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _zkVmProof   The public input and proof using zkVM.
    function proveFaultWithZkVm(
        uint256 _outputIndex,
        KromaTypes.ZkVmProof calldata _zkVmProof
    ) external {
        _proveFault(_outputIndex, _zkVmProof);
    }

    /// @notice Calls a private function that deletes the challenge because the challenger has timed out.
    ///         Reverts if the challenger hasn't timed out.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    function challengerTimeout(uint256 _outputIndex, address _challenger) external {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        if (_challengeStatus(assertion.challenges[_challenger]) != ChallengeStatus.CHALLENGER_TIMEOUT)
            revert ImproperChallengeStatus();

        _challengerTimeout(_outputIndex, _challenger);
    }

    /// @notice Accepts an assertion if there are no active challenges and the timeout period has elapsed.
    /// @param _outputIndex Index of the L2 checkpoint output.
    function acceptAssertion(uint256 _outputIndex) external {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        KromaTypes.AssertionStatus assertionStatus = _assertionStatus(assertion);

        if (
            assertion.numChallenges > 0 ||
            assertionStatus != KromaTypes.AssertionStatus.IN_PROGRESS ||
            block.timestamp - assertion.assertedAt < maxClockDurationSeconds
        ) {
            revert AssertionNotAcceptable();
        }

        assertion.acceptedAt = block.timestamp;
    }

    /// @notice Cancels the challenge.
    ///         Reverts if is not possible to cancel the sender's challenge for the given output index.
    /// @param _outputIndex Index of the L2 checkpoint output.
    function cancelChallenge(uint256 _outputIndex) external {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        KromaTypes.Challenge storage challenge = assertion.challenges[msg.sender];

        if (
            !_cancelIfChallengeImpossible(
                _outputIndex,
                challenge.challenger,
                _challengeStatus(challenge)
            )
        ) revert CannotCancelChallenge();
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
    ) external {
        _checkSecurityCouncil();
        _checkOutputNotFinalized(_outputIndex);

        if (l2Oracle.getL2Output(_outputIndex).outputRoot != DELETED_OUTPUT_ROOT)
            revert OutputNotDeleted();
        if (_outputRoot != deletedOutputs[_outputIndex].outputRoot) revert InvalidOutputGiven();
        if (_challenger != l2Oracle.getSubmitter(_outputIndex) || _asserter != deletedOutputs[_outputIndex].submitter) {
            revert InvalidAddressGiven();
        }
        if (!verifiedPublicInputs[_publicInputHash]) revert InvalidPublicInputHash();

        verifiedPublicInputs[_publicInputHash] = false;
        delete deletedOutputs[_outputIndex];

        // Rollback output root.
        l2Oracle.replaceL2Output(_outputIndex, _outputRoot, _asserter);

        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        assertion.isEnforced = true;

        // Revert slash asserter.
        l2Oracle.validatorManager().revertSlash(_outputIndex, _asserter);
        // Slash challenger.
        l2Oracle.validatorManager().slash(_outputIndex, _asserter, _challenger);

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
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        assertion.isEnforced = true;

        // Slash the asserter's asset and move it to pending challenge reward for the output.
        l2Oracle.validatorManager().slash(_outputIndex, address(securityCouncil), output.submitter);

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

    /// @notice Proves that a specific output is invalid using ZKP.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _zkVmProof   The public input and proof using zkVM.
    function _proveFault(uint256 _outputIndex, KromaTypes.ZkVmProof calldata _zkVmProof) private {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        KromaTypes.Challenge storage challenge = assertion.challenges[msg.sender];
        ChallengeStatus status = _challengeStatus(challenge);

        if (_cancelIfChallengeImpossible(_outputIndex, challenge.challenger, status)) {
            return;
        }

        KromaTypes.AssertionStatus assertionStatus = _assertionStatus(assertion);
        if (
            assertionStatus == KromaTypes.AssertionStatus.REJECTED ||
            assertionStatus == KromaTypes.AssertionStatus.ENFORCED
        ) {
            revert NotChallengeable();
        }

        if (status != ChallengeStatus.READY_TO_PROVE && status != ChallengeStatus.ASSERTER_TIMEOUT)
            revert ImproperChallengeStatus();

        // Slice from index 8 to 40 to extract the srcOutputRoot,
        // as publicValues contains concatenated bytes32 values.
        // Each bytes32 value occupies 32 bytes, so this range corresponds to the first public input.
        bytes32 srcOutput = bytes32(_zkVmProof.publicValues[8:40]);
        bytes32 dstOutput;
        if (srcOutput == challenge.segment.output) {
            dstOutput = challenge.segment.endOutput;
        } else if (srcOutput == challenge.segment.startOutput) {
            dstOutput = challenge.segment.output;
        } else {
            revert InvalidPublicInput();
        }
        bytes32 publicInputHash = zkProofVerifier.verifyZkVmProof(
            _zkVmProof,
            srcOutput,
            dstOutput,
            challenge.l1Head
        );

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
            securityCouncil.requestValidation(
                output.outputRoot,
                output.l2BlockNumber,
                callbackData
            );

            deletedOutputs[_outputIndex] = output;
        }

        // Slash the asserter's asset and move it to pending challenge reward for the output.
        l2Oracle.validatorManager().slash(_outputIndex, msg.sender, challenge.asserter);

        verifiedPublicInputs[publicInputHash] = true;
        delete assertion.challenges[msg.sender];

        assertion.rejectedAt = block.timestamp;

        // Delete output root.
        l2Oracle.replaceL2Output(_outputIndex, DELETED_OUTPUT_ROOT, msg.sender);
    }


    /// @notice Cancels the challenge if it can no longer be progressed.
    ///         A challenge becomes unresolvable when the associated assertion is either RESTORED or REJECTED.
    ///         Reverts if the challenger is timed out or called by a non-challenger.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    /// @param _status      Current status of the challenge.
    /// @return Whether the challenge was canceled.
    function _cancelIfChallengeImpossible(
        uint256 _outputIndex,
        address _challenger,
        ChallengeStatus _status
    ) private returns (bool) {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];

        // If assertion doesn't exist
        if (assertion.assertedAt == 0) {
            revert InvalidOutputGiven();
        }

        KromaTypes.AssertionStatus assertionStatus = _assertionStatus(assertion);

        if (
            assertionStatus == KromaTypes.AssertionStatus.IN_PROGRESS ||
            assertionStatus == KromaTypes.AssertionStatus.ACCEPTED
        ) {
            return false;
        }

        // If the challenge can no longer be progressed. the asserter does not need to do anything further.
        if (msg.sender != _challenger) revert OnlyChallengerCanCancel();

        if (_status == ChallengeStatus.NONE || _status == ChallengeStatus.CHALLENGER_TIMEOUT)
            revert ImproperChallengeStatusToCancel();

        delete assertion.challenges[msg.sender];
        emit ChallengeCanceled(_outputIndex, msg.sender, block.timestamp);

        l2Oracle.validatorManager().unbondValidatorKro(msg.sender);

        return true;
    }

    /// @notice Handles the challenger timeout scenario by removing the challenge and transferring assets.
    ///         When a challenger times out, the asserter wins and the challenger forfeits their bond.
    /// @param _outputIndex The index of the L2 checkpoint output being challenged
    /// @param _challenger  The address of the challenger who timed out
    function _challengerTimeout(uint256 _outputIndex, address _challenger) private {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        delete assertion.challenges[_challenger];
        assertion.numChallenges--;
        emit ChallengerTimedOut(_outputIndex, _challenger, block.timestamp);

        l2Oracle.validatorManager().slash(
            _outputIndex,
            l2Oracle.getSubmitter(_outputIndex),
            _challenger
        );
    }


    /// @notice Determines if bisection is possible.
    /// @param _challenge The current challenge data.
    /// @return Whether bisection is possible.
    function _isAbleToBisect(KromaTypes.Challenge storage _challenge) internal view returns (bool) {
        return _challenge.segment.start + 2 < _challenge.segment.end;
    }
    /// @notice Returns status of a given assertion.
    /// @param _assertion The assertion data.
    /// @return The status of the assertion.
    function _assertionStatus(
        KromaTypes.Assertion storage _assertion
    ) internal view returns (KromaTypes.AssertionStatus) {
        if (_assertion.assertedAt == 0) {
            revert AssertionNotFound();
        }
        if (_assertion.isEnforced) {
            return KromaTypes.AssertionStatus.ENFORCED;
        } else if (_assertion.acceptedAt != 0) {
            return KromaTypes.AssertionStatus.ACCEPTED;
        } else if (_assertion.rejectedAt != 0) {
            return KromaTypes.AssertionStatus.REJECTED;
        } else {
            return KromaTypes.AssertionStatus.IN_PROGRESS;
        }
    }

    /// @notice Returns status of a given challenge.
    /// @param _challenge The challenge data.
    /// @return The status of the challenge.
    function _challengeStatus(
        KromaTypes.Challenge storage _challenge
    ) internal view returns (ChallengeStatus) {
        if (_challenge.turn < TURN_INIT) {
            return ChallengeStatus.NONE;
        }

        // If the turn is even, it means that the asserter has completed its turn,
        // so the next turn will be the challenger's turn.
        bool isChallengerTurn = _challenge.turn % 2 == 0;

        // Check if it's a timed out challenge.
        if (isChallengerTurn) {
            if (_isTimeout(_challenge, _challenge.challenger)) {
                return ChallengeStatus.CHALLENGER_TIMEOUT;
            }
        } else {
            if (_isTimeout(_challenge, _challenge.asserter)) {
                return ChallengeStatus.ASSERTER_TIMEOUT;
            }
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
    ) external view returns (KromaTypes.Challenge memory) {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        return assertion.challenges[_challenger];
    }

    /// @notice Returns the assertion data for a given output index
    /// @param _outputIndex Index of the L2 checkpoint output
    /// @return The assertion view data
    function getAssertion(uint256 _outputIndex) external view returns (KromaTypes.AssertionView memory) {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];

        return
            KromaTypes.AssertionView({
                latestFinalizedOutputIndex: assertion.latestFinalizedOutputIndex,
                assertedAt: assertion.assertedAt,
                acceptedAt: assertion.acceptedAt,
                rejectedAt: assertion.rejectedAt,
                numberOfChallenges: assertion.numChallenges,
                asserter: assertion.asserter,
                isEnforced: assertion.isEnforced
            });
    }

    /// @notice Returns the challenge status corresponding to the given L2 output index.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @param _challenger  Address of the challenger.
    /// @return The status of the challenge.
    function getStatus(
        uint256 _outputIndex,
        address _challenger
    ) external view returns (ChallengeStatus) {
        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        KromaTypes.Challenge storage challenge = assertion.challenges[_challenger];
        return _challengeStatus(challenge);
    }

    /// @notice Returns the assertion status corresponding to the given L2 output index.
    /// @param _outputIndex Index of the L2 checkpoint output.
    /// @return The status of the assertion.
    function getAssertionStatus(
        uint256 _outputIndex
    ) external view returns (KromaTypes.AssertionStatus) {
        return _assertionStatus(assertions[_outputIndex]);
    }

    /// @notice Returns whether the actor is timed out.
    /// @param _challenge The target challenge stored in storage.
    /// @param _actor     The address of either the challenger or the asserter.
    /// @return Whether the actor has timed out
    function _isTimeout(
        KromaTypes.Challenge storage _challenge,
        address _actor
    ) internal view returns (bool) {
        if (_actor == _challenge.challenger) {
            if (_isAbleToBisect(_challenge)) {
                return block.timestamp >= _challenge.updatedAt + _challenge.challengerTimeLeft;
            } else {
                return block.timestamp >= _challenge.updatedAt + _challenge.challengerTimeLeft + guardianPeriodSeconds;
            }
        } else if (_actor == _challenge.asserter) {
            return block.timestamp >= _challenge.updatedAt + _challenge.asserterTimeLeft;
        } else {
            revert InvalidAddressGiven();
        }
    }

    /// @notice Returns if the output of given index is finalized.
    /// @param _outputIndex Index of an output.
    /// @return If the given output is finalized or not.
    function isFinalized(uint256 _outputIndex) external view returns (bool) {
        // The genesis output is treated as a finalized output.
        if (_outputIndex == 0) {
            return true;
        }

        KromaTypes.Assertion storage assertion = assertions[_outputIndex];
        if (assertion.assertedAt == 0) {
            return false;
        }

        KromaTypes.AssertionStatus assertionStatus = _assertionStatus(assertion);

        // Check if output is finalized based on assertion status
        if (assertionStatus == KromaTypes.AssertionStatus.ENFORCED) {
            return l2Oracle.getL2Output(_outputIndex).outputRoot != bytes32(0);
        }
        if (assertionStatus == KromaTypes.AssertionStatus.ACCEPTED) {
            return block.timestamp > assertion.acceptedAt + guardianPeriodSeconds;
        }
        if (assertionStatus == KromaTypes.AssertionStatus.IN_PROGRESS) {
            return assertion.numChallenges == 0 &&
                   block.timestamp > assertion.assertedAt + guardianPeriodSeconds + maxClockDurationSeconds;
        }
        return false;
    }
}
