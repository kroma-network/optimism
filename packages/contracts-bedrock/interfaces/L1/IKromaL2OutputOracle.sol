// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { KromaTypes } from "src/libraries/KromaTypes.sol";
import { IColosseum } from "interfaces/L1/IColosseum.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";
interface IKromaL2OutputOracle {
    event Initialized(uint8 version);
    event OutputReplaced(uint256 indexed outputIndex, address indexed newSubmitter, bytes32 newOutputRoot);
    event OutputSubmitted(
        bytes32 indexed outputRoot, uint256 indexed l2OutputIndex, uint256 indexed l2BlockNumber, uint256 l1Timestamp
    );

    function COLOSSEUM() external view returns (IColosseum);
    function FINALIZATION_PERIOD_SECONDS() external view returns (uint256);
    function L2_BLOCK_TIME() external view returns (uint256);
    function SUBMISSION_INTERVAL() external view returns (uint256);
    function VALIDATOR_MANAGER() external view returns (IValidatorManager);
    function colosseum() external view returns (IColosseum);
    function computeL2Timestamp(uint256 _l2BlockNumber) external view returns (uint256);
    function finalizationPeriodSeconds() external view returns (uint256);
    function getL2Output(uint256 _l2OutputIndex) external view returns (KromaTypes.CheckpointOutput memory);
    function getL2OutputAfter(uint256 _l2BlockNumber) external view returns (KromaTypes.CheckpointOutput memory);
    function getL2OutputIndexAfter(uint256 _l2BlockNumber) external view returns (uint256);
    function getLatestFinalizedOutput() external view returns (KromaTypes.CheckpointOutput memory);
    function getLatestFinalizedOutputIndex() external view returns (uint256);
    function getSubmitter(uint256 _outputIndex) external view returns (address);
    function initialize(
        address _validatorManager,
        address _colosseum,
        uint256 _submissionInterval,
        uint256 _l2BlockTime,
        uint256 _startingBlockNumber,
        uint256 _startingTimestamp,
        uint256 _finalizationPeriodSeconds
    ) external;
    function isFinalized(uint256 _outputIndex) external view returns (bool);
    function l2BlockTime() external view returns (uint256);
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
    function submissionInterval() external view returns (uint256);
    function submitL2Output(bytes32 _outputRoot, uint256 _l2BlockNumber, bytes32 _l1BlockHash, uint256 _l1BlockNumber)
        external
        payable;
    function validatorManager() external view returns (IValidatorManager);
    function version() external view returns (string memory);
    function __constructor__() external;

    // TODO(ayaan) : remove this after fixing compile errors at deploy and tests.
    function PROPOSER() external view returns (address);
    function CHALLENGER() external view returns (address);
    function proposer() external view returns (address);
    function challenger() external view returns (address);
    function proposeL2Output(
        bytes32 _outputRoot,
        uint256 _l2BlockNumber,
        bytes32 _l1BlockHash,
        uint256 _l1BlockNumber
    )
        external
        payable;
}
