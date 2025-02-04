// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721ReceiverUpgradeable } from
    "@openzeppelin/contracts-upgradeable-v4.9.3/token/ERC721/IERC721ReceiverUpgradeable.sol";
import { IERC1155ReceiverUpgradeable } from
    "@openzeppelin/contracts-upgradeable-v4.9.3/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import { IVotesUpgradeable } from "@openzeppelin/contracts-upgradeable-v4.9.3/governance/utils/IVotesUpgradeable.sol";
import { TimelockControllerUpgradeable } from
    "@openzeppelin/contracts-upgradeable-v4.9.3/governance/TimelockControllerUpgradeable.sol";

interface IUpgradeGovernor is IERC721ReceiverUpgradeable, IERC1155ReceiverUpgradeable, IVotesUpgradeable {
    /// @notice Enum from imported OZ contracts.
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
    enum VoteType {
        Against,
        For,
        Abstain
    }

    /// @notice Struct from imported OZ contracts.
    struct ProposalVote {
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        mapping(address => bool) hasVoted;
    }
    // solhint-disable var-name-mixedcase

    struct ProposalCore {
        uint64 voteStart;
        address proposer;
        bytes4 __gap_unused0;
        uint64 voteEnd;
        bytes24 __gap_unused1;
        bool executed;
        bool canceled;
    }

    /// @notice Events from imported OZ contracts.
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);
    event TimelockChange(address oldTimelock, address newTimelock);

    /// @notice Functions from imported OZ contracts.
    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function clock() external view returns (uint48);
    function CLOCK_MODE() external view returns (string memory);
    function COUNTING_MODE() external view returns (string memory);
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        external
        pure
        returns (uint256);
    function state(uint256 proposalId) external view returns (ProposalState);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function proposalProposer(uint256 proposalId) external view returns (address);
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function quorum(uint256 timepoint) external view returns (uint256);
    function getVotes(address account, uint256 timepoint) external view returns (uint256);
    function getVotesWithParams(
        address account,
        uint256 timepoint,
        bytes memory params
    )
        external
        view
        returns (uint256);
    function hasVoted(uint256 proposalId, address account) external view returns (bool);
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        external
        returns (uint256 proposalId);
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        external
        payable
        returns (uint256 proposalId);
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        external
        returns (uint256 proposalId);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance);
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    )
        external
        returns (uint256 balance);
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    )
        external
        returns (uint256 balance);
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (uint256 balance);
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (uint256 balance);
    function BALLOT_TYPEHASH() external view returns (bytes32);
    function EXTENDED_BALLOT_TYPEHASH() external view returns (bytes32);
    function proposalThreshold() external view returns (uint256);
    function relay(address target, uint256 value, bytes calldata data) external;
    function setVotingDelay(uint256 newVotingDelay) external;
    function setVotingPeriod(uint256 newVotingPeriod) external;
    function setProposalThreshold(uint256 newProposalThreshold) external;
    function proposalVotes(uint256 proposalId)
        external
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes);
    function token() external view returns (IVotesUpgradeable);
    function quorumNumerator() external view returns (uint256);
    function quorumNumerator(uint256 blockNumber) external view returns (uint256);
    function quorumDenominator() external view returns (uint256);
    function updateQuorumNumerator(uint256 newQuorumNumerator) external;
    function timelock() external view returns (address);
    function updateTimelock(TimelockControllerUpgradeable newTimelock) external;

    /// @notice Functions from UpgradeGovernor.sol.
    function initialize(
        address _token,
        address payable _timelock,
        uint256 _initialVotingDelay,
        uint256 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        uint256 _votesQuorumFraction
    )
        external;
    function __constructor__() external;
}
