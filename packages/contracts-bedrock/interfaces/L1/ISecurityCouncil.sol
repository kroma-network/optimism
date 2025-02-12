// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { UpgradeGovernor } from "src/governance/UpgradeGovernor.sol";

interface ISecurityCouncil {
    event ConfirmationRevoked(address indexed sender, uint256 indexed transactionId);
    event DeletionRequested(uint256 indexed transactionId, uint256 indexed outputIndex);
    event Initialized(uint8 version);
    event TransactionConfirmed(address indexed sender, uint256 indexed transactionId);
    event TransactionExecuted(address indexed sender, uint256 indexed transactionId);
    event TransactionSubmitted(address indexed sender, uint256 indexed transactionId);
    event ValidationRequested(uint256 indexed transactionId, bytes32 outputRoot, uint256 l2BlockNumber);

    function COLOSSEUM() external view returns (address);
    function GOVERNOR() external view returns (UpgradeGovernor);
    function clock() external view returns (uint48);
    function confirmTransaction(uint256 _transactionId) external;
    function confirmations(uint256) external view returns (uint256 confirmationCount);
    function executeTransaction(uint256 _transactionId) external;
    function generateTransactionId(
        address _target,
        uint256 _value,
        bytes memory _data
    )
        external
        view
        returns (uint256);
    function getConfirmationCount(uint256 _transactionId) external view returns (uint256);
    function getVotes(address account) external view returns (uint256);
    function isConfirmed(uint256 _transactionId) external view returns (bool);
    function isConfirmedBy(uint256 _transactionId, address _account) external view returns (bool);
    function outputsDeleteRequested(uint256) external view returns (bool);
    function quorum() external view returns (uint256);
    function requestDeletion(uint256 _outputIndex, bool _force) external;
    function requestValidation(bytes32 _outputRoot, uint256 _l2BlockNumber, bytes memory _data) external;
    function revokeConfirmation(uint256 _transactionId) external;
    function submitTransaction(address _target, uint256 _value, bytes memory _data) external returns (uint256);
    function transactionCount() external view returns (uint256);
    function transactions(uint256)
        external
        view
        returns (address target, bool executed, uint256 value, bytes memory data);
    function version() external view returns (string memory);

    function __constructor__(address _colosseum, address payable _governor) external;
}
