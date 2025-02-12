// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISecurityCouncilToken {
    error ErrLocked();
    error ErrNotFound();

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event EIP712DomainChanged();
    event Initialized(uint8 version);
    event Locked(uint256 tokenId);
    event MetadataUpdate(uint256 _tokenId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Unlocked(uint256 tokenId);
    event Unpaused(address account);

    function CLOCK_MODE() external view returns (string memory);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function approve(address approved, uint256 tokenId) external;
    function balanceOf(address owner) external view returns (uint256);
    function burn(uint256 tokenId) external;
    function clock() external view returns (uint48);
    function delegate(address delegatee) external;
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
    function delegates(address account) external view returns (address);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function getApproved(uint256 tokenId) external view returns (address);
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function getVotes(address account) external view returns (uint256);
    function initialize(address _owner) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function locked(uint256 tokenId) external view returns (bool);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function owner() external view returns (address);
    function ownerOf(uint256 tokenId) external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function renounceOwnership() external;
    function safeMint(address to, string memory uri) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;
    function setApprovalForAll(address operator, bool approved) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function tokenByIndex(uint256 index) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function transferOwnership(address newOwner) external;
    function unpause() external;
    function version() external view returns (string memory);

    function __constructor__() external;
}
