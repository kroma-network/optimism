// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IAccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable-v4.9.3/access/IAccessControlUpgradeable.sol";
import { IERC721ReceiverUpgradeable } from
    "@openzeppelin/contracts-upgradeable-v4.9.3/token/ERC721/IERC721ReceiverUpgradeable.sol";
import { IERC1155ReceiverUpgradeable } from
    "@openzeppelin/contracts-upgradeable-v4.9.3/token/ERC1155/IERC1155ReceiverUpgradeable.sol";

interface ITimeLock is IAccessControlUpgradeable {
    /// @notice Struct from imported OZ contracts.
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    /// @notice Events from imported OZ contracts.
    event Initialized(uint8 version);
    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );
    event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);
    event CallSalt(bytes32 indexed id, bytes32 salt);
    event Cancelled(bytes32 indexed id);
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    /// @notice Functions from imported OZ contracts.
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;

    function TIMELOCK_ADMIN_ROLE() external view returns (bytes32);
    function PROPOSER_ROLE() external view returns (bytes32);
    function EXECUTOR_ROLE() external view returns (bytes32);
    function CANCELLER_ROLE() external view returns (bytes32);
    function isOperation(bytes32 id) external view returns (bool);
    function isOperationPending(bytes32 id) external view returns (bool);
    function isOperationReady(bytes32 id) external view returns (bool);
    function isOperationDone(bytes32 id) external view returns (bool);
    function getTimestamp(bytes32 id) external view returns (uint256);
    function getMinDelay() external view returns (uint256);
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    )
        external
        pure
        returns (bytes32);
    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    )
        external
        pure
        returns (bytes32);
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    )
        external;
    function cancel(bytes32 id) external;
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    )
        external
        payable;
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    )
        external;
    function updateDelay(uint256 newDelay) external;

    /// @notice Functions from Timelock.sol.
    function initialize(
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors,
        address _admin
    )
        external;
    function version() external view returns (string memory);

    function __constructor__() external;
}
