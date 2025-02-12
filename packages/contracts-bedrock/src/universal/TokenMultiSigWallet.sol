// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Contracts
import "@openzeppelin/contracts-upgradeable-v4.9.3/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-v4.9.3/utils/math/SafeCastUpgradeable.sol";
import { UpgradeGovernor } from "src/governance/UpgradeGovernor.sol";

// Libraries
import { SafeCall } from "src/libraries/SafeCall.sol";
import { KromaTypes } from "src/libraries/KromaTypes.sol";

// Interfaces
import "@openzeppelin/contracts-upgradeable-v4.9.3/interfaces/IERC5805Upgradeable.sol";

/// @custom:upgradeable
/// @title TokenMultiSigWallet
/// @notice This contract implements `ITokenMultiSigWallet`.
///         Allows multiple parties to agree on transactions before execution.
abstract contract TokenMultiSigWallet is ReentrancyGuardUpgradeable {
    /// @notice Emitted when anyone submit a transaction.
    /// @param sender        Address of submitter.
    /// @param transactionId The ID of transaction submitted.
    event TransactionSubmitted(address indexed sender, uint256 indexed transactionId);

    /// @notice Emitted when anyone confirm a transaction.
    /// @param sender        Owner of address that confirm a transaction.
    /// @param transactionId The ID of transaction confirmed.
    event TransactionConfirmed(address indexed sender, uint256 indexed transactionId);

    /// @notice Emitted when transaction is executed.
    /// @param sender        Owner of address that execute a transaction.
    /// @param transactionId The ID of transaction executed.
    event TransactionExecuted(address indexed sender, uint256 indexed transactionId);

    /// @notice Emitted when anyone revoke a confirmation.
    /// @param sender        Owner of address that revoke a transaction.
    /// @param transactionId The ID of transaction to revoke.
    event ConfirmationRevoked(address indexed sender, uint256 indexed transactionId);

    /// @notice The address of the governor contract. Can be updated via upgrade.
    UpgradeGovernor public immutable GOVERNOR;

    /// @notice A mapping of transactions submitted.
    mapping(uint256 => KromaTypes.MultiSigTransaction) public transactions;

    /// @notice A mapping of confirmations.
    mapping(uint256 => KromaTypes.MultiSigConfirmation) public confirmations;

    /// @notice Spacer for backwards compatibility.
    uint256[3] private spacer_53_0_96;

    /// @notice The number of transactions submitted.
    uint256 public transactionCount;

    /// @notice Only allow the owner of governance token to call the functions.
    ///         This ensures that function is only executed by governance.
    modifier onlyTokenOwner(address _address) {
        require(getVotes(_address) > 0, "TokenMultiSigWallet: only allowed to governance token owner");
        _;
    }

    /// @notice Ensure that the transaction exists.
    /// @param _transactionId The ID of submitted transaction requested.
    modifier transactionExists(uint256 _transactionId) {
        require(transactions[_transactionId].target != address(0), "TokenMultiSigWallet: transaction does not exist");
        _;
    }

    /// @notice Ensure that the transaction not exceuted.
    /// @param _transactionId The ID of transaction to check.
    modifier transactionNotExcuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed, "TokenMultiSigWallet: already executed");
        _;
    }

    /// @notice Ensure that the address is not zero address.
    /// @param _address Address resource requested.
    modifier validAddress(address _address) {
        require(_address != address(0), "TokenMultiSigWallet: address is not valid");
        _;
    }

    /// @param _governor Address of the Governor contract.
    constructor(address payable _governor) {
        GOVERNOR = UpgradeGovernor(_governor);
    }

    /// @notice Allows an owner to submit and confirm a transaction.
    /// @param _target Transaction target address.
    /// @param _value  Transaction ether value.
    /// @param _data   Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(
        address _target,
        uint256 _value,
        bytes memory _data
    )
        public
        onlyTokenOwner(msg.sender)
        returns (uint256)
    {
        return _submitTransaction(_target, _value, _data);
    }

    function _submitTransaction(
        address _target,
        uint256 _value,
        bytes memory _data
    )
        internal
        validAddress(_target)
        returns (uint256)
    {
        uint256 transactionId = generateTransactionId(_target, _value, _data);
        require(transactions[transactionId].target == address(0), "TokenMultiSigWallet: transaction already exists");

        transactions[transactionId] =
            KromaTypes.MultiSigTransaction({ target: _target, value: _value, data: _data, executed: false });

        unchecked {
            ++transactionCount;
        }

        emit TransactionSubmitted(msg.sender, transactionId);
        return transactionId;
    }

    /// @notice Allows an owner to confirm a transaction.
    /// @param _transactionId Transaction ID.
    function confirmTransaction(uint256 _transactionId)
        public
        onlyTokenOwner(msg.sender)
        transactionExists(_transactionId)
    {
        KromaTypes.MultiSigConfirmation storage confirms = confirmations[_transactionId];
        require(!confirms.confirmedBy[msg.sender], "TokenMultiSigWallet: already confirmed");
        confirms.confirmedBy[msg.sender] = true;
        confirms.confirmationCount += getVotes(msg.sender);
        emit TransactionConfirmed(msg.sender, _transactionId);

        // execute transaction if condition is met.
        if (confirmations[_transactionId].confirmationCount >= quorum()) {
            executeTransaction(_transactionId);
        }
    }

    /// @notice Allows an owner to revoke a transaction.
    /// @param _transactionId Transaction ID.
    function revokeConfirmation(uint256 _transactionId)
        public
        onlyTokenOwner(msg.sender)
        transactionExists(_transactionId)
        transactionNotExcuted(_transactionId)
    {
        require(isConfirmedBy(_transactionId, msg.sender), "TokenMultiSigWallet: not confirmed yet");

        KromaTypes.MultiSigConfirmation storage confirms = confirmations[_transactionId];
        confirms.confirmedBy[msg.sender] = false;
        confirms.confirmationCount -= getVotes(msg.sender);
        emit ConfirmationRevoked(msg.sender, _transactionId);
    }

    /// @notice Allows anyone to execute a confirmed transaction.
    /// @param _transactionId Transaction ID.
    function executeTransaction(uint256 _transactionId)
        public
        nonReentrant
        transactionExists(_transactionId)
        transactionNotExcuted(_transactionId)
    {
        require(isConfirmed(_transactionId), "TokenMultiSigWallet: quorum not reached");

        KromaTypes.MultiSigTransaction storage txn = transactions[_transactionId];
        txn.executed = true;
        bool success = SafeCall.call(txn.target, gasleft(), txn.value, txn.data);
        require(success, "TokenMultiSigWallet: call transaction failed");
        emit TransactionExecuted(msg.sender, _transactionId);
    }

    /// @notice Returns the confirmation status of a transaction.
    /// @param _transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint256 _transactionId) public view returns (bool) {
        return confirmations[_transactionId].confirmationCount >= quorum();
    }

    /// @notice Returns the current quorum, in terms of number of votes.
    /// @return Current quorum, in terms of number of votes: `supply * quorumNumerator / quorumDenominator`.
    function quorum() public view returns (uint256) {
        uint256 currentTimepoint = clock() - 1;
        return (
            IERC5805Upgradeable(address(GOVERNOR.token())).getPastTotalSupply(currentTimepoint)
                * GOVERNOR.quorumNumerator(currentTimepoint)
        ) / GOVERNOR.quorumDenominator();
    }

    /// @notice Returns the number of votes.
    /// @param account Account to check votes.
    /// @return Number of votes.
    function getVotes(address account) public view returns (uint256) {
        return IERC5805Upgradeable(address(GOVERNOR.token())).getVotes(account);
    }

    /// @notice Returns whether the account has confirmed the transaction.
    /// @param _transactionId Transaction id to check.
    /// @param _account       Address to check.
    /// @return Confirmed status.
    function isConfirmedBy(uint256 _transactionId, address _account) public view returns (bool) {
        return confirmations[_transactionId].confirmedBy[_account];
    }

    /// @notice Returns the number of confirmations that account has confirmed.
    /// @param _transactionId Transaction id to check.
    /// @return The number of confirmations.
    function getConfirmationCount(uint256 _transactionId) public view returns (uint256) {
        return confirmations[_transactionId].confirmationCount;
    }

    /// @notice Generate id of the transaction.
    /// @param _target Transaction target address.
    /// @param _value  Transaction ether value.
    /// @param _data   Transaction data payload.
    /// @return Generated transaction id.
    function generateTransactionId(
        address _target,
        uint256 _value,
        bytes memory _data
    )
        public
        view
        validAddress(_target)
        returns (uint256)
    {
        return uint256(keccak256(abi.encode(_target, _value, _data, clock())));
    }

    /// @dev Clock (as specified in EIP-6372) is set to match the token's clock.
    ///      Fallback to block numbers if the token does not implement EIP-6372.
    function clock() public view returns (uint48) {
        try IERC5805Upgradeable(address(GOVERNOR.token())).clock() returns (uint48 timepoint) {
            return timepoint;
        } catch {
            return SafeCastUpgradeable.toUint48(block.number);
        }
    }
}
