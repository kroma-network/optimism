// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC5192 } from "src/universal/KromaSoulBoundERC721.sol";
import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable-v4.9.3/token/ERC721/IERC721Upgradeable.sol";
import { IERC721EnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable-v4.9.3/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import { IERC4906Upgradeable } from "@openzeppelin/contracts-upgradeable-v4.9.3/interfaces/IERC4906Upgradeable.sol";
import { IERC5267Upgradeable } from "@openzeppelin/contracts-upgradeable-v4.9.3/interfaces/IERC5267Upgradeable.sol";

interface ISecurityCouncilToken is
    IERC5192,
    IERC721Upgradeable,
    IERC721EnumerableUpgradeable,
    IERC4906Upgradeable,
    IERC5267Upgradeable
{
    /// @notice Events from imported OZ contracts.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Initialized(uint8 version);
    event Paused(address account);
    event Unpaused(address account);

    /// @notice Functions from imported OZ contracts.
    function owner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function initialize(address _owner) external;
    function paused() external view returns (bool);
    function clock() external view returns (uint48);
    function CLOCK_MODE() external view returns (string memory);
    function getVotes(address account) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);
    function delegates(address account) external view returns (address);
    function delegate(address delegatee) external;
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Functions from SecurityCouncilToken.sol.
    function pause() external;
    function unpause() external;
    function safeMint(address to, string memory uri) external;
    function burn(uint256 tokenId) external;
    function locked(uint256 tokenId) external view returns (bool);

    function version() external view returns (string memory);
    function __constructor__() external;
}
