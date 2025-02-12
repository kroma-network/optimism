// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";

/// @title IAssetManager
/// @notice Interface for AssetManager contract.
interface IAssetManager {
    error ImproperValidatorStatus();
    error InsufficientAsset();
    error InsufficientShare();
    error InvalidTokenIdsInput();
    error NotAllowedCaller();
    error NotAllowedZeroInput();
    error NotElapsedMinDelegationPeriod();
    error ZeroAddress();

    event Deposited(address indexed validator, uint128 amount);
    event KghBatchDelegated(address indexed validator, address indexed delegator, uint256[] tokenIds);
    event KghBatchUndelegated(address indexed validator, address indexed delegator, uint256[] tokenIds, uint128 amount);
    event KghDelegated(address indexed validator, address indexed delegator, uint256 tokenId);
    event KghRewardClaimed(address indexed validator, address indexed delegator, uint128 amount);
    event KghUndelegated(address indexed validator, address indexed delegator, uint256 tokenId, uint128 amount);
    event KroDelegated(address indexed validator, address indexed delegator, uint128 amount, uint128 shares);
    event KroUndelegated(address indexed validator, address indexed delegator, uint128 amount, uint128 shares);
    event ValidatorKroBonded(address indexed validator, uint128 amount, uint128 remainder);
    event ValidatorKroUnbonded(address indexed validator, uint128 amount, uint128 remainder);
    event Withdrawn(address indexed validator, uint128 amount);

    function ASSET_TOKEN() external view returns (IERC20);
    function BOND_AMOUNT() external view returns (uint128);
    function DECIMAL_OFFSET() external view returns (uint128);
    function KGH() external view returns (IERC721);
    function MIN_DELEGATION_PERIOD() external view returns (uint128);
    function SECURITY_COUNCIL() external view returns (address);
    function TAX_DENOMINATOR() external view returns (uint128);
    function TAX_NUMERATOR() external view returns (uint128);
    function VALIDATOR_MANAGER() external view returns (IValidatorManager);
    function VALIDATOR_REWARD_VAULT() external view returns (address);
    function bondValidatorKro(address validator) external;
    function canUndelegateKghAt(
        address validator,
        address delegator,
        uint256 tokenId
    )
        external
        view
        returns (uint128);
    function canUndelegateKroAt(address validator, address delegator) external view returns (uint128);
    function canWithdrawAt(address validator) external view returns (uint128);
    function claimKghReward(address validator) external;
    function decreaseBalanceWithChallenge(address loser) external returns (uint128);
    function delegate(address validator, uint128 assets) external returns (uint128);
    function delegateKgh(address validator, uint256 tokenId) external;
    function delegateKghBatch(address validator, uint256[] memory tokenIds) external;
    function deposit(uint128 assets) external;
    function depositToRegister(address validator, uint128 assets, address withdrawAccount) external;
    function getKghNum(address validator, address delegator) external view returns (uint128);
    function getKghReward(address validator, address delegator) external view returns (uint128);
    function getKroAssets(address validator, address delegator) external view returns (uint128);
    function getKroTotalShareBalance(address validator, address delegator) external view returns (uint128);
    function getWithdrawAccount(address validator) external view returns (address);
    function increaseBalanceWithChallenge(address winner, uint128 challengeReward) external returns (uint128);
    function increaseBalanceWithReward(
        address validator,
        uint128 baseReward,
        uint128 boostedReward,
        uint128 validatorReward
    )
        external;
    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4);
    function previewDelegate(address validator, uint128 assets) external view returns (uint128);
    function previewUndelegate(address validator, uint128 shares) external view returns (uint128);
    function reflectiveWeight(address validator) external view returns (uint128);
    function revertDecreaseBalanceWithChallenge(address loser) external returns (uint128);
    function totalKghNum(address validator) external view returns (uint128);
    function totalKroAssets(address validator) external view returns (uint128);
    function totalValidatorKro(address validator) external view returns (uint128);
    function totalValidatorKroBonded(address validator) external view returns (uint128);
    function totalValidatorKroNotBonded(address validator) external view returns (uint128);
    function unbondValidatorKro(address validator) external;
    function undelegate(address validator, uint128 assets) external;
    function undelegateKgh(address validator, uint256 tokenId) external;
    function undelegateKghBatch(address validator, uint256[] memory tokenIds) external;
    function version() external view returns (string memory);
    function withdraw(address validator, uint128 assets) external;

    function __constructor__(
        IERC20 _assetToken,
        IERC721 _kgh,
        address _securityCouncil,
        address _validatorRewardVault,
        IValidatorManager _validatorManager,
        uint128 _minDelegationPeriod,
        uint128 _bondAmount
    )
        external;
}
