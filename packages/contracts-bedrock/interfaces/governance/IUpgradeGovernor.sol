// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUpgradeGovernor {
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

    error Empty();

    event EIP712DomainChanged();
    event Initialized(uint8 version);
    event ProposalCanceled(uint256 proposalId);
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
    event ProposalExecuted(uint256 proposalId);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);
    event TimelockChange(address oldTimelock, address newTimelock);
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    receive() external payable;

    function BALLOT_TYPEHASH() external view returns (bytes32);
    function CLOCK_MODE() external view returns (string memory);
    function COUNTING_MODE() external pure returns (string memory);
    function EXTENDED_BALLOT_TYPEHASH() external view returns (bytes32);
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        external
        returns (uint256);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (uint256);
    function castVoteWithReason(uint256 proposalId, uint8 support, string memory reason) external returns (uint256);
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        bytes memory params
    )
        external
        returns (uint256);
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        bytes memory params,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (uint256);
    function clock() external view returns (uint48);
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
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        external
        payable
        returns (uint256);
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
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        external
        pure
        returns (uint256);
    function initialize(
        address _token,
        address payable _timelock,
        uint256 _initialVotingDelay,
        uint256 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        uint256 _votesQuorumFraction
    )
        external;
    function name() external view returns (string memory);
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    )
        external
        returns (bytes4);
    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);
    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function proposalEta(uint256 proposalId) external view returns (uint256);
    function proposalProposer(uint256 proposalId) external view returns (address);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function proposalVotes(uint256 proposalId)
        external
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes);
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        external
        returns (uint256);
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        external
        returns (uint256);
    function quorum(uint256 blockNumber) external view returns (uint256);
    function quorumDenominator() external view returns (uint256);
    function quorumNumerator(uint256 timepoint) external view returns (uint256);
    function quorumNumerator() external view returns (uint256);
    function relay(address target, uint256 value, bytes memory data) external payable;
    function setProposalThreshold(uint256 newProposalThreshold) external;
    function setVotingDelay(uint256 newVotingDelay) external;
    function setVotingPeriod(uint256 newVotingPeriod) external;
    function state(uint256 proposalId) external view returns (ProposalState);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function timelock() external view returns (address);
    function token() external view returns (address);
    function updateQuorumNumerator(uint256 newQuorumNumerator) external;
    function updateTimelock(address newTimelock) external;
    function version() external pure returns (string memory);
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);

    function __constructor__() external;
}
