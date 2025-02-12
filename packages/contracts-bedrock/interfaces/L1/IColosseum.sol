// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { ZKProofVerifier } from "src/L1/ZKProofVerifier.sol";
import { KromaTypes } from "src/libraries/KromaTypes.sol";

interface IColosseum {
    enum ChallengeStatus {
        NONE,
        CHALLENGER_TURN,
        ASSERTER_TURN,
        CHALLENGER_TIMEOUT,
        ASSERTER_TIMEOUT,
        READY_TO_PROVE
    }

    error AlreadyVerifiedPublicInput();
    error CannotCancelChallenge();
    error CreationPeriodPassed();
    error FirstSegmentMismatched();
    error ImproperChallengeStatus();
    error ImproperChallengeStatusToCancel();
    error ImproperValidatorStatus();
    error InvalidAddressGiven();
    error InvalidOutputGiven();
    error InvalidPublicInputHash();
    error InvalidSegmentsLength();
    error InvalidTurn();
    error L1Reorged();
    error LastSegmentMatched();
    error NotAllowedCaller();
    error NotAllowedGenesisOutput();
    error OnlyChallengerCanCancel();
    error OutputAlreadyDeleted();
    error OutputAlreadyFinalized();
    error OutputNotDeleted();

    event Bisected(uint256 indexed outputIndex, address indexed challenger, uint8 turn, uint256 timestamp);
    event ChallengeCanceled(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);
    event ChallengeCreated(
        uint256 indexed outputIndex, address indexed asserter, address indexed challenger, uint256 timestamp
    );
    event ChallengeDismissed(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);
    event ChallengerTimedOut(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);
    event Initialized(uint8 version);
    event OutputForceDeleted(uint256 indexed outputIndex, address indexed asseter, uint256 timestamp);
    event Proven(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);
    event ReadyToProve(uint256 indexed outputIndex, address indexed challenger);

    function BISECTION_TIMEOUT() external view returns (uint256);
    function CREATION_PERIOD_SECONDS() external view returns (uint256);
    function L2_ORACLE() external view returns (L2OutputOracle);
    function L2_ORACLE_SUBMISSION_INTERVAL() external view returns (uint256);
    function PROVING_TIMEOUT() external view returns (uint256);
    function SECURITY_COUNCIL() external view returns (address);
    function ZK_PROOF_VERIFIER() external view returns (ZKProofVerifier);
    function bisect(uint256 _outputIndex, address _challenger, uint256 _pos, bytes32[] memory _segments) external;
    function cancelChallenge(uint256 _outputIndex) external;
    function challengerTimeout(uint256 _outputIndex, address _challenger) external;
    function challenges(
        uint256,
        address
    )
        external
        view
        returns (
            uint8 turn,
            uint64 timeoutAt,
            address asserter,
            address challenger,
            uint256 segSize,
            uint256 segStart,
            bytes32 l1Head
        );
    function createChallenge(
        uint256 _outputIndex,
        bytes32 _l1BlockHash,
        uint256 _l1BlockNumber,
        bytes32[] memory _segments
    )
        external;
    function deletedOutputs(uint256)
        external
        view
        returns (address submitter, bytes32 outputRoot, uint128 timestamp, uint128 l2BlockNumber);
    function dismissChallenge(
        uint256 _outputIndex,
        address _challenger,
        address _asserter,
        bytes32 _outputRoot,
        bytes32 _publicInputHash
    )
        external;
    function forceDeleteOutput(uint256 _outputIndex) external;
    function getChallenge(
        uint256 _outputIndex,
        address _challenger
    )
        external
        view
        returns (KromaTypes.Challenge memory);
    function getStatus(uint256 _outputIndex, address _challenger) external view returns (ChallengeStatus);
    function initialize(uint256[] memory _segmentsLengths) external;
    function isInCreationPeriod(uint256 _outputIndex) external view returns (bool);
    function proveFaultWithZkVm(uint256 _outputIndex, uint256 _pos, KromaTypes.ZkVmProof memory _zkVmProof) external;
    function segmentsLengths(uint256) external view returns (uint256);
    function verifiedPublicInputs(bytes32) external view returns (bool);
    function version() external view returns (string memory);

    function __constructor__(
        L2OutputOracle _l2Oracle,
        ZKProofVerifier _zkProofVerifier,
        uint256 _submissionInterval,
        uint256 _creationPeriodSeconds,
        uint256 _bisectionTimeout,
        uint256 _provingTimeout,
        uint256[] memory _segmentsLengths,
        address _securityCouncil
    )
        external;
}
