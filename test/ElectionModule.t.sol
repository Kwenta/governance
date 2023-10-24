// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";

import { ElectionModule, IElectionModule } from "src/ElectionModule.sol";

import { StakingRewardsV2Mock } from "test/mocks/StakingRewardsV2Mock.sol";
import { SafeProxyMock } from "test/mocks/SafeProxyMock.sol";

import { Error } from "src/libraries/Error.sol";

contract ElectionModuleTest is Test {
	address user1 = vm.addr(1);
	address user2 = vm.addr(2);
	address user3 = vm.addr(3);
	address user4 = vm.addr(4);
	address user5 = vm.addr(5);
	address user6 = vm.addr(6);

	SafeProxyMock public safeProxy;
	StakingRewardsV2Mock public stakingRewards;
	ElectionModule public electionModule;

	uint256 public constant DEFAULT_START_TIME = 1697415594;
	uint256 constant EPOCH_LENGTH = 26 weeks;
	uint256 constant ELECTION_DURATION = 3 weeks;
	uint256 constant NOMINATION_WINDOW = 1 weeks;

	uint256 public constant DEFAULT_STAKE_AMOUNT = 100;

	uint256 public constant SAFE_THRESHOLD = 3;

	event ElectionStarted(uint256 indexed electionId);
	event CandidateNominated(uint256 indexed electionId, address indexed candidate);
	event VoteRecorded(uint256 indexed electionId, address indexed voter, address candidate);
	event ElectionFinalized(uint256 indexed electionId);
	event ElectionCanceled(uint256 indexed electionId);

	function setUp() public {
		stakingRewards = new StakingRewardsV2Mock();

		safeProxy = new SafeProxyMock();
		address[] memory safeOwners = new address[](5);
		safeOwners[0] = user1;
		safeOwners[1] = user6;
		safeOwners[2] = vm.addr(10);
		safeOwners[3] = vm.addr(11);
		safeOwners[4] = vm.addr(12);

		safeProxy.initializeOwners(safeOwners, SAFE_THRESHOLD);

		electionModule = new ElectionModule(address(stakingRewards), address(safeProxy), DEFAULT_START_TIME);

		vm.prank(user1);
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		vm.prank(user2);
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		vm.prank(user3);
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		vm.prank(user4);
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		vm.prank(user5);
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		vm.prank(user6);
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);

		vm.label(user1, "user1");
		vm.label(user2, "user2");
		vm.label(user3, "user3");
		vm.label(user4, "user4");
		vm.label(user5, "user5");
		vm.label(user6, "user6");
	}

	function generateNominations(ElectionModule _electionModule) public {
		// we start an election and and we nominate enough candidates
		vm.warp(DEFAULT_START_TIME);
		_electionModule.startScheduledElection();
		vm.warp(DEFAULT_START_TIME + 1);
		_electionModule.nominateCandidate(1, user1);
		_electionModule.nominateCandidate(1, user2);
		_electionModule.nominateCandidate(1, user3);
		_electionModule.nominateCandidate(1, user4);
		_electionModule.nominateCandidate(1, user5);

		// we close the nomination window
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
	}

	function generateElection(ElectionModule _electionModule) public {
		generateNominations(_electionModule);

		// we vote and election enough candidates
		vm.prank(user1);
		_electionModule.vote(1, user1);
		vm.prank(user2);
		_electionModule.vote(1, user2);
		vm.prank(user3);
		_electionModule.vote(1, user3);
		vm.prank(user4);
		_electionModule.vote(1, user4);
		vm.prank(user5);
		_electionModule.vote(1, user5);

		// we close the voting window
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION + 1);
	}
}

contract Constructor is ElectionModuleTest {
	function test_RevertIf_StakingRewardsIsZero() public {
		vm.expectRevert(Error.ZeroAddress.selector);
		new ElectionModule(address(0), address(safeProxy), 0);
	}

	function test_RevertIf_SafeProxyIsZero() public {
		vm.expectRevert(Error.ZeroAddress.selector);
		new ElectionModule(address(stakingRewards), address(0), 0);
	}

	function test_setsStorageVariables() public {
		ElectionModule electionModule = new ElectionModule(
			address(stakingRewards),
			address(safeProxy),
			DEFAULT_START_TIME
		);
		assertTrue(address(electionModule.stakingRewardsV2()) == address(stakingRewards));
		assertTrue(address(electionModule.safeProxy()) == address(safeProxy));
		assertTrue(electionModule.startTime() == DEFAULT_START_TIME);
	}
}

contract StartScheduledElection is ElectionModuleTest {
	function test_RevertIf_StartTimeNotReached() public {
		vm.warp(DEFAULT_START_TIME - 1);
		vm.expectRevert(Error.ElectionNotReadyToBeStarted.selector);
		electionModule.startScheduledElection();
	}

	function test_RevertIf_HasOngoingElection() public {
		// we start a new scheduled election first
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		vm.expectRevert(Error.ElectionNotReadyToBeStarted.selector);
		electionModule.startScheduledElection();
	}

	function test_RevertIf_NotInNewEpochWindow() public {
		// we start a new scheduled election first and finalize it
		generateElection(electionModule);
		electionModule.finalizeElection(1);

		// we now try call for a new election
		vm.expectRevert(Error.ElectionNotReadyToBeStarted.selector);
		electionModule.startScheduledElection();
	}

	function test_IncrementsLastScheduledElection() public {
		assertTrue(electionModule.lastScheduledElection() == 0);
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		assertTrue(electionModule.lastScheduledElection() == 1);
	}

	function test_EmitsElectionStartedEvent() public {
		vm.expectEmit(true, false, false, false);
		emit ElectionStarted(1);
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
	}

	function test_SetsElectionStruc() public {
		uint256 electionId = 1;

		assertTrue(electionModule.getElectionStartTime(electionId) == 0);
		assertTrue(electionModule.getElectionStatus(electionId) == IElectionModule.ElectionStatus.Invalid);

		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		assertTrue(electionModule.getElectionStartTime(electionId) == DEFAULT_START_TIME);
		assertTrue(electionModule.getElectionStatus(electionId) == IElectionModule.ElectionStatus.Ongoing);
	}

	function test_StartsElectionAfterFinalised() public {
		// we start a new scheduled election first and finalize it
		generateElection(electionModule);
		electionModule.finalizeElection(1);

		// we now try call for a new election in the correct window
		vm.warp(electionModule.getElectionStartTime(1) + EPOCH_LENGTH);
		electionModule.startScheduledElection();

		assertTrue(electionModule.getElectionStatus(2) == IElectionModule.ElectionStatus.Ongoing);
	}

	function test_StartsElectionAfterInvalid() public {
		assertTrue(electionModule.lastScheduledElection() == 0);

		// we start a new scheduled election first and don't nominate any candidate
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		assertTrue(electionModule.lastScheduledElection() == 1);

		// we cancel the election
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		electionModule.cancelElection(1);

		// we now create a new election
		electionModule.startScheduledElection();
		assertTrue(electionModule.lastScheduledElection() == 2);
	}
}

contract NominateCandidate is ElectionModuleTest {
	function test_RevertIf_NotInNominationWindow() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// reverts before the nomination window
		vm.expectRevert(Error.NotInNominationWindow.selector);
		electionModule.nominateCandidate(1, user1);

		// reverts after the nomination window
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.expectRevert(Error.NotInNominationWindow.selector);
		electionModule.nominateCandidate(1, user1);
	}

	function test_RevertIf_CandidateAlreadyNominated() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate user1
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);

		// we try to nominate user1 again
		vm.expectRevert(Error.CandidateAlreadyNominated.selector);
		electionModule.nominateCandidate(1, user1);
	}

	function test_EmitsCandidateNominatedEvent() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate user1
		vm.warp(DEFAULT_START_TIME + 1);
		vm.expectEmit(true, true, false, false);
		emit CandidateNominated(1, user1);
		electionModule.nominateCandidate(1, user1);
	}

	function test_AddsCandidateInElectionStruc() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		assertTrue(electionModule.isElectionCandidate(1, user1) == false);

		// we nominate user1
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);

		assertTrue(electionModule.isElectionCandidate(1, user1) == true);
	}
}

contract NominateMultipleCandidates is ElectionModuleTest {
	function test_AddsCandidatesInElectionStruc() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		address[] memory candidates = new address[](5);
		candidates[0] = user1;
		candidates[1] = user2;
		candidates[2] = user3;
		candidates[3] = user4;
		candidates[4] = user5;

		assertTrue(electionModule.isElectionCandidate(1, user1) == false);
		assertTrue(electionModule.isElectionCandidate(1, user2) == false);
		assertTrue(electionModule.isElectionCandidate(1, user3) == false);
		assertTrue(electionModule.isElectionCandidate(1, user4) == false);
		assertTrue(electionModule.isElectionCandidate(1, user5) == false);

		// we nominate 5 users
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateMultipleCandidates(1, candidates);

		assertTrue(electionModule.isElectionCandidate(1, user1) == true);
		assertTrue(electionModule.isElectionCandidate(1, user2) == true);
		assertTrue(electionModule.isElectionCandidate(1, user3) == true);
		assertTrue(electionModule.isElectionCandidate(1, user4) == true);
		assertTrue(electionModule.isElectionCandidate(1, user5) == true);
	}
}

contract Vote is ElectionModuleTest {
	function test_RevertIf_NotAnElection() public {
		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(0, user1);

		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(1, user1);

		// we start the first election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(0, user1);

		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(2, user1);
	}

	function test_RevertIf_NotInVotingWindow() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we try to vote before the voting window
		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(1, user1);

		// we try to vote after the voting window
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION + 1);
		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(1, user1);
	}

	function test_RevertIf_AlreadyVoted() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate a candidate
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);

		// we vote twice
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.startPrank(user1);
		electionModule.vote(1, user1);

		vm.expectRevert(Error.AlreadyVoted.selector);
		electionModule.vote(1, user1);
		vm.stopPrank();
	}

	function test_RevertIf_CandidateNotNominated() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate a candidate
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);

		// we vote for another candidate
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.startPrank(user1);
		vm.expectRevert(Error.CandidateNotNominated.selector);
		electionModule.vote(1, user2);
	}

	function test_RevertIf_VoterWasNotStaking() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate a candidate
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);

		// a user who wasn't staking votes for the candidate
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.expectRevert(Error.NotStakingBeforeElection.selector);
		electionModule.vote(1, user1);
	}

	function test_EmitsVoteRecordedEvent() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate a candidate
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user2);

		// we vote for the candidate
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.startPrank(user1);
		vm.expectEmit(true, true, false, true);
		emit VoteRecorded(1, user1, user2);
		electionModule.vote(1, user2);
	}

	function test_UpdatesElectionStruc() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		assertTrue(electionModule.hasVoted(1, user1) == false);
		assertTrue(electionModule.hasVoted(1, user2) == false);
		assertTrue(electionModule.getElectionVotesForCandidate(1, user2) == 0);
		assertTrue(electionModule.getElectionTotalVotes(1) == 0);

		// we nominate a candidate
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user2);

		// we vote for the candidate
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.startPrank(user1);
		electionModule.vote(1, user2);

		assertTrue(electionModule.hasVoted(1, user1) == true);
		assertTrue(electionModule.getElectionVotesForCandidate(1, user2) == DEFAULT_STAKE_AMOUNT);
		assertTrue(electionModule.getElectionTotalVotes(1) == DEFAULT_STAKE_AMOUNT);

		// another user votes
		vm.startPrank(user2);
		electionModule.vote(1, user2);

		assertTrue(electionModule.hasVoted(1, user2) == true);
		assertTrue(electionModule.getElectionVotesForCandidate(1, user2) == 2 * DEFAULT_STAKE_AMOUNT);
		assertTrue(electionModule.getElectionTotalVotes(1) == 2 * DEFAULT_STAKE_AMOUNT);
	}

	function test_UpdatesWinnerList() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate 6 candidates
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);
		electionModule.nominateCandidate(1, user2);
		electionModule.nominateCandidate(1, user3);
		electionModule.nominateCandidate(1, user4);
		electionModule.nominateCandidate(1, user5);
		electionModule.nominateCandidate(1, user6);

		assertFalse(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 0);

		// we vote for user1
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.prank(user1);
		electionModule.vote(1, user1);

		assertTrue(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 1);

		// we vote for user2
		vm.prank(user2);
		electionModule.vote(1, user2);

		assertTrue(electionModule.isElectionWinner(1, user2));
		assertTrue(electionModule.getElectionWinners(1).length == 2);

		// we vote for user3
		vm.prank(user3);
		electionModule.vote(1, user3);

		assertTrue(electionModule.isElectionWinner(1, user3));
		assertTrue(electionModule.getElectionWinners(1).length == 3);

		// we vote for user4
		vm.prank(user4);
		electionModule.vote(1, user4);

		assertTrue(electionModule.isElectionWinner(1, user4));
		assertTrue(electionModule.getElectionWinners(1).length == 4);

		// we vote for user5
		vm.prank(user5);
		electionModule.vote(1, user5);

		assertTrue(electionModule.isElectionWinner(1, user5));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user6 but they don't get added to the winner list
		// as they get the exact same votes amount
		vm.prank(user6);
		electionModule.vote(1, user6);

		assertFalse(electionModule.isElectionWinner(1, user6));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user6 again, and they now replace user1 in the
		// winner list
		vm.startPrank(vm.addr(7));
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		electionModule.vote(1, user6);

		assertTrue(electionModule.isElectionWinner(1, user6));
		assertFalse(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user1 again, and they now replace user5 in the
		// winner list
		vm.startPrank(vm.addr(8));
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		electionModule.vote(1, user1);

		assertTrue(electionModule.isElectionWinner(1, user1));
		assertFalse(electionModule.isElectionWinner(1, user5));
		assertTrue(electionModule.getElectionWinners(1).length == 5);
	}
}

contract FinalizeEelection is ElectionModuleTest {
	function test_RevertIf_ElectionNotOngoing() public {
		// we try to finalize a election which wasn't started
		vm.warp(DEFAULT_START_TIME);
		vm.expectRevert(Error.ElectionAlreadyFinalizedOrInvalid.selector);
		electionModule.finalizeElection(1);
	}

	function test_RevertIf_AlreadyFinalized() public {
		// we start an election and and we nominate enough candidates
		generateNominations(electionModule);

		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection(1);

		// we vote and election enough candidates
		vm.prank(user1);
		electionModule.vote(1, user1);
		vm.prank(user2);
		electionModule.vote(1, user2);
		vm.prank(user3);
		electionModule.vote(1, user3);
		vm.prank(user4);
		electionModule.vote(1, user4);
		vm.prank(user5);
		electionModule.vote(1, user5);

		// we finalize the vote
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);
		electionModule.finalizeElection(1);

		// we can't finalize it twice
		vm.expectRevert(Error.ElectionAlreadyFinalizedOrInvalid.selector);
		electionModule.finalizeElection(1);
	}

	function testFuzz_RevertIf_NotElectionEndTime(uint256 _delay) public {
		vm.assume(_delay <= ELECTION_DURATION);
		// we start an election and try to finalize it before the voting window ends
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		vm.expectRevert(Error.ElectionNotReadyToBeFinalized.selector);
		electionModule.finalizeElection(1);
	}

	function test_CancelElectionIfNoCandidates() public {
		// we start an election and and we don't nominate enough candidates
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);
		electionModule.nominateCandidate(1, user2);
		electionModule.nominateCandidate(1, user3);

		// we close the voting window meaning there are no votes
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);
		vm.expectEmit(true, false, false, false);
		emit ElectionCanceled(1);
		electionModule.finalizeElection(1);
	}

	function test_CancelElectionIfNoVotes() public {
		// we start an election and and we nominate enough candidates
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);
		electionModule.nominateCandidate(1, user2);
		electionModule.nominateCandidate(1, user3);
		electionModule.nominateCandidate(1, user4);
		electionModule.nominateCandidate(1, user5);

		// we close the voting window meaning there are no votes
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);
		vm.expectEmit(true, false, false, false);
		emit ElectionCanceled(1);
		electionModule.finalizeElection(1);
	}

	function test_EmitsElectionFinalizedEvent() public {
		generateElection(electionModule);
		vm.expectEmit(true, false, false, false);
		emit ElectionFinalized(1);
		electionModule.finalizeElection(1);
	}

	function test_UpdatesElectionStruc() public {
		assertTrue(electionModule.lastFinalizedScheduledElection() == 0);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Invalid);

		generateElection(electionModule);

		assertTrue(electionModule.lastFinalizedScheduledElection() == 0);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Ongoing);

		electionModule.finalizeElection(1);

		assertTrue(electionModule.lastFinalizedScheduledElection() == 1);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Finalized);
	}

	function test_InitiatesNewCouncil() public {
		// we check who are the current safe owners pre-election
		assertTrue(safeProxy.getOwners().length == 5);
		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user6));
		assertTrue(safeProxy.isOwner(vm.addr(10)));
		assertTrue(safeProxy.isOwner(vm.addr(11)));
		assertTrue(safeProxy.isOwner(vm.addr(12)));

		generateElection(electionModule);
		electionModule.finalizeElection(1);

		assertTrue(safeProxy.getOwners().length == 5);
		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user2));
		assertTrue(safeProxy.isOwner(user3));
		assertTrue(safeProxy.isOwner(user4));
		assertTrue(safeProxy.isOwner(user5));
	}
}

contract CancelElection is ElectionModuleTest {
	function test_RevertIf_NotElection() public {
		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection(0);

		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection(1);
	}

	function test_RevertIf_NotOngoing() public {
		// we start an election and cancel it because not enough candidates
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		electionModule.cancelElection(1);

		// reverts because already set to Invalid
		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection(1);
	}

	function test_RevertIf_EnoughCandidatesAndVotes() public {
		// we start an election and and we nominate enough candidates
		generateNominations(electionModule);

		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection(1);

		// we vote and election enough candidates
		vm.prank(user1);
		electionModule.vote(1, user1);
		vm.prank(user2);
		electionModule.vote(1, user2);
		vm.prank(user3);
		electionModule.vote(1, user3);
		vm.prank(user4);
		electionModule.vote(1, user4);
		vm.prank(user5);
		electionModule.vote(1, user5);

		// we close the voting window
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION + 1);

		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection(1);
	}

	function test_EmitsElectionCanceledEvent() public {
		// we start an election and and we don't enough candidates
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);

		// we close the nomination window making the election cancelable
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.expectEmit(true, false, false, false);
		emit ElectionCanceled(1);
		electionModule.cancelElection(1);
	}

	function test_UpdatesElectionStruc() public {
		// we start an election and and we don't enough candidates
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(1, user1);

		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Ongoing);

		// we close the nomination window making the election cancelable
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		electionModule.cancelElection(1);

		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Invalid);
	}
}
