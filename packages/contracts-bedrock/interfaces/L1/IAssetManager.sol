// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IValidatorManager } from "interfaces/L1/IValidatorManager.sol";

/// @title IAssetManager
/// @notice Interface for AssetManager contract.
interface IAssetManager {
    function TAX_NUMERATOR() external view returns (uint128);
    function TAX_DENOMINATOR() external view returns (uint128);
    function DECIMAL_OFFSET() external view returns (uint128);
    function ASSET_TOKEN() external view returns (IERC20);
    function KGH() external view returns (IERC721);
    function SECURITY_COUNCIL() external view returns (address);
    function VALIDATOR_REWARD_VAULT() external view returns (address);
    function VALIDATOR_MANAGER() external view returns (IValidatorManager);
    function MIN_DELEGATION_PERIOD() external view returns (uint128);
    function BOND_AMOUNT() external view returns (uint128);

    struct Asset {
        uint128 validatorKro;
        uint128 validatorKroBonded;
        uint128 totalKro;
        uint128 totalKroShares;
        uint128 totalKgh;
        uint128 rewardPerKghStored;
    }

    struct KroDelegator {
        uint128 shares;
        uint128 lastDelegatedAt;
    }

    struct KghDelegator {
        uint128 rewardPerKghPaid;
        uint128 kghNum;
        mapping(uint256 => uint128) delegatedAt;
    }

    struct Vault {
        address withdrawAccount;
        uint128 lastDepositedAt;
        Asset asset;
        mapping(address => KroDelegator) kroDelegators;
        mapping(address => KghDelegator) kghDelegators;
    }

    event Deposited(address indexed validator, uint128 amount);
    event KroDelegated(address indexed validator, address indexed delegator, uint128 amount, uint128 shares);
    event KghDelegated(address indexed validator, address indexed delegator, uint256 tokenId);
    event KghBatchDelegated(address indexed validator, address indexed delegator, uint256[] tokenIds);
    event Withdrawn(address indexed validator, uint128 amount);
    event KroUndelegated(address indexed validator, address indexed delegator, uint128 amount, uint128 shares);
    event KghUndelegated(address indexed validator, address indexed delegator, uint256 tokenId, uint128 amount);
    event KghBatchUndelegated(address indexed validator, address indexed delegator, uint256[] tokenIds, uint128 amount);
    event KghRewardClaimed(address indexed validator, address indexed delegator, uint128 amount);
    event ValidatorKroBonded(address indexed validator, uint128 amount, uint128 remainder);
    event ValidatorKroUnbonded(address indexed validator, uint128 amount, uint128 remainder);

    error NotAllowedCaller();
    error ImproperValidatorStatus();
    error NotAllowedZeroInput();
    error ZeroAddress();
    error InsufficientAsset();
    error InsufficientShare();
    error NotElapsedMinDelegationPeriod();
    error InvalidTokenIdsInput();

    function getWithdrawAccount(address validator) external view returns (address);
    function canWithdrawAt(address validator) external view returns (uint128);
    function totalValidatorKro(address validator) external view returns (uint128);
    function totalValidatorKroBonded(address validator) external view returns (uint128);
    function totalValidatorKroNotBonded(address validator) external view returns (uint128);
    function totalKroAssets(address validator) external view returns (uint128);
    function totalKghNum(address validator) external view returns (uint128);
    function getKroTotalShareBalance(address validator, address delegator) external view returns (uint128);
    function getKroAssets(address validator, address delegator) external view returns (uint128);
    function canUndelegateKroAt(address validator, address delegator) external view returns (uint128);
    function getKghNum(address validator, address delegator) external view returns (uint128);
    function canUndelegateKghAt(
        address validator,
        address delegator,
        uint256 tokenId
    )
        external
        view
        returns (uint128);
    function previewDelegate(address validator, uint128 assets) external view returns (uint128);
    function previewUndelegate(address validator, uint128 shares) external view returns (uint128);
    function getKghReward(address validator, address delegator) external view returns (uint128);
    function deposit(uint128 assets) external;
    function withdraw(address validator, uint128 assets) external;
    function delegate(address validator, uint128 assets) external returns (uint128);
    function delegateKgh(address validator, uint256 tokenId) external;
    function delegateKghBatch(address validator, uint256[] calldata tokenIds) external;
    function undelegate(address validator, uint128 assets) external;
    function undelegateKgh(address validator, uint256 tokenId) external;
    function undelegateKghBatch(address validator, uint256[] calldata tokenIds) external;
    function claimKghReward(address validator) external;

    function version() external view returns (string memory);
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
