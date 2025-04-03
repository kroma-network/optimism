// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Types } from "./Types.sol";

/// @title KromaTypes
/// @notice Contains various types used throughout the Kroma contract system.
library KromaTypes {
    /// @notice CheckpointOutput represents a commitment to the state of L2 checkpoint. The timestamp
    ///         is the L1 timestamp that the output root is posted. This timestamp is used to verify
    ///         that the finalization period has passed since the output root was submitted.
    /// @custom:field submitter     Address of the output submitter.
    /// @custom:field outputRoot    Hash of the L2 output.
    /// @custom:field timestamp     Timestamp of the L1 block that the output root was submitted in.
    /// @custom:field l2BlockNumber L2 block number that the output corresponds to.
    struct CheckpointOutput {
        address submitter;
        bytes32 outputRoot;
        uint128 timestamp;
        uint128 l2BlockNumber;
    }

    /// @notice Struct representing multisig transaction data.
    /// @custom:field target   The destination address to run the transaction.
    /// @custom:field executed Record whether a transaction was executed or not.
    /// @custom:field value    The value passed in while executing the transaction.
    /// @custom:field data     Calldata for transaction.
    struct MultiSigTransaction {
        address target;
        bool executed;
        uint256 value;
        bytes data;
    }

    /// @notice Struct representing multisig confirmation data.
    /// @custom:field confirmationCount The sum of confirmations.
    /// @custom:field confirmedBy       Map data that stores whether confirmation is performed by account.
    struct MultiSigConfirmation {
        uint256 confirmationCount;
        mapping(address => bool) confirmedBy;
    }

    /// @notice Struct representing zkVM public input and proof.
    /// @custom:field zkVmProgramVKey The verification key for the zkVM program.
    /// @custom:field publicValues    The public values concatenated.
    ///                        (Currently 3 public inputs: bytes32 srcOutputRoot, bytes32 dstOutputRoot, bytes32 l1Head)
    /// @custom:field proofBytes      The proof of the program execution the SP1 zkVM encoded as bytes.
    struct ZkVmProof {
        bytes32 zkVmProgramVKey;
        bytes publicValues;
        bytes proofBytes;
    }

    /// @notice Struct representing a challenge.
    /// @custom:field turn               The current turn.
    /// @custom:field asserterTimeLeft   Total remaining time for the asserter in the challenge, based on the chess clock model.
    /// @custom:field challengerTimeLeft Total remaining time for the challenger in the challenge, based on the chess clock model.
    /// @custom:field updatedAt          Timestamp of the last update to the challenge.
    /// @custom:field asserter           Address of the asserter.
    /// @custom:field challenger         Address of the challenger.
    /// @custom:field segment            The segment being disputed in the challenge.
    /// @custom:field l1Head             The L1 head at the time of challenge creation.
    struct Challenge {
        uint256 turn;
        uint256 asserterTimeLeft;
        uint256 challengerTimeLeft;
        uint256 updatedAt;
        address asserter;
        address challenger;
        Segment segment;
        bytes32 l1Head;
    }

    /// @notice A struct grouping output-related values to avoid stack too deep errors.
    /// @custom:field output      The output value at the specified position.
    /// @custom:field pos         The mid-point position within the current start and end range.
    /// @custom:field start       The starting position of the current segment.
    /// @custom:field end         The ending position of the current segment.
    /// @custom:field startOutput The output value at the start position.
    /// @custom:field endOutput   The output value at the end position.
    struct Segment {
        bytes32 output;
        uint256 pos;
        uint256 start;
        uint256 end;
        bytes32 startOutput;
        bytes32 endOutput;
    }

    /// @notice Struct representing a assertion.
    /// @custom:field latestFinalizedOutputIndex Starting point for bisection.
    /// @custom:field asserter                   Address of the asserter.
    /// @custom:field assertedAt                 Timestamp when the assertion was created
    /// @custom:field acceptedAt                 Timestamp when the assertion was accepted.
    /// @custom:field rejectedAt                 Timestamp when the assertion was rejected.
    /// @custom:field status                     Current status of the assertion.
    /// @custom:field challenges                 Challenges related to the assertion. The key of the mapping is the challenger's address.
    /// @custom:field numChallenges              Number of challenges raised against the assertion.
    /// @custom:field isEnforced                 Indicates that the Assertion has been adjusted due to the intervention of the Security Council.
    struct Assertion {
        uint256 latestFinalizedOutputIndex;
        uint256 assertedAt;
        uint256 acceptedAt;
        uint256 rejectedAt;
        uint256 numChallenges;
        mapping(address => Challenge) challenges;
        address asserter;
        bool isEnforced;
    }

    /// @notice View struct for the Assertion, excluding the challenges mapping.
    /// @custom:field latestFinalizedOutputIndex Starting point for bisection.
    /// @custom:field asserter                   Address of the asserter.
    /// @custom:field assertedAt                 Timestamp when the assertion was created
    /// @custom:field acceptedAt                 Timestamp when the assertion was accepted.
    /// @custom:field rejectedAt                 Timestamp when the assertion was rejected.
    /// @custom:field status                     Current status of the assertion.
    /// @custom:field isEnforced                 Indicates that the Assertion has been adjusted due to the intervention of the Security Council.
    struct AssertionView {
        uint256 latestFinalizedOutputIndex;
        uint256 assertedAt;
        uint256 acceptedAt;
        uint256 rejectedAt;
        uint256 numberOfChallenges;
        address asserter;
        bool isEnforced;
    }

    /// @notice Enum of the Assertion status.
    /// See the https://specs.kroma.network/fault-proof/challenge.html#state-diagram
    /// for more details.
    ///
    /// Belows are possible state transitions at current implementation.
    ///
    /// 1) IN_PROGRESS → createAssertion()
    /// 2) ACCEPTED    → when challenger's timer has expired
    /// 3) REJECTED    → when proveFault() succeeds or asserter timeout
    /// 4) ENFORCED    → when a assertion is enforced by SC
    enum AssertionStatus {
        IN_PROGRESS,
        ACCEPTED,
        REJECTED,
        ENFORCED
    }

    /// @notice Struct representing a validator's bond.
    /// @custom:field amount    Amount of the lock.
    /// @custom:field expiresAt The expiration timestamp of bond.
    struct Bond {
        uint128 amount;
        uint128 expiresAt;
    }
}
