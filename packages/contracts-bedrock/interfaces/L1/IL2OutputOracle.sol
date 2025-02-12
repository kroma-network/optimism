// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { KromaTypes } from "src/libraries/KromaTypes.sol";
import { Types } from "src/libraries/Types.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";

interface IL2OutputOracle {
    // TODO(sm-stack): Remove these Optimism L2OutputOracle methods after fixing tests and deployment process.
    event Initialized(uint8 version);
    event OutputProposed(
        bytes32 indexed outputRoot, uint256 indexed l2OutputIndex, uint256 indexed l2BlockNumber, uint256 l1Timestamp
    );
    event OutputsDeleted(uint256 indexed prevNextOutputIndex, uint256 indexed newNextOutputIndex);

    function CHALLENGER() external view returns (address);
    function FINALIZATION_PERIOD_SECONDS() external view returns (uint256);
    function L2_BLOCK_TIME() external view returns (uint256);
    function PROPOSER() external view returns (address);
    function SUBMISSION_INTERVAL() external view returns (uint256);
    function challenger() external view returns (address);
    function computeL2Timestamp(uint256 _l2BlockNumber) external view returns (uint256);
    function deleteL2Outputs(uint256 _l2OutputIndex) external;
    function finalizationPeriodSeconds() external view returns (uint256);
    function getL2Output(uint256 _l2OutputIndex) external view returns (Types.OutputProposal memory);
    function getL2OutputAfter(uint256 _l2BlockNumber) external view returns (Types.OutputProposal memory);
    function getL2OutputIndexAfter(uint256 _l2BlockNumber) external view returns (uint256);
    function initialize(
        uint256 _submissionInterval,
        uint256 _l2BlockTime,
        uint256 _startingBlockNumber,
        uint256 _startingTimestamp,
        address _proposer,
        address _challenger,
        uint256 _finalizationPeriodSeconds
    )
        external;
    function l2BlockTime() external view returns (uint256);
    function latestBlockNumber() external view returns (uint256);
    function latestOutputIndex() external view returns (uint256);
    function nextBlockNumber() external view returns (uint256);
    function nextOutputIndex() external view returns (uint256);
    function proposeL2Output(
        bytes32 _outputRoot,
        uint256 _l2BlockNumber,
        bytes32 _l1BlockHash,
        uint256 _l1BlockNumber
    )
        external
        payable;
    function proposer() external view returns (address);
    function startingBlockNumber() external view returns (uint256);
    function startingTimestamp() external view returns (uint256);
    function submissionInterval() external view returns (uint256);
    function version() external view returns (string memory);

    function __constructor__() external;

    // TODO(sm-stack): Uncomment this after fixing compile errors at deploy and tests.
    /*
    event Initialized(uint8 version);
    event OutputReplaced(uint256 indexed outputIndex, address indexed newSubmitter, bytes32 newOutputRoot);
    event OutputSubmitted(
    bytes32 indexed outputRoot, uint256 indexed l2OutputIndex, uint256 indexed l2BlockNumber, uint256 l1Timestamp
    );

    function COLOSSEUM() external view returns (address);
    function FINALIZATION_PERIOD_SECONDS() external view returns (uint256);
    function L2_BLOCK_TIME() external view returns (uint256);
    function SUBMISSION_INTERVAL() external view returns (uint256);
    function VALIDATOR_MANAGER() external view returns (address);
    function computeL2Timestamp(uint256 _l2BlockNumber) external view returns (uint256);
    function finalizedAt(uint256 _outputIndex) external view returns (uint256);
    function getL2Output(uint256 _l2OutputIndex) external view returns (KromaTypes.CheckpointOutput memory);
    function getL2OutputAfter(uint256 _l2BlockNumber) external view returns (KromaTypes.CheckpointOutput memory);
    function getL2OutputIndexAfter(uint256 _l2BlockNumber) external view returns (uint256);
    function getSubmitter(uint256 _outputIndex) external view returns (address);
    function initialize(uint256 _startingBlockNumber, uint256 _startingTimestamp) external;
    function isFinalized(uint256 _outputIndex) external view returns (bool);
    function latestBlockNumber() external view returns (uint256);
    function latestOutputIndex() external view returns (uint256);
    function nextBlockNumber() external view returns (uint256);
    function nextFinalizeOutputIndex() external view returns (uint256);
    function nextOutputIndex() external view returns (uint256);
    function nextOutputMinL2Timestamp() external view returns (uint256);
    function replaceL2Output(uint256 _l2OutputIndex, bytes32 _newOutputRoot, address _submitter) external;
    function setNextFinalizeOutputIndex(uint256 _outputIndex) external;
    function startingBlockNumber() external view returns (uint256);
    function startingTimestamp() external view returns (uint256);
    function submitL2Output(bytes32 _outputRoot, uint256 _l2BlockNumber, bytes32 _l1BlockHash, uint256 _l1BlockNumber)
        external
        payable;
    function version() external view returns (string memory);
    function __constructor__() external;
    */
}
