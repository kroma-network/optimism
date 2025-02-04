// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ITokenMultiSigWallet } from "interfaces/universal/ITokenMultiSigWallet.sol";
import { UpgradeGovernor } from "src/governance/UpgradeGovernor.sol";

interface ISecurityCouncil is ITokenMultiSigWallet {
    event ValidationRequested(uint256 indexed transactionId, bytes32 outputRoot, uint256 l2BlockNumber);
    event DeletionRequested(uint256 indexed transactionId, uint256 indexed outputIndex);

    function COLOSSEUM() external view returns (address);
    function GOVERNOR() external view returns (UpgradeGovernor);
    function transactions(uint256)
        external
        view
        returns (address target, bool executed, uint256 value, bytes memory data);
    function transactionCount() external view returns (uint256);
    function generateTransactionId(
        address _target,
        uint256 _value,
        bytes memory _data
    )
        external
        view
        returns (uint256);
    function clock() external view returns (uint48);
    function version() external view returns (string memory);
    function requestValidation(bytes32 _outputRoot, uint256 _l2BlockNumber, bytes memory _data) external;
    function requestDeletion(uint256 _outputIndex, bool _force) external;

    function __constructor__(address _colosseum, address payable _governor) external;
}
