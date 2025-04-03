// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IKromaL2OutputOracle } from "interfaces/L1/IKromaL2OutputOracle.sol";
import { ISecurityCouncil } from "interfaces/L1/ISecurityCouncil.sol";
import { IZKProofVerifier } from "interfaces/L1/IZKProofVerifier.sol";
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
    error AsserterTimeout();
    error AssertionAlreadyCreated();
    error AssertionNotAcceptable();
    error AssertionNotFound();
    error BisectUnnecessary();
    error CannotCancelChallenge();
    error ChallengeAlreadyCreated();
    error ChallengerTimeout();
    error ImproperChallengeStatus();
    error ImproperChallengeStatusToCancel();
    error ImproperValidatorStatus();
    error InvalidAddressGiven();
    error InvalidOutputGiven();
    error InvalidPublicInput();
    error InvalidPublicInputHash();
    error InvalidSegmentPosition();
    error L1Reorged();
    error NotAllowedCaller();
    error NotAllowedGenesisOutput();
    error NotChallengeable();
    error OnlyChallengerCanCancel();
    error OutputAlreadyDeleted();
    error OutputAlreadyFinalized();
    error OutputNotDeleted();

    event Bisected(uint256 indexed outputIndex, address indexed challenger, uint256 turn, uint256 timestamp);
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

    function L2_ORACLE() external view returns (address);
    function L2_ORACLE_SUBMISSION_INTERVAL() external view returns (uint256);
    function SECURITY_COUNCIL() external view returns (ISecurityCouncil);
    function ZK_PROOF_VERIFIER() external view returns (IZKProofVerifier);
    function acceptAssertion(uint256 _outputIndex) external;
    function assertions(uint256)
        external
        view
        returns (
            uint256 latestFinalizedOutputIndex,
            uint256 assertedAt,
            uint256 acceptedAt,
            uint256 rejectedAt,
            uint256 numChallenges,
            address asserter,
            bool isEnforced
        );
    function bisect(uint256 _outputIndex, address _challenger, uint256 _pos, bytes32 _output) external;
    function cancelChallenge(uint256 _outputIndex) external;
    function challengeGracePeriodSeconds() external view returns (uint256);
    function challengerTimeout(uint256 _outputIndex, address _challenger) external;
    function createAssertion(uint256 _outputIndex, address asserter) external;
    function createChallenge(uint256 _outputIndex, bytes32 _l1BlockHash, uint256 _l1BlockNumber) external;
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
    ) external;
    function forceDeleteOutput(uint256 _outputIndex) external;
    function getAssertion(uint256 _outputIndex) external view returns (KromaTypes.AssertionView memory);
    function getAssertionStatus(uint256 _outputIndex) external view returns (KromaTypes.AssertionStatus);
    function getChallenge(uint256 _outputIndex, address _challenger) external view returns (KromaTypes.Challenge memory);
    function getStatus(uint256 _outputIndex, address _challenger) external view returns (ChallengeStatus);
    function guardianPeriodSeconds() external view returns (uint256);
    function initialize(
        address _l2Oracle,
        address _zkProofVerifier,
        uint256 _submissionInterval,
        address _securityCouncil,
        uint256 _guardianPeriod,
        uint256 _maxClockDurationSeconds,
        uint256 _challengeGracePeriod
    ) external;
    function isFinalized(uint256 _outputIndex) external view returns (bool);
    function l2Oracle() external view returns (address);
    function l2OracleSubmissionInterval() external view returns (uint256);
    function maxClockDurationSeconds() external view returns (uint256);
    function proveFaultWithZkVm(uint256 _outputIndex, KromaTypes.ZkVmProof memory _zkVmProof) external;
    function securityCouncil() external view returns (ISecurityCouncil);
    function verifiedPublicInputs(bytes32) external view returns (bool);
    function version() external view returns (string memory);
    function zkProofVerifier() external view returns (IZKProofVerifier);
    function __constructor__() external;
}
