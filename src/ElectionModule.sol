// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CouncilGovernor } from "src/CouncilGovernor.sol";

import { IStakingRewardsV2 } from "src/interfaces/IStakingRewardsV2.sol";
import { IElectionModule } from "src/interfaces/IElectionModule.sol";

import { Error } from "src/libraries/Error.sol";

import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

contract ElectionModule is CouncilGovernor, IElectionModule {
	using EnumerableSet for EnumerableSet.AddressSet;

	/*///////////////////////////////////////////////////////////////
                              CONSTANTS
  ///////////////////////////////////////////////////////////////*/

	uint256 public constant EPOCH_LENGTH = 26 weeks;
	uint256 public constant NOMINATION_WINDOW = 1 weeks;
	uint256 public constant ELECTION_DURATION = 3 weeks;
	uint256 public constant SEATS_FULL_ELECTION = 5;
	uint256 public constant SEATS_REPLACEMENT_ELECTION = 1;

	/*///////////////////////////////////////////////////////////////
                              	STATE
  ///////////////////////////////////////////////////////////////*/

	/// @notice start time for the elections
	uint256 public startTime;

	/// @notice mapping of election number to election
	mapping(uint256 => Election) private elections;
	uint256 public currentElection;
	uint256 public lastFinalizedScheduledElection;

	uint256 public quorumThreshold = 40;

	// /// @notice tracker for timestamp start of last scheduled election
	// uint256 public lastScheduledElectionStartTime;

	/// @notice staking rewards V2 contract
	IStakingRewardsV2 public immutable stakingRewardsV2;

	/*///////////////////////////////////////////////////////////////
                             CONSTRUCTOR
  ///////////////////////////////////////////////////////////////*/

	constructor(address _stakingRewardsV2, address _safeProxy, uint256 _startTime) CouncilGovernor(_safeProxy) {
		if (_stakingRewardsV2 == address(0)) revert Error.ZeroAddress();
		stakingRewardsV2 = IStakingRewardsV2(_stakingRewardsV2);
		startTime = _startTime;
	}

	/*///////////////////////////////////////////////////////////////
                              VIEWS
  ///////////////////////////////////////////////////////////////*/

	function isNominationWindow() public view returns (bool) {
		return
			block.timestamp >= elections[currentElection].startTime &&
			block.timestamp < elections[currentElection].startTime + NOMINATION_WINDOW;
	}

	function isVotingWindow() public view returns (bool) {
		return
			hasOngoingElection() &&
			block.timestamp >= elections[currentElection].startTime + NOMINATION_WINDOW &&
			block.timestamp < elections[currentElection].startTime + ELECTION_DURATION;
	}

	function getElectionStartTime(uint256 _electionId) public view returns (uint256) {
		return elections[_electionId].startTime;
	}

	function getElectionEndTime(uint256 _electionId) public view returns (uint256) {
		return elections[_electionId].startTime + ELECTION_DURATION;
	}

	function getElectionTotalVotes(uint256 _electionId) public view returns (uint256) {
		return elections[_electionId].totalVotes;
	}

	function getElectionStatus(uint256 _electionId) public view returns (ElectionStatus) {
		return elections[_electionId].status;
	}

	function getElectionType(uint256 _electionId) public view returns (ElectionType) {
		return elections[_electionId].electionType;
	}

	function getElectionCandidateAddress(uint256 _electionId, uint256 _index) public view returns (address) {
		return elections[_electionId].candidates.at(_index);
	}

	function isElectionCandidate(uint256 _electionId, address _candidate) public view returns (bool) {
		return elections[_electionId].candidates.contains(_candidate);
	}

	function getElectionWinners(uint256 _electionId) public view returns (address[] memory) {
		EnumerableSet.AddressSet storage electionWinners = elections[_electionId].winners;
		address[] memory winnersArray = new address[](electionWinners.length());
		for (uint i = 0; i < electionWinners.length(); ++i) {
			winnersArray[i] = electionWinners.at(i);
		}
		return winnersArray;
	}

	function isElectionWinner(uint256 _electionId, address _candidate) public view returns (bool) {
		return elections[_electionId].winners.contains(_candidate);
	}

	function getElectionVotesForCandidate(uint256 _electionId, address _candidate) public view returns (uint256) {
		return elections[_electionId].voteCounts[_candidate];
	}

	function hasVoted(uint256 _electionId, address _voter) public view returns (bool) {
		return elections[_electionId].hasVoted[_voter];
	}

	function isElectionFinalized() public view returns (bool) {
		return
			elections[currentElection].status == ElectionStatus.Finalized ||
			elections[currentElection].status == ElectionStatus.Invalid;
	}

	function isElectionCancelable() public view returns (bool) {
		/// @dev an election can be cancelled if it has the Ongoing status AND
		/// if nomination window ended with not enough candidates OR
		/// voting window ended with not enough winners
		uint256 seatsNumber = getAvailableSeatsForElection(elections[currentElection].electionType);
		if (
			elections[currentElection].status == ElectionStatus.Ongoing &&
			((isVotingWindow() && elections[currentElection].candidates.length() < seatsNumber) ||
				(block.timestamp > getElectionEndTime(currentElection) &&
					elections[currentElection].winners.length() < seatsNumber))
		) {
			return true;
		} else return false;
	}

	function hasOngoingElection() public view returns (bool) {
		return elections[currentElection].status == ElectionStatus.Ongoing;
	}

	function hasOngoingScheduledElection() public view returns (bool) {
		return hasOngoingElection() && elections[currentElection].electionType == ElectionType.Scheduled;
	}

	/// @dev a scheduled election can only be started if:
	/// block.timestamp >= startTime AND
	/// there is not another ongoing scheduled election AND
	/// last finalized scheduled election was more than 6 months ago
	function canStartScheduledElection() public view returns (bool) {
		if (block.timestamp < startTime) return false;
		if (hasOngoingScheduledElection()) return false;
		if (
			lastFinalizedScheduledElection > 0 &&
			block.timestamp < elections[lastFinalizedScheduledElection].startTime + EPOCH_LENGTH
		) return false;
		return true;
	}

	function getAvailableSeatsForElection(ElectionType _electionType) public pure returns (uint256) {
		return _electionType == ElectionType.Replacement ? SEATS_REPLACEMENT_ELECTION : SEATS_FULL_ELECTION;
	}

	function getQuorum(uint256 _timestamp) public view returns (uint256) {
		return (stakingRewardsV2.totalSupplyAtTime(_timestamp) * quorumThreshold) / 100;
	}

	/*///////////////////////////////////////////////////////////////
                        MUTATIVE FUNCTIONS
  ///////////////////////////////////////////////////////////////*/

	function startScheduledElection() external {
		if (!canStartScheduledElection()) revert Error.ElectionCannotStart();
		if (hasOngoingElection()) {
			_cancelElection();
		}
		_startElection(ElectionType.Scheduled);
	}

	function startCommunityElection() external noElectionOngoing {
		if (stakingRewardsV2.balanceOf(msg.sender) == 0) revert Error.CallerIsNotStaking();
		_startElection(ElectionType.Community);
	}

	function startReplacementElection(address _councilMember) external safeOnly {
		_startReplacementElection(_councilMember);
	}

	function stepDownFromCouncil() external {
		_startReplacementElection(msg.sender);
	}

	/// @dev this function can be called after a replacement election occured before but
	/// ended up being invalid (no candidates or votes). To avoid multisig desertion,
	/// we cannot start another replacement election until the current available seat has been filled.
	function startSingleSeatElection() external noElectionOngoing {
		if (_getOwners().length == COUNCIL_SEATS_NUMBER) revert Error.NoSeatAvailableInCouncil();
		_startElection(ElectionType.Replacement);
	}

	function nominateCandidate(address _candidate) external {
		_nominateCandidate(_candidate);
	}

	function nominateMultipleCandidates(address[] calldata candidates) external {
		for (uint256 i = 0; i < candidates.length; ) {
			_nominateCandidate(candidates[i]);
			unchecked {
				++i;
			}
		}
	}

	function vote(address _candidate) external {
		if (!isVotingWindow()) revert Error.NotInVotingWindow();

		Election storage election = elections[currentElection];

		if (election.hasVoted[msg.sender]) revert Error.AlreadyVoted();
		if (!election.candidates.contains(_candidate)) revert Error.CandidateNotNominated();

		uint256 votingPower = stakingRewardsV2.balanceAtTime(msg.sender, election.startTime);
		if (votingPower == 0) revert Error.CallerIsNotStaking();

		emit VoteRecorded(currentElection, msg.sender, _candidate);

		election.hasVoted[msg.sender] = true;
		election.voteCounts[_candidate] += votingPower;
		election.totalVotes += votingPower;

		_updateWinnerList(election, _candidate);
	}

	function finalizeElection() external {
		if (isElectionFinalized()) revert Error.ElectionFinalizedOrInvalid();
		if (block.timestamp < getElectionEndTime(currentElection)) revert Error.ElectionNotReadyToBeFinalized();

		Election storage election = elections[currentElection];

		/// @dev if there are no votes, or if quorum isn't met for a Community Election then the election is invalid and needs to be canceled
		uint256 seatsNumber = getAvailableSeatsForElection(election.electionType);
		if (
			election.winners.length() < seatsNumber ||
			(election.electionType == ElectionType.Community && election.totalVotes < getQuorum(election.startTime))
		) {
			_cancelElection();
			return;
		}

		emit ElectionFinalized(currentElection);

		election.status = ElectionStatus.Finalized;
		lastFinalizedScheduledElection = currentElection;

		if (election.electionType == ElectionType.Replacement) {
			_addMemberToCouncil(election.winners.at(0));
		} else {
			_initiateNewCouncil(election.winners);
		}
	}

	function cancelElection() external {
		if (!isElectionCancelable()) revert Error.ElectionNotCancelable();
		_cancelElection();
	}

	function setQuorumThreshold(uint256 _newThreshold) external safeOnly {
		emit QuorumThresholdSet(quorumThreshold, _newThreshold);
		quorumThreshold = _newThreshold;
	}

	// /*///////////////////////////////////////////////////////////////
	//                       INTERNAL FUNCTIONS
	// ///////////////////////////////////////////////////////////////*/

	function _startReplacementElection(address _councilMember) internal noElectionOngoing {
		if (!_isCouncilMember(_councilMember)) revert Error.NotInCouncil();

		_removeMemberFromCouncil(_councilMember);
		_startElection(ElectionType.Replacement);
	}

	function _startElection(ElectionType _electionType) internal {
		++currentElection;
		emit ElectionStarted(currentElection, _electionType);

		Election storage election = elections[currentElection];

		election.startTime = block.timestamp;
		election.status = ElectionStatus.Ongoing;
		election.electionType = _electionType;
	}

	function _cancelElection() internal {
		emit ElectionCanceled(currentElection);
		elections[currentElection].status = ElectionStatus.Invalid;
	}

	function _nominateCandidate(address _candidate) internal {
		if (!hasOngoingElection()) revert Error.ElectionFinalizedOrInvalid();
		if (!isNominationWindow()) revert Error.NotInNominationWindow();

		Election storage election = elections[currentElection];

		if (election.candidates.contains(_candidate)) revert Error.CandidateAlreadyNominated();

		/// @dev this prevent a council member from being nominated in a replacement election (becoming member twice)
		if (election.electionType == ElectionType.Replacement && _isCouncilMember(_candidate))
			revert Error.CandidateAlreadyInCouncil();

		emit CandidateNominated(currentElection, _candidate);

		election.candidates.add(_candidate);
	}

	function _updateWinnerList(Election storage _election, address _candidate) internal {
		/// @dev if candidate is already a winner, no action is required
		if (_election.winners.contains(_candidate)) return;

		uint256 seatsNumber = getAvailableSeatsForElection(elections[currentElection].electionType);

		/// @dev if the set is not complete yet, we take the first empty seat
		if (_election.winners.length() < seatsNumber) {
			_election.winners.add(_candidate);
			return;
		}

		(address leastVotedWinner, uint256 leastVotes) = _findWinnerWithLeastVotes(_election);

		if (_election.voteCounts[_candidate] > leastVotes) {
			_election.winners.remove(leastVotedWinner);
			_election.winners.add(_candidate);
		}
	}

	function _findWinnerWithLeastVotes(
		Election storage _election
	) internal view returns (address leastVotedWinner, uint256 leastVotes) {
		if (_election.winners.length() == 1) {
			leastVotedWinner = _election.winners.at(0);
			leastVotes = _election.voteCounts[leastVotedWinner];
		} else {
			leastVotes = type(uint).max;

			for (uint256 i = 0; i < _election.winners.length(); ) {
				address winner = _election.winners.at(i);
				uint256 winnerVotes = _election.voteCounts[winner];

				if (winnerVotes < leastVotes) {
					leastVotedWinner = winner;
					leastVotes = winnerVotes;
				}

				unchecked {
					++i;
				}
			}
		}
		return (leastVotedWinner, leastVotes);
	}

	// /*///////////////////////////////////////////////////////////////
	//                       		MODIFIERS
	// ///////////////////////////////////////////////////////////////*/

	modifier noElectionOngoing() {
		if (hasOngoingElection()) revert Error.ElectionAlreadyOngoing();
		_;
	}
}
