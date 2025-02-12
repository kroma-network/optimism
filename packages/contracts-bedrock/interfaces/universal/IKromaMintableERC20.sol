// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IKromaMintableERC20
/// @notice This interface is available on the KromaMintableERC20 contract. We declare it as a
///         separate interface so that it can be used in custom implementations of
///         KromaMintableERC20.
interface IKromaMintableERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed account, uint256 amount);
    event Mint(address indexed account, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function BRIDGE() external view returns (address);
    function REMOTE_TOKEN() external view returns (address);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function burn(address _from, uint256 _amount) external;
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function mint(address _to, uint256 _amount) external;
    function name() external view returns (string memory);
    function supportsInterface(bytes4 _interfaceId) external pure returns (bool);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function version() external view returns (string memory);

    function __constructor__(
        address _bridge,
        address _remoteToken,
        string memory _name,
        string memory _symbol
    )
        external;
}
