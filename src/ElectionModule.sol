// SPDX-License-Identifier: MIT
// slither-disable-start timestamp
pragma solidity ^0.8.19;

import { CouncilManager, Safe } from "src/libraries/CouncilManager.sol";

import { IStakingRewardsV2 } from "src/interfaces/IStakingRewardsV2.sol";
import { IElectionModule } from "src/interfaces/IElectionModule.sol";

import { Error } from "src/libraries/Error.sol";

import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

contract ElectionModule is IElectionModule {
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
	/// @notice Safe proxy contract
	Safe public immutable safeProxy;

	/// @notice StakingRewardsV2 contract
	IStakingRewardsV2 public immutable stakingRewardsV2;

	/// @notice time where any election can start
	uint256 public immutable startTime;

	/// @notice mapping storing all the elections following the schema (electionId => election)
	mapping(uint256 => Election) private elections;

	/// @notice the current election
	uint256 public currentElection;
	/// @notice the last finalized scheduled election
	uint256 public lastFinalizedScheduledElection;

	/// @notice the quorum threshold for a community election to be valid
	uint256 public quorumThreshold = 4000;

	/*///////////////////////////////////////////////////////////////
                             CONSTRUCTOR
	///////////////////////////////////////////////////////////////*/

	constructor(address _safeProxy, address _stakingRewardsV2, uint256 _startTime) {
		if (_safeProxy == address(0)) revert Error.ZeroAddress();
		if (_stakingRewardsV2 == address(0)) revert Error.ZeroAddress();

		safeProxy = Safe(payable(address(_safeProxy)));
		stakingRewardsV2 = IStakingRewardsV2(_stakingRewardsV2);
		startTime = _startTime;
	}

	/*///////////////////////////////////////////////////////////////
                              VIEWS
  ///////////////////////////////////////////////////////////////*/

	/// @inheritdoc IElectionModule
	function getElectionDetails(
		uint256 _electionId
	)
		external
		view
		returns (uint256 start, uint256 end, uint256 totalVotes, ElectionStatus status, ElectionType electionType)
	{
		Election storage election = elections[_electionId];
		start = election.startTime;
		end = election.startTime + ELECTION_DURATION;
		totalVotes = election.totalVotes;
		status = election.status;
		electionType = election.electionType;
	}

	/// @inheritdoc IElectionModule
	function getElectionCandidateAddress(uint256 _electionId, uint256 _index) public view returns (address) {
		return elections[_electionId].candidates.at(_index);
	}

	/// @inheritdoc IElectionModule
	function isElectionCandidate(uint256 _electionId, address _candidate) public view returns (bool) {
		return elections[_electionId].candidates.contains(_candidate);
	}

	/// @inheritdoc IElectionModule
	function getElectionWinners(uint256 _electionId) public view returns (address[] memory) {
		return elections[_electionId].winners.values();
	}

	/// @inheritdoc IElectionModule
	function isElectionWinner(uint256 _electionId, address _candidate) public view returns (bool) {
		return elections[_electionId].winners.contains(_candidate);
	}

	/// @inheritdoc IElectionModule
	function getElectionVotesForCandidate(uint256 _electionId, address _candidate) public view returns (uint256) {
		return elections[_electionId].voteCounts[_candidate];
	}

	/// @inheritdoc IElectionModule
	function hasVoted(uint256 _electionId, address _voter) public view returns (bool) {
		return elections[_electionId].hasVoted[_voter];
	}

	/// @inheritdoc IElectionModule
	function canStartScheduledElection() external view returns (bool) {
		return _canStartScheduledElection();
	}

	/// @inheritdoc IElectionModule
	function hasOngoingElection() external view returns (bool) {
		return _hasOngoingElection();
	}

	/*///////////////////////////////////////////////////////////////
                        MUTATIVE FUNCTIONS
  ///////////////////////////////////////////////////////////////*/

	/// @inheritdoc IElectionModule
	function startScheduledElection() external {
		if (!_canStartScheduledElection()) revert Error.ElectionCannotStart();
		if (_hasOngoingElection()) {
			_cancelElection();
		}
		_startElection(ElectionType.Scheduled);
	}

	/// @inheritdoc IElectionModule
	function startCommunityElection() external noElectionOngoing {
		if (stakingRewardsV2.balanceOf(msg.sender) == 0) revert Error.CallerIsNotStaking();
		_startElection(ElectionType.Community);
	}

	/// @inheritdoc IElectionModule
	function startReplacementElection(address _councilMember) external safeOnly {
		_startReplacementElection(_councilMember);
	}

	/// @inheritdoc IElectionModule
	function stepDownFromCouncil() external {
		_startReplacementElection(msg.sender);
	}

	/// @inheritdoc IElectionModule
	/// @dev this function can be called after a replacement election occured before but
	/// ended up being invalid (no candidates or votes). To avoid multisig desertion,
	/// we cannot start another replacement election until the current available seat has been filled.
	function startSingleSeatElection() external noElectionOngoing {
		if (safeProxy.getOwners().length == CouncilManager.COUNCIL_SEATS_NUMBER)
			revert Error.NoSeatAvailableInCouncil();
		_startElection(ElectionType.Replacement);
	}

	/// @inheritdoc IElectionModule
	function nominateCandidate(address _candidate) external {
		_nominateCandidate(_candidate);
	}

	/// @inheritdoc IElectionModule
	function nominateMultipleCandidates(address[] calldata _candidates) external {
		for (uint256 i = 0; i < _candidates.length; ) {
			_nominateCandidate(_candidates[i]);
			unchecked {
				++i;
			}
		}
	}

	/// @inheritdoc IElectionModule
	function vote(address _candidate) external {
		if (!_isVotingWindow()) revert Error.NotInVotingWindow();

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

	/// @inheritdoc IElectionModule
	function finalizeElection() external {
		if (_isElectionFinalized()) revert Error.ElectionFinalizedOrInvalid();

		Election storage election = elections[currentElection];

		if (block.timestamp < election.startTime + ELECTION_DURATION) revert Error.ElectionNotReadyToBeFinalized();

		/// @dev if there are no votes, or if quorum isn't met for a Community Election
		/// then the election is invalid and needs to be canceled
		uint256 seatsNumber = _getAvailableSeatsForElection(election.electionType);
		if (
			election.winners.length() < seatsNumber ||
			(election.electionType == ElectionType.Community && election.totalVotes < _getQuorum(election.startTime))
		) {
			_cancelElection();
			return;
		}

		emit ElectionFinalized(currentElection);

		election.status = ElectionStatus.Finalized;
		lastFinalizedScheduledElection = currentElection;

		if (election.electionType == ElectionType.Replacement) {
			CouncilManager._addMemberToCouncil(safeProxy, election.winners.at(0));
		} else {
			CouncilManager._initiateNewCouncil(safeProxy, election.winners);
		}
	}

	/// @inheritdoc IElectionModule
	function cancelElection() external {
		if (!_isElectionCancelable()) revert Error.ElectionNotCancelable();
		_cancelElection();
	}

	/// @inheritdoc IElectionModule
	function setQuorumThreshold(uint256 _newThreshold) external safeOnly {
		emit QuorumThresholdSet(quorumThreshold, _newThreshold);
		quorumThreshold = _newThreshold;
	}

	/*///////////////////////////////////////////////////////////////
	                      INTERNAL FUNCTIONS
	///////////////////////////////////////////////////////////////*/

	/// @notice checks if the current election is in the nomination window
	function _isNominationWindow() internal view returns (bool) {
		uint256 electionStartTime = elections[currentElection].startTime;
		return block.timestamp >= electionStartTime && block.timestamp < electionStartTime + NOMINATION_WINDOW;
	}

	/// @notice checks if the current election is in the voting window
	/// @dev _hasOngoingElection is called here because an election could possibly
	/// be in the voting window but with no candidates at all, making it invalid
	function _isVotingWindow() internal view returns (bool) {
		uint256 electionStartTime = elections[currentElection].startTime;
		return
			_hasOngoingElection() &&
			block.timestamp >= electionStartTime + NOMINATION_WINDOW &&
			block.timestamp < electionStartTime + ELECTION_DURATION;
	}

	/// @notice checks if the current election has been finalized
	function _isElectionFinalized() internal view returns (bool) {
		ElectionStatus electionStatus = elections[currentElection].status;
		return electionStatus == ElectionStatus.Finalized || electionStatus == ElectionStatus.Invalid;
	}

	/// @notice checks if the current election is cancelable
	/// @dev an election can be cancelled if it has the Ongoing status AND
	/// if nomination window ended with not enough candidates OR
	/// voting window ended with not enough winners
	function _isElectionCancelable() internal view returns (bool) {
		Election storage election = elections[currentElection];
		uint256 seatsNumber = _getAvailableSeatsForElection(elections[currentElection].electionType);
		if (
			elections[currentElection].status == ElectionStatus.Ongoing &&
			((_isVotingWindow() && elections[currentElection].candidates.length() < seatsNumber) ||
				(block.timestamp > election.startTime + ELECTION_DURATION &&
					elections[currentElection].winners.length() < seatsNumber))
		) {
			return true;
		}
		return false;
	}

	/// @notice checks if the current election has the Ongoing status
	function _hasOngoingElection() internal view returns (bool) {
		return elections[currentElection].status == ElectionStatus.Ongoing;
	}

	/// @notice checks if the current election has the Ongoing status and is scheduled
	function _hasOngoingScheduledElection() internal view returns (bool) {
		return _hasOngoingElection() && elections[currentElection].electionType == ElectionType.Scheduled;
	}

	/// @notice returns the number of available seats for an election type
	function _getAvailableSeatsForElection(ElectionType _electionType) internal pure returns (uint256) {
		return _electionType == ElectionType.Replacement ? SEATS_REPLACEMENT_ELECTION : SEATS_FULL_ELECTION;
	}

	/// @notice returns the quorum amount based on the stakingRewardsV2 total supply
	/// @param _timestamp the timestamp to use to lookup the total supply
	/// in the stakingRewardsV2 contract
	function _getQuorum(uint256 _timestamp) internal view returns (uint256) {
		return (stakingRewardsV2.totalSupplyAtTime(_timestamp) * quorumThreshold) / 10000;
	}

	/// @notice checks if a scheduled election can be started or not
	/// @dev a scheduled election can only be started if:
	/// block.timestamp >= startTime AND
	/// there is not another ongoing scheduled election AND
	/// last finalized scheduled election was more than 6 months ago
	function _canStartScheduledElection() internal view returns (bool) {
		if (block.timestamp < startTime) return false;
		if (_hasOngoingScheduledElection()) return false;
		if (
			lastFinalizedScheduledElection > 0 &&
			block.timestamp < elections[lastFinalizedScheduledElection].startTime + EPOCH_LENGTH
		) return false;
		return true;
	}

	/// @notice starts a replacement election
	/// @param _councilMember the address of the council member to be replaced
	function _startReplacementElection(address _councilMember) internal noElectionOngoing {
		if (!safeProxy.isOwner(_councilMember)) revert Error.NotInCouncil();

		_startElection(ElectionType.Replacement);
		CouncilManager._removeMemberFromCouncil(safeProxy, _councilMember);
	}

	/// @notice starts any kind of election
	function _startElection(ElectionType _electionType) internal {
		++currentElection;
		emit ElectionStarted(currentElection, _electionType);

		Election storage election = elections[currentElection];

		election.startTime = block.timestamp;
		election.status = ElectionStatus.Ongoing;
		election.electionType = _electionType;
	}

	/// @notice cancels the current election
	function _cancelElection() internal {
		emit ElectionCanceled(currentElection);
		elections[currentElection].status = ElectionStatus.Invalid;
	}

	/// @notice nominate a candidate for the current election
	function _nominateCandidate(address _candidate) internal {
		if (_candidate == address(0)) revert Error.ZeroAddress();
		if (!_hasOngoingElection()) revert Error.ElectionFinalizedOrInvalid();
		if (!_isNominationWindow()) revert Error.NotInNominationWindow();

		Election storage election = elections[currentElection];

		/// @dev this prevent a council member from being nominated in a replacement election (becoming member twice)
		if (election.electionType == ElectionType.Replacement && safeProxy.isOwner(_candidate)) {
			revert Error.CandidateAlreadyInCouncil();
		}

		emit CandidateNominated(currentElection, _candidate);

		if (!election.candidates.add(_candidate)) revert Error.AddFailed();
	}

	/// @notice updates the winners list every time a vote is recorded
	function _updateWinnerList(Election storage _election, address _candidate) internal {
		/// @dev if candidate is already a winner, no action is required
		if (_election.winners.contains(_candidate)) return;

		uint256 seatsNumber = _getAvailableSeatsForElection(elections[currentElection].electionType);

		/// @dev if the set is not complete yet, we take the first empty seat
		if (_election.winners.length() < seatsNumber) {
			if (!_election.winners.add(_candidate)) revert Error.AddFailed();
			return;
		}

		(address leastVotedWinner, uint256 leastVotes) = _findWinnerWithLeastVotes(_election);

		if (_election.voteCounts[_candidate] > leastVotes) {
			if (!_election.winners.remove(leastVotedWinner)) revert Error.RemoveFailed();
			if (!_election.winners.add(_candidate)) revert Error.AddFailed();
		}
	}

	/// @notice find and returns the address and votes for the current least voted winner
	function _findWinnerWithLeastVotes(
		Election storage _election
	) internal view returns (address leastVotedWinner, uint256 leastVotes) {
		uint256 winnersLength = _election.winners.length();
		if (winnersLength == 1) {
			leastVotedWinner = _election.winners.at(0);
			leastVotes = _election.voteCounts[leastVotedWinner];
		} else {
			leastVotes = type(uint256).max;

			for (uint256 i = 0; i < winnersLength; ) {
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

	/*///////////////////////////////////////////////////////////////
	                      		MODIFIERS
	///////////////////////////////////////////////////////////////*/

	/// @notice reverts if there is no ongoing election
	modifier noElectionOngoing() {
		if (_hasOngoingElection()) revert Error.ElectionAlreadyOngoing();
		_;
	}

	/// @notice reverts if caller is not Safe proxy
	modifier safeOnly() {
		if (msg.sender != address(safeProxy)) revert Error.Unauthorized();
		_;
	}
}
// slither-disable-end timestamp
