// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Types } from "src/libraries/Types.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { SystemConfig } from "src/L1/SystemConfig.sol";

interface IKromaPortal {
    error ContentLengthMismatch();
    error EmptyItem();
    error InvalidDataRemainder();
    error InvalidHeader();
    error OutOfGas();
    error Unauthorized();
    error UnexpectedList();
    error UnexpectedString();

    event Initialized(uint8 version);
    event Paused(address account);
    event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData);
    event Unpaused(address account);
    event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success);
    event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to);

    receive() external payable;

    function GUARDIAN() external view returns (address);
    function L2_ORACLE() external view returns (L2OutputOracle);
    function SYSTEM_CONFIG() external view returns (SystemConfig);
    function depositTransaction(
        address _to,
        uint256 _value,
        uint64 _gasLimit,
        bool _isCreation,
        bytes memory _data
    )
        external
        payable;
    function finalizeWithdrawalTransaction(Types.WithdrawalTransaction memory _tx) external;
    function finalizedWithdrawals(bytes32) external view returns (bool);
    function initialize(bool _paused) external;
    function isOutputFinalized(uint256 _l2OutputIndex) external view returns (bool);
    function l2Sender() external view returns (address);
    function params() external view returns (uint128 prevBaseFee, uint64 prevBoughtGas, uint64 prevBlockNum);
    function pause() external;
    function paused() external view returns (bool);
    function proveWithdrawalTransaction(
        Types.WithdrawalTransaction memory _tx,
        uint256 _l2OutputIndex,
        Types.OutputRootProof memory _outputRootProof,
        bytes[] memory _withdrawalProof
    )
        external;
    function provenWithdrawals(bytes32)
        external
        view
        returns (bytes32 outputRoot, uint128 timestamp, uint128 l2OutputIndex);
    function setGasPayingToken(address _token, uint8 _decimals, bytes32 _name, bytes32 _symbol) external;
    function unpause() external;
    function version() external view returns (string memory);

    function __constructor__(
        L2OutputOracle _l2Oracle,
        address _guardian,
        bool _paused,
        SystemConfig _config
    )
        external;
}
