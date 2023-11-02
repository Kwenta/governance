// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

interface IElectionModule {
	/*///////////////////////////////////////////////////////////////
                        		STRUCTS/ENUMS
  ///////////////////////////////////////////////////////////////*/
	enum ElectionType {
		Scheduled,
		Community,
		Replacement
	}

	enum ElectionStatus {
		Invalid,
		Ongoing,
		Finalized
	}

	struct Election {
		uint256 startTime;
		uint256 totalVotes;
		ElectionStatus status;
		ElectionType electionType;
		EnumerableSet.AddressSet candidates;
		EnumerableSet.AddressSet winners;
		mapping(address => uint256) voteCounts;
		mapping(address => bool) hasVoted;
	}

	/*///////////////////////////////////////////////////////////////
                          	VIEW FUNCTIONS
	///////////////////////////////////////////////////////////////*/

	/// @notice returns the start time of an election
	/// @param _electionId the election ID
	function getElectionStartTime(uint256 _electionId) external view returns (uint256);

	/// @notice returns the end time of an election
	/// @param _electionId the election ID
	function getElectionEndTime(uint256 _electionId) external view returns (uint256);

	/// @notice returns the total votes of an election
	/// @param _electionId the election ID
	function getElectionTotalVotes(uint256 _electionId) external view returns (uint256);

	/// @notice returns the status of an election
	/// @param _electionId the election ID
	function getElectionStatus(uint256 _electionId) external view returns (ElectionStatus);

	/// @notice returns the type of an election
	/// @param _electionId the election ID
	function getElectionType(uint256 _electionId) external view returns (ElectionType);

	/// @notice returns the address of a candidate for an election
	/// @param _electionId the election ID
	/// @param _index the index of the candidate
	function getElectionCandidateAddress(uint256 _electionId, uint256 _index) external view returns (address);

	/// @notice checks if an address is a candidate for an election
	/// @param _electionId the election ID
	/// @param _candidate the address of the candidate
	function isElectionCandidate(uint256 _electionId, address _candidate) external view returns (bool);

	/// @notice returns an array with all the winners for an election
	/// @param _electionId the election ID
	function getElectionWinners(uint256 _electionId) external view returns (address[] memory);

	/// @notice checks if an address won an election
	/// @param _electionId the election ID
	/// @param _candidate the address of the candidate
	function isElectionWinner(uint256 _electionId, address _candidate) external view returns (bool);

	/// @notice returns a candidate's total votes for an election
	/// @param _electionId the election ID
	/// @param _candidate the address of the candidate
	function getElectionVotesForCandidate(uint256 _electionId, address _candidate) external view returns (uint256);

	/// @notice checks if an address has voted for an election
	/// @param _electionId the election ID
	/// @param _voter the address of the voter
	function hasVoted(uint256 _electionId, address _voter) external view returns (bool);

	/// @notice checks if a scheduled election can be started or not
	function canStartScheduledElection() external view returns (bool);

	/// @notice checks if the current election is in the voting window
	function hasOngoingElection() external view returns (bool);

	/*///////////////////////////////////////////////////////////////
                          MUTATIVE FUNCTIONS
	///////////////////////////////////////////////////////////////*/

	/// @notice starts a scheduled election
	function startScheduledElection() external;

	/// @notice starts a community election
	function startCommunityElection() external;

	/// @notice removes a specified member from council and starts a replacement election
	/// @param _councilMember the address of the member to be replaced
	function startReplacementElection(address _councilMember) external;

	/// @notice removes caller from council and starts a replacement election
	function stepDownFromCouncil() external;

	/// @notice starts a single seat election
	function startSingleSeatElection() external;

	/// @notice nominates a candidate for the current election
	/// @param _candidate the address of the candidate
	function nominateCandidate(address _candidate) external;

	/// @notice nominates multiple candidates for the current election
	/// @param _candidates an array of candidate addresses
	function nominateMultipleCandidates(address[] calldata _candidates) external;

	/// @notice casts a vote for a candidate in the current election
	/// @param _candidate the address of the candidate
	function vote(address _candidate) external;

	/// @notice finalizes an election and its results
	function finalizeElection() external;

	/// @notice cancels an election (when it can be cancelled)
	function cancelElection() external;

	/// @notice sets the quorum threshold (eg: 40%)
	function setQuorumThreshold(uint256 _newThreshold) external;

	/*///////////////////////////////////////////////////////////////
                        				EVENTS
  ///////////////////////////////////////////////////////////////*/

	/// @notice emitted when an election is started
	/// @param electionId: the election ID
	/// @param electionType: the type of election
	event ElectionStarted(uint256 indexed electionId, ElectionType indexed electionType);

	/// @notice emitted when an election is canceled
	/// @param electionId: the election ID
	event ElectionCanceled(uint256 indexed electionId);

	/// @notice emitted when a candidate is nominated for an election
	/// @param electionId: the election ID
	/// @param candidate: the address of the candidate
	event CandidateNominated(uint256 indexed electionId, address indexed candidate);

	/// @notice emitted when a vote has been made
	/// @param electionId: the election ID
	/// @param voter: the address of the voter
	/// @param candidate: the address of the candidate
	event VoteRecorded(uint256 indexed electionId, address indexed voter, address candidate);

	/// @notice emitted when an election has been finalized
	/// @param electionId: the election ID
	event ElectionFinalized(uint256 indexed electionId);

	/// @notice emitted when the quorum threshold has been updated
	/// @param oldThreshold: the previous threshold
	/// @param newThreshold: the new threshold
	event QuorumThresholdSet(uint256 oldThreshold, uint256 newThreshold);
}
