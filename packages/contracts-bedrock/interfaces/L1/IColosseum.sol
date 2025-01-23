// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { ZKProofVerifier } from "src/L1/ZKProofVerifier.sol";
import { KromaTypes } from "src/libraries/KromaTypes.sol";

enum ChallengeStatus {
    NONE,
    CHALLENGER_TURN,
    ASSERTER_TURN,
    CHALLENGER_TIMEOUT,
    ASSERTER_TIMEOUT,
    READY_TO_PROVE
}

interface IColosseum {
    error NotAllowedCaller();
    error OnlyChallengerCanCancel();
    error OutputAlreadyFinalized();
    error OutputAlreadyDeleted();
    error ImproperValidatorStatus();
    error OutputNotDeleted();
    error InvalidOutputGiven();
    error InvalidAddressGiven();
    error NotAllowedGenesisOutput();
    error ImproperChallengeStatus();
    error ImproperChallengeStatusToCancel();
    error CreationPeriodPassed();
    error L1Reorged();
    error InvalidSegmentsLength();
    error FirstSegmentMismatched();
    error LastSegmentMatched();
    error AlreadyVerifiedPublicInput();
    error InvalidPublicInputHash();
    error InvalidTurn();
    error CannotCancelChallenge();

    event Initialized(uint8 version);
    event ChallengeCreated(
        uint256 indexed outputIndex, address indexed asserter, address indexed challenger, uint256 timestamp
    );
    event Bisected(uint256 indexed outputIndex, address indexed challenger, uint8 turn, uint256 timestamp);
    event ReadyToProve(uint256 indexed outputIndex, address indexed challenger);
    event Proven(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);
    event ChallengeDismissed(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);
    event OutputForceDeleted(uint256 indexed outputIndex, address indexed asseter, uint256 timestamp);
    event ChallengeCanceled(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);
    event ChallengerTimedOut(uint256 indexed outputIndex, address indexed challenger, uint256 timestamp);

    function L2_OUTPUT_ORACLE() external view returns (L2OutputOracle);
    function ZK_PROOF_VERIFIER() external view returns (ZKProofVerifier);
    function CREATION_PERIOD_SECONDS() external view returns (uint256);
    function BISECTION_TIMEOUT() external view returns (uint256);
    function PROVING_TIMEOUT() external view returns (uint256);
    function L2_ORACLE_SUBMISSION_INTERVAL() external view returns (uint256);
    function SECURITY_COUNCIL() external view returns (address);
    function version() external view returns (string memory);

    function segmentsLengths(uint256) external view returns (uint256);
    function challenges(uint256) external view returns (KromaTypes.Challenge memory);
    function verifiedPublicInputs(bytes32) external view returns (bool);
    function deletedOutputs(uint256) external view returns (bool);

    function createChallenge(
        uint256 _outputIndex,
        bytes32 _l1BlockHash,
        uint256 _l1BlockNumber,
        bytes32[] calldata _segments
    )
        external;
    function bisect(uint256 _outputIndex, address _challenger, uint256 _pos, bytes32[] calldata _segments) external;
    function proveFaultWithZkVm(
        uint256 _outputIndex,
        uint256 _pos,
        KromaTypes.ZkVmProof calldata _zkVmProof
    )
        external;
    function cancelChallenge(uint256 _outputIndex) external;
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
    function isInCreationPeriod(uint256 _outputIndex) external view returns (bool);
}
