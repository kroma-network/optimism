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

    /// @notice Struct representing a challenge.
    /// @custom:field turn       The current turn.
    /// @custom:field timeoutAt  Timeout timestamp of the next turn.
    /// @custom:field asserter   Address of the asserter.
    /// @custom:field challenger Address of the challenger.
    /// @custom:field segments   Array of the segment.
    /// @custom:field segStart   The L2 block number of the first segment.
    /// @custom:field segSize    The number of L2 blocks.
    /// @custom:field l1Head     Parent L1 block hash at the challenge creation time.
    struct Challenge {
        uint8 turn;
        uint64 timeoutAt;
        address asserter;
        address challenger;
        bytes32[] segments;
        uint256 segSize;
        uint256 segStart;
        bytes32 l1Head;
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
    /// @param zkVmProgramVKey The verification key for the zkVM program.
    /// @param publicValues    The public values concatenated.
    ///                        (Currently 3 public inputs: bytes32 srcOutputRoot, bytes32 dstOutputRoot, bytes32 l1Head)
    /// @param proofBytes      The proof of the program execution the SP1 zkVM encoded as bytes.
    struct ZkVmProof {
        bytes32 zkVmProgramVKey;
        bytes publicValues;
        bytes proofBytes;
    }
}
