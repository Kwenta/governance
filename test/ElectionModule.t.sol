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

	event ElectionStarted(uint256 indexed electionId, IElectionModule.ElectionType indexed electionType);
	event CandidateNominated(uint256 indexed electionId, address indexed candidate);
	event VoteRecorded(uint256 indexed electionId, address indexed voter, address candidate);
	event ElectionFinalized(uint256 indexed electionId);
	event ElectionCanceled(uint256 indexed electionId);
	event RemovedOwner(address indexed owner);
	event ChangedThreshold(uint256 threshold);

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

	function generateNominations(IElectionModule.ElectionType _electionType) public {
		// we start an election and and we nominate enough candidates
		vm.warp(DEFAULT_START_TIME);
		if (_electionType == IElectionModule.ElectionType.Scheduled) {
			electionModule.startScheduledElection();
			electionModule.nominateCandidate(user1);
			electionModule.nominateCandidate(user6);
		} else if (_electionType == IElectionModule.ElectionType.Community) {
			vm.prank(user1);
			electionModule.startCommunityElection();
			electionModule.nominateCandidate(user1);
			electionModule.nominateCandidate(user6);
		} else {
			vm.prank(address(safeProxy));
			electionModule.startReplacementElection(user1);
		}

		electionModule.nominateCandidate(user2);
		electionModule.nominateCandidate(user3);
		electionModule.nominateCandidate(user4);
		electionModule.nominateCandidate(user5);

		// we close the nomination window
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
	}

	function generateElection(IElectionModule.ElectionType _electionType) public {
		generateNominations(_electionType);

		if (_electionType == IElectionModule.ElectionType.Scheduled) {
			vm.prank(user1);
			electionModule.vote(user1);
		} else if (_electionType == IElectionModule.ElectionType.Community) {
			vm.prank(user1);
			electionModule.vote(user1);
		}

		// we vote and election enough candidates

		vm.prank(user2);
		electionModule.vote(user2);
		vm.prank(user3);
		electionModule.vote(user3);
		vm.prank(user4);
		electionModule.vote(user4);
		vm.prank(user5);
		electionModule.vote(user5);

		// we close the voting window
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);
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
		vm.expectRevert(Error.ElectionCannotStart.selector);
		electionModule.startScheduledElection();
	}

	function test_RevertIf_HasOngoingElection() public {
		vm.warp(DEFAULT_START_TIME);
		// we start a new scheduled election first
		electionModule.startScheduledElection();

		vm.expectRevert(Error.ElectionCannotStart.selector);
		electionModule.startScheduledElection();
	}

	function test_RevertIf_NotInNewEpochWindow() public {
		// we start a new scheduled election first and finalize it
		generateElection(IElectionModule.ElectionType.Scheduled);
		electionModule.finalizeElection();

		// we now try call for a new election
		vm.expectRevert(Error.ElectionCannotStart.selector);
		electionModule.startScheduledElection();
	}

	function test_IncrementsLastElection() public {
		assertTrue(electionModule.currentElection() == 0);
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		assertTrue(electionModule.currentElection() == 1);
	}

	function test_EmitsElectionStartedEvent() public {
		vm.expectEmit(true, false, false, false);
		emit ElectionStarted(1, IElectionModule.ElectionType.Scheduled);
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
		assertTrue(electionModule.getElectionType(electionId) == IElectionModule.ElectionType.Scheduled);
	}

	function test_StartsElectionAfterFinalised() public {
		// we start a new scheduled election first and finalize it
		generateElection(IElectionModule.ElectionType.Scheduled);
		electionModule.finalizeElection();

		// we now try call for a new election in the correct window
		vm.warp(electionModule.getElectionStartTime(1) + EPOCH_LENGTH);
		electionModule.startScheduledElection();

		assertTrue(electionModule.getElectionStatus(2) == IElectionModule.ElectionStatus.Ongoing);
	}

	function test_StartsElectionAfterInvalid() public {
		assertTrue(electionModule.currentElection() == 0);

		// we start a new scheduled election first and don't nominate any candidate
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		assertTrue(electionModule.currentElection() == 1);

		// we cancel the election
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		electionModule.cancelElection();

		// we now create a new election
		electionModule.startScheduledElection();
		assertTrue(electionModule.currentElection() == 2);
	}

	function test_CancelOtherNonScheduledElection() public {
		// we start a community election
		vm.warp(DEFAULT_START_TIME);
		vm.expectEmit(true, true, false, false);
		emit ElectionStarted(1, IElectionModule.ElectionType.Community);
		vm.prank(user1);
		electionModule.startCommunityElection();

		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Ongoing);

		// we now start a scheduled election
		vm.warp(DEFAULT_START_TIME + 1);
		vm.expectEmit(true, false, false, false);
		emit ElectionCanceled(1);
		vm.expectEmit(true, true, false, false);
		emit ElectionStarted(2, IElectionModule.ElectionType.Scheduled);
		electionModule.startScheduledElection();

		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Invalid);
		assertTrue(electionModule.getElectionStatus(2) == IElectionModule.ElectionStatus.Ongoing);
	}
}

contract StartCommunityElection is ElectionModuleTest {
	function test_RevertIf_CallerIsNotStaking() public {
		vm.warp(DEFAULT_START_TIME);
		vm.expectRevert(Error.CallerIsNotStaking.selector);
		electionModule.startCommunityElection();
	}

	function test_RevertIf_HasOngoingElection() public {
		vm.warp(DEFAULT_START_TIME);
		// user1 is staking
		vm.startPrank(user1);
		// we start a community election
		electionModule.startCommunityElection();

		vm.expectRevert(Error.ElectionAlreadyOngoing.selector);
		electionModule.startCommunityElection();

		vm.stopPrank();
	}

	function test_EmitsElectionStartedEvent() public {
		vm.warp(DEFAULT_START_TIME);
		vm.startPrank(user1);

		vm.expectEmit(true, true, false, false);
		emit ElectionStarted(1, IElectionModule.ElectionType.Community);
		electionModule.startCommunityElection();

		vm.stopPrank();
	}

	function test_SetsElectionStruc() public {
		vm.warp(DEFAULT_START_TIME);
		vm.startPrank(user1);

		electionModule.startCommunityElection();
		assertTrue(electionModule.getElectionStartTime(1) == DEFAULT_START_TIME);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Ongoing);
		assertTrue(electionModule.getElectionType(1) == IElectionModule.ElectionType.Community);

		vm.stopPrank();
	}
}

contract StartReplacementElection is ElectionModuleTest {
	function test_RevertIf_CallerNotSafe() public {
		vm.expectRevert(Error.Unauthorized.selector);
		electionModule.startReplacementElection(user2);
	}

	function test_RevertIf_NotCouncilMember() public {
		// user2 is not in council, so it should revert
		vm.prank(address(safeProxy));
		vm.expectRevert(Error.NotInCouncil.selector);
		electionModule.startReplacementElection(user2);
	}

	function test_RevertIf_HasOngoingElection() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		vm.prank(address(safeProxy));
		vm.expectRevert(Error.ElectionAlreadyOngoing.selector);
		electionModule.startReplacementElection(user1);
	}

	function test_RevertIf_NotEnoughMembersInCouncil() public {
		// we call for a first replacement election
		vm.warp(DEFAULT_START_TIME);
		vm.startPrank(address(safeProxy));
		electionModule.startReplacementElection(user1);

		// we don't vote and wait for the election to be considered as Invalid
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);
		electionModule.finalizeElection();

		// we now try to remove user6 from the council and it reverts
		vm.expectRevert(Error.NotEnoughMembersInCouncil.selector);
		electionModule.startReplacementElection(user6);

		vm.stopPrank();
	}

	function test_RemovesMemberFromCouncil() public {
		vm.warp(DEFAULT_START_TIME);

		assertTrue(safeProxy.isOwner(user1));

		vm.prank(address(safeProxy));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user1);
		vm.expectEmit(false, false, false, true);
		emit ChangedThreshold(SAFE_THRESHOLD - 1);
		electionModule.startReplacementElection(user1);

		assertFalse(safeProxy.isOwner(user1));
	}

	function test_EmitsElectionStartedEvent() public {
		vm.warp(DEFAULT_START_TIME);
		vm.prank(address(safeProxy));
		vm.expectEmit(true, false, false, false);
		emit ElectionStarted(1, IElectionModule.ElectionType.Replacement);
		electionModule.startReplacementElection(user1);
	}
}

// Since both StartReplacementElection & StepDownFromCouncil are calling the same
// internal function we don't need to repeat the tests
contract StepDownFromCouncil is ElectionModuleTest {
	function test_RevertIfCallerNotCouncilMember() public {
		// user2 is not in council, so it should revert
		vm.prank(user2);
		vm.expectRevert(Error.NotInCouncil.selector);
		electionModule.stepDownFromCouncil();
	}

	function test_SetsRemovesMsgSenderFromCouncil() public {
		vm.warp(DEFAULT_START_TIME);

		assertTrue(safeProxy.isOwner(user1));

		vm.prank(user1);
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user1);
		vm.expectEmit(false, false, false, true);
		emit ChangedThreshold(SAFE_THRESHOLD - 1);
		electionModule.stepDownFromCouncil();

		assertFalse(safeProxy.isOwner(user1));
	}
}

contract StartSingleSeatElection is ElectionModuleTest {
	function test_RevertIf_HasOngoingElection() public {
		// we start a community election
		vm.warp(DEFAULT_START_TIME);
		vm.prank(user1);
		electionModule.startCommunityElection();

		vm.warp(DEFAULT_START_TIME + 1);
		vm.expectRevert(Error.ElectionAlreadyOngoing.selector);
		electionModule.startSingleSeatElection();
	}

	function test_RevertIf_NoAvailableCouncilSeat() public {
		vm.warp(DEFAULT_START_TIME);
		vm.expectRevert(Error.NoSeatAvailableInCouncil.selector);
		electionModule.startSingleSeatElection();
	}

	function test_EmitsElectionStartedEvent() public {
		// we call for a first replacement election
		vm.warp(DEFAULT_START_TIME);
		vm.startPrank(address(safeProxy));
		electionModule.startReplacementElection(user1);

		// we don't vote and wait for the election to be considered as Invalid
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);
		electionModule.finalizeElection();
		vm.stopPrank();

		vm.expectEmit(true, true, false, false);
		emit ElectionStarted(2, IElectionModule.ElectionType.Replacement);
		electionModule.startSingleSeatElection();
	}
}

contract NominateCandidate is ElectionModuleTest {
	function test_RevertIf_NoOngoingElection() public {
		vm.expectRevert(Error.ElectionFinalizedOrInvalid.selector);
		electionModule.nominateCandidate(user1);
	}

	function test_RevertIf_NotInNominationWindow() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// reverts after the nomination window
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		vm.expectRevert(Error.NotInNominationWindow.selector);
		electionModule.nominateCandidate(user1);
	}

	function test_RevertIf_CandidateAlreadyNominated() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate user1
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(user1);

		// we try to nominate user1 again
		vm.expectRevert(Error.CandidateAlreadyNominated.selector);
		electionModule.nominateCandidate(user1);
	}

	// only applicable for Replacement Election
	function test_RevertIf_CandidateAlreadyInCouncil() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		vm.prank(address(safeProxy));
		electionModule.startReplacementElection(user1);

		// user6 is already in council, so tx should revert
		vm.expectRevert(Error.CandidateAlreadyInCouncil.selector);
		electionModule.nominateCandidate(user6);
	}

	function test_EmitsCandidateNominatedEvent() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		vm.prank(user1);
		electionModule.startCommunityElection();

		// we nominate user1
		vm.warp(DEFAULT_START_TIME + 1);
		vm.expectEmit(true, true, false, false);
		emit CandidateNominated(1, user1);
		electionModule.nominateCandidate(user1);
	}

	function test_AddsCandidateInElectionStruc() public {
		// we start a new scheduled election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		assertTrue(electionModule.isElectionCandidate(1, user1) == false);

		// we nominate user1
		vm.warp(DEFAULT_START_TIME + 1);
		electionModule.nominateCandidate(user1);

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
		electionModule.nominateMultipleCandidates(candidates);

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
		electionModule.vote(user1);
	}

	function test_RevertIf_NotInVotingWindow() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we try to vote before the voting window
		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(user1);

		// we try to vote after the voting window
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION + 1);
		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(user1);
	}

	function test_RevertIf_NotInVotingWindowAfterCancelled() public {
		// we start an election
		vm.warp(DEFAULT_START_TIME);
		vm.prank(address(safeProxy));
		electionModule.startReplacementElection(user1);

		assertTrue(electionModule.hasOngoingElection());

		// we wait until the end of the nomination window to cancel
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		electionModule.cancelElection();

		assertFalse(electionModule.hasOngoingElection());

		// we are technically still in voting window
		// but since it has been cancelled it should revert
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);

		// we try to vote before the voting window
		vm.expectRevert(Error.NotInVotingWindow.selector);
		electionModule.vote(user1);
	}

	function test_RevertIf_AlreadyVoted() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		vm.startPrank(user1);
		electionModule.startCommunityElection();

		// we nominate a candidate
		electionModule.nominateCandidate(user1);

		// we vote twice
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		vm.startPrank(user1);
		electionModule.vote(user1);

		vm.expectRevert(Error.AlreadyVoted.selector);
		electionModule.vote(user1);
		vm.stopPrank();
	}

	function test_RevertIf_CandidateNotNominated() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate a candidate
		electionModule.nominateCandidate(user1);

		// we vote for another candidate
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		vm.startPrank(user1);
		vm.expectRevert(Error.CandidateNotNominated.selector);
		electionModule.vote(user2);
	}

	function test_RevertIf_VoterWasNotStaking() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		vm.prank(user1);
		electionModule.startCommunityElection();

		// we nominate a candidate
		electionModule.nominateCandidate(user1);

		// a user who wasn't staking votes for the candidate
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		vm.expectRevert(Error.CallerIsNotStaking.selector);
		electionModule.vote(user1);
	}

	function test_EmitsVoteRecordedEvent() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		// we nominate a candidate
		electionModule.nominateCandidate(user2);

		// we vote for the candidate
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW + 1);
		vm.startPrank(user1);
		vm.expectEmit(true, true, false, true);
		emit VoteRecorded(1, user1, user2);
		electionModule.vote(user2);
	}

	function test_UpdatesElectionStruc() public {
		// we start the election
		vm.warp(DEFAULT_START_TIME);
		vm.prank(address(safeProxy));
		electionModule.startReplacementElection(user1);

		assertTrue(electionModule.hasVoted(1, user1) == false);
		assertTrue(electionModule.hasVoted(1, user2) == false);
		assertTrue(electionModule.getElectionVotesForCandidate(1, user2) == 0);
		assertTrue(electionModule.getElectionTotalVotes(1) == 0);

		// we nominate a candidate
		electionModule.nominateCandidate(user2);

		// we vote for the candidate
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		vm.startPrank(user1);
		electionModule.vote(user2);

		assertTrue(electionModule.hasVoted(1, user1) == true);
		assertTrue(electionModule.getElectionVotesForCandidate(1, user2) == DEFAULT_STAKE_AMOUNT);
		assertTrue(electionModule.getElectionTotalVotes(1) == DEFAULT_STAKE_AMOUNT);

		// another user votes
		vm.startPrank(user2);
		electionModule.vote(user2);

		assertTrue(electionModule.hasVoted(1, user2) == true);
		assertTrue(electionModule.getElectionVotesForCandidate(1, user2) == 2 * DEFAULT_STAKE_AMOUNT);
		assertTrue(electionModule.getElectionTotalVotes(1) == 2 * DEFAULT_STAKE_AMOUNT);
	}

	function test_UpdatesWinnerListForScheduledElection() public {
		// we start a scheduled election and nominate the candidates
		generateNominations(IElectionModule.ElectionType.Scheduled);

		assertFalse(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 0);

		// we vote for user1
		vm.prank(user1);
		electionModule.vote(user1);

		assertTrue(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 1);

		// we vote for user2
		vm.prank(user2);
		electionModule.vote(user2);

		assertTrue(electionModule.isElectionWinner(1, user2));
		assertTrue(electionModule.getElectionWinners(1).length == 2);

		// we vote for user3
		vm.prank(user3);
		electionModule.vote(user3);

		assertTrue(electionModule.isElectionWinner(1, user3));
		assertTrue(electionModule.getElectionWinners(1).length == 3);

		// we vote for user4
		vm.prank(user4);
		electionModule.vote(user4);

		assertTrue(electionModule.isElectionWinner(1, user4));
		assertTrue(electionModule.getElectionWinners(1).length == 4);

		// we vote for user5
		vm.prank(user5);
		electionModule.vote(user5);

		assertTrue(electionModule.isElectionWinner(1, user5));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user6 but they don't get added to the winner list
		// as they get the exact same votes amount
		vm.prank(user6);
		electionModule.vote(user6);

		assertFalse(electionModule.isElectionWinner(1, user6));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user6 again, and they now replace user1 in the
		// winner list
		vm.startPrank(vm.addr(7));
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		electionModule.vote(user6);

		assertTrue(electionModule.isElectionWinner(1, user6));
		assertFalse(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user1 again, and they now replace user5 in the
		// winner list
		vm.startPrank(vm.addr(8));
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		electionModule.vote(user1);

		assertTrue(electionModule.isElectionWinner(1, user1));
		assertFalse(electionModule.isElectionWinner(1, user5));
		assertTrue(electionModule.getElectionWinners(1).length == 5);
	}

	function test_UpdatesWinnerListForCommunityElection() public {
		// we start a community election and nominate the candidates
		generateNominations(IElectionModule.ElectionType.Community);

		assertFalse(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 0);

		// we vote for user1
		vm.prank(user1);
		electionModule.vote(user1);

		assertTrue(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 1);

		// we vote for user2
		vm.prank(user2);
		electionModule.vote(user2);

		assertTrue(electionModule.isElectionWinner(1, user2));
		assertTrue(electionModule.getElectionWinners(1).length == 2);

		// we vote for user3
		vm.prank(user3);
		electionModule.vote(user3);

		assertTrue(electionModule.isElectionWinner(1, user3));
		assertTrue(electionModule.getElectionWinners(1).length == 3);

		// we vote for user4
		vm.prank(user4);
		electionModule.vote(user4);

		assertTrue(electionModule.isElectionWinner(1, user4));
		assertTrue(electionModule.getElectionWinners(1).length == 4);

		// we vote for user5
		vm.prank(user5);
		electionModule.vote(user5);

		assertTrue(electionModule.isElectionWinner(1, user5));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user6 but they don't get added to the winner list
		// as they get the exact same votes amount
		vm.prank(user6);
		electionModule.vote(user6);

		assertFalse(electionModule.isElectionWinner(1, user6));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user6 again, and they now replace user1 in the
		// winner list
		vm.startPrank(vm.addr(7));
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		electionModule.vote(user6);

		assertTrue(electionModule.isElectionWinner(1, user6));
		assertFalse(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 5);

		// we vote for user1 again, and they now replace user5 in the
		// winner list
		vm.startPrank(vm.addr(8));
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		electionModule.vote(user1);

		assertTrue(electionModule.isElectionWinner(1, user1));
		assertFalse(electionModule.isElectionWinner(1, user5));
		assertTrue(electionModule.getElectionWinners(1).length == 5);
	}

	function test_UpdatesWinnerListForReplacementElection() public {
		// we start a replacement election and nominates the candidates
		generateNominations(IElectionModule.ElectionType.Replacement);

		assertFalse(electionModule.isElectionWinner(1, user1));
		assertTrue(electionModule.getElectionWinners(1).length == 0);

		// we vote for user2
		vm.prank(user2);
		electionModule.vote(user2);

		assertTrue(electionModule.isElectionWinner(1, user2));
		assertTrue(electionModule.getElectionWinners(1).length == 1);

		// we vote for user3, which isn't added in the winner list
		// they've staked the same amount as user2
		vm.prank(user3);
		electionModule.vote(user3);

		assertFalse(electionModule.isElectionWinner(1, user3));
		assertTrue(electionModule.getElectionWinners(1).length == 1);

		// we now vote for user4 making sure they've staked more that the rest
		// before, so they can be in the winners list
		vm.startPrank(user4);
		stakingRewards.stake(DEFAULT_STAKE_AMOUNT);
		electionModule.vote(user4);

		assertTrue(electionModule.isElectionWinner(1, user4));
		assertTrue(electionModule.getElectionWinners(1).length == 1);

		vm.stopPrank();
	}
}

contract FinalizeEelection is ElectionModuleTest {
	function test_RevertIf_ElectionNotOngoing() public {
		// we try to finalize a election which wasn't started
		vm.warp(DEFAULT_START_TIME);
		vm.expectRevert(Error.ElectionFinalizedOrInvalid.selector);
		electionModule.finalizeElection();
	}

	function test_RevertIf_AlreadyFinalized() public {
		// we start an election and and we nominate enough candidates
		generateElection(IElectionModule.ElectionType.Scheduled);
		electionModule.finalizeElection();

		// we can't finalize it twice
		vm.expectRevert(Error.ElectionFinalizedOrInvalid.selector);
		electionModule.finalizeElection();
	}

	function testFuzz_RevertIf_NotElectionEndTime(uint256 _delay) public {
		vm.assume(_delay < ELECTION_DURATION);
		// we start an election and try to finalize it before the voting window ends
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();

		vm.warp(DEFAULT_START_TIME + _delay);
		vm.expectRevert(Error.ElectionNotReadyToBeFinalized.selector);
		electionModule.finalizeElection();
	}

	function test_CancelElectionIfNoCandidates() public {
		// we start an election and and we don't nominate enough candidates
		vm.warp(DEFAULT_START_TIME);
		vm.prank(user1);
		electionModule.startCommunityElection();

		electionModule.nominateCandidate(user1);
		electionModule.nominateCandidate(user2);
		electionModule.nominateCandidate(user3);

		// we close the voting window meaning the election is invalid
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);
		vm.expectEmit(true, false, false, false);
		emit ElectionCanceled(1);
		electionModule.finalizeElection();
	}

	function test_CancelElectionIfNoVotes() public {
		// we start an election and and we nominate enough candidates
		generateNominations(IElectionModule.ElectionType.Replacement);

		// we close the voting window meaning there are no votes
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);
		vm.expectEmit(true, false, false, false);
		emit ElectionCanceled(1);
		electionModule.finalizeElection();
	}

	function test_CancelElectionIfNoQuorum() public {
		// we start a community election
		generateElection(IElectionModule.ElectionType.Community);

		// we inflate supply of the stakingRewards contract to make sure all the votes don't reach quorum
		stakingRewards.inflateTotalSupply();

		// election should get cancelled
		vm.expectEmit(true, false, false, false);
		emit ElectionCanceled(1);
		electionModule.finalizeElection();
	}

	function test_FinalizeScheduledElection() public {
		assertTrue(electionModule.lastFinalizedScheduledElection() == 0);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Invalid);

		generateElection(IElectionModule.ElectionType.Scheduled);

		assertTrue(electionModule.lastFinalizedScheduledElection() == 0);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Ongoing);

		vm.expectEmit(true, false, false, false);
		emit ElectionFinalized(1);
		electionModule.finalizeElection();

		assertTrue(electionModule.lastFinalizedScheduledElection() == 1);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Finalized);
	}

	function test_FinalizeCommunityElection() public {
		assertTrue(electionModule.lastFinalizedScheduledElection() == 0);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Invalid);

		generateElection(IElectionModule.ElectionType.Community);

		assertTrue(electionModule.lastFinalizedScheduledElection() == 0);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Ongoing);

		vm.expectEmit(true, false, false, false);
		emit ElectionFinalized(1);
		electionModule.finalizeElection();

		assertTrue(electionModule.lastFinalizedScheduledElection() == 1);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Finalized);
	}

	function test_FinalizeReplacementElection() public {
		assertTrue(electionModule.lastFinalizedScheduledElection() == 0);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Invalid);

		generateElection(IElectionModule.ElectionType.Replacement);

		assertTrue(electionModule.lastFinalizedScheduledElection() == 0);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Ongoing);

		vm.expectEmit(true, false, false, false);
		emit ElectionFinalized(1);
		electionModule.finalizeElection();

		assertTrue(electionModule.lastFinalizedScheduledElection() == 1);
		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Finalized);
	}

	function test_InitiateNewCouncilAfterScheduledElection() public {
		// we check who are the current safe owners pre-election
		assertTrue(safeProxy.getOwners().length == 5);
		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user6));
		assertTrue(safeProxy.isOwner(vm.addr(10)));
		assertTrue(safeProxy.isOwner(vm.addr(11)));
		assertTrue(safeProxy.isOwner(vm.addr(12)));

		generateElection(IElectionModule.ElectionType.Scheduled);
		electionModule.finalizeElection();

		assertTrue(safeProxy.getOwners().length == 5);
		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user2));
		assertTrue(safeProxy.isOwner(user3));
		assertTrue(safeProxy.isOwner(user4));
		assertTrue(safeProxy.isOwner(user5));
	}

	function test_InitiateNewCouncilAfterCommunityElection() public {
		// we check who are the current safe owners pre-election
		assertTrue(safeProxy.getOwners().length == 5);
		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user6));
		assertTrue(safeProxy.isOwner(vm.addr(10)));
		assertTrue(safeProxy.isOwner(vm.addr(11)));
		assertTrue(safeProxy.isOwner(vm.addr(12)));

		generateElection(IElectionModule.ElectionType.Community);
		electionModule.finalizeElection();

		assertTrue(safeProxy.getOwners().length == 5);
		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user2));
		assertTrue(safeProxy.isOwner(user3));
		assertTrue(safeProxy.isOwner(user4));
		assertTrue(safeProxy.isOwner(user5));
	}

	function test_AddCouncilMemberAfterReplacementElection() public {
		// we check who are the current safe owners pre-election
		assertTrue(safeProxy.getOwners().length == 5);
		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user6));
		assertTrue(safeProxy.isOwner(vm.addr(10)));
		assertTrue(safeProxy.isOwner(vm.addr(11)));
		assertTrue(safeProxy.isOwner(vm.addr(12)));

		// we replace user1
		generateElection(IElectionModule.ElectionType.Replacement);

		assertFalse(safeProxy.isOwner(user1));

		electionModule.finalizeElection();

		assertTrue(safeProxy.getOwners().length == 5);
		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.isOwner(user2));
		assertTrue(safeProxy.isOwner(user6));
		assertTrue(safeProxy.isOwner(vm.addr(10)));
		assertTrue(safeProxy.isOwner(vm.addr(11)));
		assertTrue(safeProxy.isOwner(vm.addr(12)));
	}
}

contract CancelElection is ElectionModuleTest {
	function test_RevertIf_NotElection() public {
		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection();
	}

	function test_RevertIf_NotOngoing() public {
		// we start an election and cancel it because not enough candidates
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		electionModule.nominateCandidate(user1);
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		electionModule.cancelElection();

		// reverts because already set to Invalid
		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection();
	}

	function test_RevertIf_EnoughCandidatesAndVotes() public {
		// we start an election and and we nominate enough candidates
		generateNominations(IElectionModule.ElectionType.Scheduled);

		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection();

		// we vote for enough candidates
		vm.prank(user1);
		electionModule.vote(user1);
		vm.prank(user2);
		electionModule.vote(user2);
		vm.prank(user3);
		electionModule.vote(user3);
		vm.prank(user4);
		electionModule.vote(user4);
		vm.prank(user5);
		electionModule.vote(user5);

		// we close the voting window
		vm.warp(DEFAULT_START_TIME + ELECTION_DURATION);

		vm.expectRevert(Error.ElectionNotCancelable.selector);
		electionModule.cancelElection();
	}

	function test_EmitsElectionCanceledEvent() public {
		// we start an election and and we don't enough candidates
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		electionModule.nominateCandidate(user1);

		// we close the nomination window making the election cancelable
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		vm.expectEmit(true, false, false, false);
		emit ElectionCanceled(1);
		electionModule.cancelElection();
	}

	function test_UpdatesElectionStruc() public {
		// we start an election and and we don't enough candidates
		vm.warp(DEFAULT_START_TIME);
		electionModule.startScheduledElection();
		electionModule.nominateCandidate(user1);

		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Ongoing);

		// we close the nomination window making the election cancelable
		vm.warp(DEFAULT_START_TIME + NOMINATION_WINDOW);
		electionModule.cancelElection();

		assertTrue(electionModule.getElectionStatus(1) == IElectionModule.ElectionStatus.Invalid);
	}
}
