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

	uint256 constant EPOCH_LENGTH = 26 weeks;
	uint256 constant ELECTION_DURATION = 3 weeks;
	uint256 constant NOMINATION_WINDOW = 1 weeks;
	uint256 constant SEATS_NUMBER = 5;

	/*///////////////////////////////////////////////////////////////
                              	STATE
  ///////////////////////////////////////////////////////////////*/

	/// @notice start time for scheduled elections
	uint256 public startTime;

	/// @notice mapping of election number to election
	mapping(uint256 => Election) private scheduledElections;
	uint256 public lastScheduledElection;
	uint256 public lastFinalizedScheduledElection;

	/// @notice tracker for timestamp start of last scheduled election
	uint256 public lastScheduledElectionStartTime;

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

	function isNominationWindow(uint256 _electionId) public view returns (bool) {
		return
			scheduledElections[_electionId].startTime > 0 &&
			block.timestamp > scheduledElections[_electionId].startTime &&
			block.timestamp <= scheduledElections[_electionId].startTime + NOMINATION_WINDOW;
	}

	function isVotingWindow(uint256 _electionId) public view returns (bool) {
		return
			scheduledElections[_electionId].startTime > 0 &&
			block.timestamp > scheduledElections[_electionId].startTime + NOMINATION_WINDOW &&
			block.timestamp <= scheduledElections[_electionId].startTime + ELECTION_DURATION;
	}

	function getElectionStartTime(uint256 _electionId) public view returns (uint256) {
		return scheduledElections[_electionId].startTime;
	}

	function getElectionEndTime(uint256 _electionId) public view returns (uint256) {
		return scheduledElections[_electionId].startTime + ELECTION_DURATION;
	}

	function getElectionTotalVotes(uint256 _electionId) public view returns (uint256) {
		return scheduledElections[_electionId].totalVotes;
	}

	function getElectionStatus(uint256 _electionId) public view returns (ElectionStatus) {
		return scheduledElections[_electionId].status;
	}

	function getElectionCandidateAddress(uint256 _electionId, uint256 _index) public view returns (address) {
		return scheduledElections[_electionId].candidates.at(_index);
	}

	function isElectionCandidate(uint256 _electionId, address _candidate) public view returns (bool) {
		return scheduledElections[_electionId].candidates.contains(_candidate);
	}

	function getElectionWinners(uint256 _electionId) public view returns (address[] memory) {
		EnumerableSet.AddressSet storage electionWinners = scheduledElections[_electionId].winners;
		address[] memory winnersArray = new address[](electionWinners.length());
		for (uint i = 0; i < electionWinners.length(); ++i) {
			winnersArray[i] = electionWinners.at(i);
		}
		return winnersArray;
	}

	function isElectionWinner(uint256 _electionId, address _candidate) public view returns (bool) {
		return scheduledElections[_electionId].winners.contains(_candidate);
	}

	function getElectionVotesForCandidate(uint256 _electionId, address _candidate) public view returns (uint256) {
		return scheduledElections[_electionId].voteCounts[_candidate];
	}

	function hasVoted(uint256 _electionId, address _voter) public view returns (bool) {
		return scheduledElections[_electionId].hasVoted[_voter];
	}

	function isElectionFinalized(uint256 _electionId) public view returns (bool) {
		return
			scheduledElections[_electionId].status == ElectionStatus.Finalized ||
			scheduledElections[_electionId].status == ElectionStatus.Invalid;
	}

	function isElectionCancelable(uint256 _electionId) public view returns (bool) {
		/// @dev an election is considered valid if it has the Ongoing status AND
		/// if nomination window ended with enough candidates OR
		/// voting window ended with enough winners
		if (
			scheduledElections[_electionId].status == ElectionStatus.Ongoing &&
			((isVotingWindow(_electionId) && scheduledElections[_electionId].candidates.length() < SEATS_NUMBER) ||
				(block.timestamp > getElectionEndTime(_electionId) &&
					scheduledElections[_electionId].winners.length() < SEATS_NUMBER))
		) {
			return true;
		} else return false;
	}

	function hasOngoingScheduledElection() public view returns (bool) {
		return scheduledElections[lastScheduledElection].status == ElectionStatus.Ongoing;
	}

	function canStartScheduledElection() public view returns (bool) {
		if (block.timestamp < startTime) return false;
		if (hasOngoingScheduledElection()) return false;
		if (
			lastFinalizedScheduledElection > 0 &&
			block.timestamp < scheduledElections[lastFinalizedScheduledElection].startTime + EPOCH_LENGTH
		) return false;
		return true;
	}

	/*///////////////////////////////////////////////////////////////
                        MUTATIVE FUNCTIONS
  ///////////////////////////////////////////////////////////////*/

	function startScheduledElection() external {
		if (!canStartScheduledElection()) {
			revert Error.ElectionNotReadyToBeStarted();
		} else {
			++lastScheduledElection;
			_cancelOnGoingElections();
			_startElection(ElectionType.Scheduled);
		}
	}

	function nominateCandidate(uint256 _electionId, address _candidate) external {
		_nominateCandidate(_electionId, _candidate);
	}

	function nominateMultipleCandidates(uint256 _electionId, address[] calldata candidates) external {
		for (uint256 i = 0; i < candidates.length; ) {
			_nominateCandidate(_electionId, candidates[i]);
			unchecked {
				++i;
			}
		}
	}

	function vote(uint256 _electionId, address _candidate) external {
		Election storage election = scheduledElections[_electionId];

		if (!isVotingWindow(_electionId)) revert Error.NotInVotingWindow();
		if (election.hasVoted[msg.sender]) revert Error.AlreadyVoted();
		if (!election.candidates.contains(_candidate)) revert Error.CandidateNotNominated();

		uint256 votingPower = stakingRewardsV2.balanceAtTime(msg.sender, election.startTime);
		if (votingPower == 0) revert Error.NotStakingBeforeElection();

		emit VoteRecorded(_electionId, msg.sender, _candidate);

		election.hasVoted[msg.sender] = true;
		election.voteCounts[_candidate] += votingPower;
		election.totalVotes += votingPower;

		_updateWinnerList(election, _candidate);
	}

	function finalizeElection(uint256 _electionId) external {
		if (isElectionFinalized(_electionId)) revert Error.ElectionAlreadyFinalizedOrInvalid();
		if (block.timestamp < getElectionEndTime(_electionId)) revert Error.ElectionNotReadyToBeFinalized();

		/// @dev if there are no votes, then the election is invalid and needs to be canceled
		if (scheduledElections[_electionId].winners.length() < SEATS_NUMBER) {
			_cancelElection(_electionId);
		} else {
			emit ElectionFinalized(_electionId);

			scheduledElections[_electionId].status = ElectionStatus.Finalized;
			lastFinalizedScheduledElection = _electionId;

			_initiateNewCouncil(scheduledElections[_electionId].winners);
		}
	}

	function cancelElection(uint256 _electionId) external {
		if (!isElectionCancelable(_electionId)) revert Error.ElectionNotCancelable();
		_cancelElection(_electionId);
	}

	/*///////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
  ///////////////////////////////////////////////////////////////*/

	function _wasStakingBeforeElection(address _voter, uint256 _startTime) internal view returns (bool) {
		return stakingRewardsV2.balanceAtTime(_voter, _startTime) > 0;
	}

	function _startElection(ElectionType _electionType) internal {
		emit ElectionStarted(lastScheduledElection);

		scheduledElections[lastScheduledElection].startTime = block.timestamp;
		scheduledElections[lastScheduledElection].status = ElectionStatus.Ongoing;
		scheduledElections[lastScheduledElection].electionType = _electionType;
	}

	function _nominateCandidate(uint256 _electionId, address _candidate) internal {
		if (!isNominationWindow(_electionId)) revert Error.NotInNominationWindow();
		if (scheduledElections[_electionId].candidates.contains(_candidate)) revert Error.CandidateAlreadyNominated();

		// /// @dev this prevent a council member from being nominated in a replacement election (becoming member twice)
		// if (scheduledElections[_electionId].electionType == ElectionType.Replacement && _isCouncilMember(_candidate))
		// 	revert Error.CandidateAlreadyInCouncil();

		emit CandidateNominated(_electionId, _candidate);

		scheduledElections[_electionId].candidates.add(_candidate);
	}

	function _cancelElection(uint256 _electionId) internal {
		emit ElectionCanceled(_electionId);
		scheduledElections[_electionId].status = ElectionStatus.Invalid;
	}

	function _cancelOnGoingElections() internal {}

	function _updateWinnerList(Election storage _election, address _candidate) internal {
		/// @dev if candidate is already a winner, no action is required
		if (_election.winners.contains(_candidate)) return;

		/// @dev if the set is not complete yet, we take the first empty seat
		if (_election.winners.length() < SEATS_NUMBER) {
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
		return (leastVotedWinner, leastVotes);
	}
}
