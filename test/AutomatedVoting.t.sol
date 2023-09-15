// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AutomatedVoting} from "../src/AutomatedVoting.sol";
import {IAutomatedVoting} from "../src/interfaces/IAutomatedVoting.sol";
import {StakingRewards} from "../lib/token/contracts/StakingRewards.sol";
import {Kwenta} from "../lib/token/contracts/Kwenta.sol";
import {RewardEscrow} from "../lib/token/contracts/RewardEscrow.sol";
import {AutomatedVotingInternals} from "./AutomatedVotingInternals.sol";
import {Enums} from "../src/Enums.sol";
import {DefaultStakingV2Setup} from "../lib/token/test/foundry/utils/setup/DefaultStakingV2Setup.t.sol";

contract AutomatedVotingTest is DefaultStakingV2Setup {
    AutomatedVoting public automatedVoting;
    AutomatedVotingInternals public automatedVotingInternals;
    address public admin;
    address public user6;
    uint256 public startTime;
    address[] public council;

    function setUp() public override {
        super.setUp();

        /// @dev this is so lastScheduledElectionStartTime is != 0
        vm.warp(block.timestamp + 25 weeks);
        admin = createUser();
        user6 = createUser();

        council = new address[](5);
        council[0] = user1;
        council[1] = user2;
        council[2] = user3;
        council[3] = user4;
        council[4] = user5;

        /// @dev set up council for automatedVoting and automatedVotingInternals
        automatedVoting = new AutomatedVoting(address(stakingRewardsV2));
        automatedVotingInternals = new AutomatedVotingInternals(
            address(stakingRewardsV2)
        );
        fundAccountAndStakeV2(admin, 1);
        vm.startPrank(admin);
        automatedVoting.startScheduledElection();
        automatedVotingInternals.startScheduledElection();
        automatedVoting.nominateMultipleCandidates(0, council);
        automatedVotingInternals.nominateMultipleCandidates(0, council);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.vote(0, user1);
        automatedVotingInternals.vote(0, user1);
        vm.warp(block.timestamp + 2 weeks);
        automatedVoting.finalizeElection(0);
        automatedVotingInternals.finalizeElection(0);
        vm.stopPrank();
    }

    // onlyCouncil()

    function testOnlyCouncilSuccess() public {
        vm.prank(user1);
        automatedVoting.stepDown();
    }

    function testOnlyCouncilFail() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotCouncil.selector)
        );
        automatedVoting.stepDown();
    }

    // onlyStaker()

    // onlyDuringNomination()

    function testOnlyDuringNominationAtStart() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
    }

    function testFuzzOnlyDuringNomination(uint128 time) public {
        vm.assume(time <= 1 weeks);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        vm.warp(block.timestamp + time);
        automatedVoting.nominateMultipleCandidates(1, council);
    }

    function testOnlyDuringNominationLastSecond() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
    }

    function testOnlyDuringNominationPassed() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks + 1);
        vm.startPrank(user1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateMultipleCandidates(1, new address[](5));
    }

    // onlyDuringVoting()

    function testOnlyDuringVotingAtStart() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.vote(1, user1);
    }

    function testFuzzOnlyDuringVoting(uint128 time) public {
        vm.assume(time <= 2 weeks);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.warp(block.timestamp + 1 weeks);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + time);
        automatedVoting.vote(1, user1);
    }

    function testOnlyDuringVotingLastSecond() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.warp(block.timestamp + 1 weeks);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 2 weeks);
        automatedVoting.vote(1, user1);
    }

    function testOnlyDuringVotingPassed() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 2 weeks + 1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.vote(1, user1);
    }

    function testOnlyDuringVotingNotVotingYet() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks - 1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.vote(1, user1);
    }

    // getCouncil()

    function testGetCouncil() public {
        address[] memory result = automatedVoting.getCouncil();
        assertEq(result.length, 5);
        assertEq(result[0], user1);
    }

    // timeUntilNextScheduledElection()

    function testTimeUntilNextScheduledElection() public {
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 21 weeks);
    }

    function testTimeUntilNextScheduledElectionOverdue() public {
        vm.warp(block.timestamp + 21 weeks);
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 0);
    }

    function testTimeUntilNextScheduledElectionRightBeforeOverdue() public {
        vm.warp(block.timestamp + 21 weeks - 1);
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 1);
    }

    function testFuzzTimeUntilNextScheduledElection(uint128 time) public {
        vm.assume(time < 21 weeks);
        vm.warp(block.timestamp + time);
        assertEq(
            automatedVoting.timeUntilNextScheduledElection(),
            21 weeks - time
        );
    }

    // timeUntilElectionStateEnd(1

    function testTimeUntilElectionStateEndNoElection() public {
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 0);
    }

    function testTimeUntilElectionStateEndNewScheduledElection() public {
        /// @dev warp forward 21 weeks to get past the cooldown
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks);
    }

    function testTimeUntilElectionStateEndFinishedElection() public {
        /// @dev warp forward 21 weeks to get past the cooldown
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks);
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 0);
    }

    function testTimeUntilElectionStateEndRightBeforeFinish() public {
        /// @dev warp forward 21 weeks to get past the cooldown
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks - 1);
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 1);
    }

    function testFuzzTimeUntilElectionStateEndNewScheduledElection(
        uint128 time
    ) public {
        vm.assume(time < 3 weeks);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks - time);
    }

    // isElectionFinalized()

    function testIsElectionFinalizedNoElection() public {
        assertEq(automatedVoting.isElectionFinalized(1), false);
    }

    function testIsElectionFinalizedNewElection() public {
        /// @dev warp forward 21 weeks to get past the cooldown
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.isElectionFinalized(1), false);
    }

    function testIsElectionFinalizedFinishedElection() public {
        /// @dev warp forward 21 weeks to get past the cooldown
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        /// @dev nominate so we can finalize and not get index out of bounds
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(1);
        assertEq(automatedVoting.isElectionFinalized(1), true);
    }

    // startScheduledElection()

    function testStartScheduledElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks);
        assertEq(
            automatedVoting.lastScheduledElectionStartTime(),
            block.timestamp
        );
        assertEq(automatedVoting.electionNumbers(), 2);
        (
            uint256 electionStartTime,
            uint256 stakedAmountsForQuorum,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(1);
        assertEq(electionStartTime, block.timestamp);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.scheduled);
        assertEq(stakedAmountsForQuorum, 0);
    }

    function testFuzzStartScheduledElectionNotReady(uint128 time) public {
        vm.assume(time < 21 weeks);
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startScheduledElection();
    }

    function testStartScheduledElectionNotReady() public {
        vm.warp(block.timestamp + 21 weeks - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startScheduledElection();
    }

    function testStartScheduledElectionLastElectionIsntFinalized() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        /// @dev nominate so we can finalize and not get index out of bounds
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 24 weeks);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startScheduledElection();
        automatedVoting.finalizeElection(1);
        automatedVoting.startScheduledElection();
    }

    function testFuzzStartScheduledElectionLastElectionIsntFinalized(
        uint128 time
    ) public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startScheduledElection();
    }

    function testStartScheduledElectionAndCancelStepDownElection() public {
        vm.prank(user1);
        automatedVoting.stepDown();
        assertEq(automatedVoting.isElectionFinalized(1), false);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.isElectionFinalized(1), true);
    }

    function testStartScheduledElectionAndCancelCommunityElection() public {
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.startCommunityElection();
        assertEq(automatedVoting.isElectionFinalized(1), false);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.isElectionFinalized(1), true);
    }

    // startCouncilElection()

    // startCommunityElection()

    function testStartCommunityElectionSuccess() public {
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.startCommunityElection();

        /// @dev check election
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks);
        assertEq(
            automatedVoting.lastScheduledElectionStartTime(),
            block.timestamp - 3 weeks
        );
        assertEq(automatedVoting.electionNumbers(), 2);
        (
            uint256 electionStartTime,
            uint256 stakedAmountsForQuorum,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(1);
        assertEq(electionStartTime, block.timestamp);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.community);
        assertEq(stakedAmountsForQuorum, 0);
    }

    function testStartCommunityElectionNotStaked() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.startCommunityElection();
    }

    function testStartCommunityElectionNotReadyToStart() public {
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.startCommunityElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startCommunityElection();
    }

    function testFuzzStartCommunityElectionNotReadyToStart(uint time) public {
        vm.assume(time < 3 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.startCommunityElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startCommunityElection();
    }

    function testStartCommunityElectionImmediatelyAfterCooldown() public {
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.startCommunityElection();
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.startCommunityElection();
    }

    function testStartCommunityElectionScheduledElectionJustStarted() public {
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ScheduledElectionInProgress.selector
            )
        );
        automatedVoting.startCommunityElection();
    }

    function testFuzzStartCommunityElectionDuringScheduledElection(
        uint128 time
    ) public {
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ScheduledElectionInProgress.selector
            )
        );
        automatedVoting.startCommunityElection();
    }

    function testStartCommunityElectionScheduledElectionJustEnded() public {
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        /// @dev nominate so we can finalize and not get index out of bounds
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.finalizeElection(1);
        automatedVoting.startCommunityElection();
    }

    // stepDown()

    function testStepDownSuccess() public {
        vm.prank(user1);
        automatedVoting.stepDown();

        assertFalse(automatedVoting.isCouncilMember(user1));
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks);
        assertEq(automatedVoting.electionNumbers(), 2);
        (
            uint256 electionStartTime,
            uint256 stakedAmountsForQuorum,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(1);
        assertEq(electionStartTime, block.timestamp);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.single);
        assertEq(stakedAmountsForQuorum, 0);

        council = automatedVoting.getCouncil();
        assertEq(council.length, 5);
        assertEq(council[0], address(0));
        assertEq(council[1], user2);
        assertEq(council[2], user3);
        assertEq(council[3], user4);
        assertEq(council[4], user5);
    }

    function testStepDownNotCouncil() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotCouncil.selector)
        );
        automatedVoting.stepDown();
    }

    function testEveryoneCanStepDown() public {
        vm.prank(user1);
        automatedVoting.stepDown();
        vm.prank(user3);
        automatedVoting.stepDown();
        vm.prank(user4);
        automatedVoting.stepDown();
        vm.prank(user5);
        automatedVoting.stepDown();
        vm.prank(user2);
        automatedVoting.stepDown();
    }

    function testStepDownScheduledElectionJustStarted() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ScheduledElectionInProgress.selector
            )
        );
        vm.prank(user1);
        automatedVoting.stepDown();
    }

    function testFuzzStepDownDuringScheduledElection(uint128 time) public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ScheduledElectionInProgress.selector
            )
        );
        vm.prank(user1);
        automatedVoting.stepDown();
    }

    function testStepDownScheduledElectionJustEnded() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        /// @dev nominate so we can finalize and not get index out of bounds
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.finalizeElection(1);
        automatedVoting.stepDown();
    }

    // finalizeElection()

    function testFinalizeElectionAlreadyFinalized() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        /// @dev nominate so we can finalize and not get index out of bounds
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.finalizeElection(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionAlreadyFinalized.selector
            )
        );
        automatedVoting.finalizeElection(1);
    }

    function testFinalizeElection() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        /// @dev nominate so we can finalize and not get index out of bounds
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.finalizeElection(1);
        assertEq(automatedVoting.isElectionFinalized(1), true);
    }

    function testFuzzFinalizeElectionNotReady(uint128 time) public {
        vm.assume(time < 3 weeks);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeFinalized.selector
            )
        );
        automatedVoting.finalizeElection(1);
    }

    function testFinalizeElectionNotReady() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeFinalized.selector
            )
        );
        automatedVoting.finalizeElection(1);
    }

    // nominateCandidate()

    function testNominateInSingleElectionSuccess() public {
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user2);
        automatedVoting.stepDown();

        vm.startPrank(user1);
        automatedVoting.nominateCandidate(1, user6);
        assertEq(automatedVoting.getIsNominated(1, user6), true);
        /// @dev sanity check
        assertEq(automatedVoting.getIsNominated(1, user1), false);
    }

    function testNominateInSingleElectionNotStaked() public {
        vm.warp(block.timestamp + 21 weeks);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CallerWasNotStakedBeforeElectionStart.selector
            )
        );
        automatedVoting.nominateCandidate(1, user1);
    }

    function testNominateInSingleElectionNotDuringNomination() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.warp(block.timestamp + 1 weeks + 1);
        vm.prank(user1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateCandidate(1, user1);
    }

    function testNominateInSingleElectionAlreadyMember() public {
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CandidateIsAlreadyCouncilMember.selector
            )
        );
        vm.startPrank(user1);
        automatedVoting.nominateCandidate(1, user1);
    }

    // voteInSingleElection()

    function testVoteInSingleElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user2);
        automatedVoting.stepDown();

        vm.startPrank(user1);
        automatedVoting.nominateCandidate(1, user6);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.vote(1, user6);
        assertEq(automatedVoting.getVoteCounts(1, user6), 1);
        assertEq(automatedVoting.getVoteCounts(1, user1), 0);
        assertTrue(automatedVoting.getIsNominated(1, user6));
        assertFalse(automatedVoting.getIsNominated(1, user1));
        assertTrue(automatedVoting.getHasVoted(1, user1));
        assertFalse(automatedVoting.getHasVoted(1, user6));
    }

    function testVoteInSingleElectionNotStaked() public {
        vm.warp(block.timestamp + 21 weeks);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CallerWasNotStakedBeforeElectionStart.selector
            )
        );
        automatedVoting.vote(1, user1);
    }

    function testVoteInSingleElectionNotDuringVoting() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user2);
        automatedVoting.stepDown();

        vm.expectRevert("Election not in voting state");
        vm.prank(user1);
        automatedVoting.vote(1, user1);
    }

    function testVoteInSingleElectionAlreadyEnded() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.warp(block.timestamp + 3 weeks + 1);
        vm.startPrank(user1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.vote(1, user1);
    }

    function testVoteInSingleElectionAlreadyVoted() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user2);
        automatedVoting.stepDown();

        vm.startPrank(user1);
        automatedVoting.nominateCandidate(1, user6);
        vm.warp(block.timestamp + 1 weeks + 1);
        automatedVoting.vote(1, user6);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        automatedVoting.vote(1, user6);
    }

    function testVoteInSingleElectionCandidateNotNominated() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.warp(block.timestamp + 1 weeks + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CandidateNotNominated.selector
            )
        );
        vm.prank(user1);
        automatedVoting.vote(1, user1);
    }

    // nominateMultipleCandidates()

    function testNominateInFullElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);

        assertEq(automatedVoting.getCandidateAddress(1, 0), user1);
        assertEq(automatedVoting.getCandidateAddress(1, 1), user2);
        assertEq(automatedVoting.getCandidateAddress(1, 2), user3);
        assertEq(automatedVoting.getCandidateAddress(1, 3), user4);
        assertEq(automatedVoting.getCandidateAddress(1, 4), user5);
        assertTrue(automatedVoting.getIsNominated(1, user1));
        assertTrue(automatedVoting.getIsNominated(1, user2));
        assertTrue(automatedVoting.getIsNominated(1, user3));
        assertTrue(automatedVoting.getIsNominated(1, user4));
        assertTrue(automatedVoting.getIsNominated(1, user5));
    }

    function testNominateInFullElectionNotStaked() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CallerWasNotStakedBeforeElectionStart.selector
            )
        );
        automatedVoting.nominateMultipleCandidates(1, council);
    }

    function testNominateInFullElectionNotElection() public {
        vm.warp(block.timestamp + 23 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CallerWasNotStakedBeforeElectionStart.selector
            )
        );
        automatedVoting.nominateMultipleCandidates(1, new address[](5));
    }

    function testNominateInFullElectionNominatingEnded() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.warp(block.timestamp + 1 weeks + 1);
        vm.startPrank(user1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateMultipleCandidates(1, new address[](5));
    }

    // vote()

    function testVoteInScheduledElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);

        assertEq(automatedVoting.getCandidateAddress(1, 0), user1);
        assertEq(automatedVoting.getCandidateAddress(1, 1), user2);
        assertEq(automatedVoting.getCandidateAddress(1, 2), user3);
        assertEq(automatedVoting.getCandidateAddress(1, 3), user4);
        assertEq(automatedVoting.getCandidateAddress(1, 4), user5);

        automatedVoting.vote(1, user1);

        /// @dev make sure voting didnt change the order
        assertEq(automatedVoting.getCandidateAddress(1, 0), user1);
        assertEq(automatedVoting.getCandidateAddress(1, 1), user2);
        assertEq(automatedVoting.getCandidateAddress(1, 2), user3);
        assertEq(automatedVoting.getCandidateAddress(1, 3), user4);
        assertEq(automatedVoting.getCandidateAddress(1, 4), user5);

        assertEq(automatedVoting.getVoteCounts(1, user1), 1);
    }

    function testVoteInScheduledElectionNotStaked() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CallerWasNotStakedBeforeElectionStart.selector
            )
        );
        vm.startPrank(user1);
        automatedVoting.vote(1, user1);
    }

    function testVoteInScheduledElectionNotElection() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        /// @dev when there is no election, this is the error that is thrown
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CallerWasNotStakedBeforeElectionStart.selector
            )
        );
        automatedVoting.vote(1, user1);
    }

    function testVoteInScheduledElectionAlreadyEnded() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.warp(block.timestamp + 3 weeks + 1);
        vm.startPrank(user1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.vote(1, user1);
    }

    function testVoteInScheduledElectionAlreadyVoted() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVoting.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.vote(1, user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        automatedVoting.vote(1, user1);
    }

    function testVoteInScheduledElectionCandidateNotNominated() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 weeks);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CandidateNotNominated.selector
            )
        );
        automatedVoting.vote(1, user1);
    }

    // isCouncilMember()

    function testIsCouncilMember() public {
        assertEq(automatedVoting.isCouncilMember(user1), true);
    }

    function testIsNotCouncilMember() public {
        assertEq(automatedVoting.isCouncilMember(address(0x2)), false);
    }

    // _isStaker()

    // _checkIfQuorumReached()

    // _finalizeElection()

    function testFinalizeElectionInternal() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        council[0] = user6;
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);
        automatedVotingInternals.vote(1, user6);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVotingInternals.finalizeElectionInternal(1);
        assertEq(automatedVotingInternals.isElectionFinalized(1), true);

        /// @dev check if the council changed
        assertEq(automatedVotingInternals.getCouncil(), council);
    }

    function testFinalizeElectionInternalStepDown() public {
        vm.warp(block.timestamp + 21 weeks);
        fundAccountAndStakeV2(user1, 1);
        vm.prank(user2);
        automatedVotingInternals.stepDown();
        vm.startPrank(user1);
        automatedVotingInternals.nominateCandidate(1, user6);
        vm.warp(block.timestamp + 1 weeks);
        automatedVotingInternals.vote(1, user6);
        automatedVotingInternals.getVoteCounts(1, user6);

        address[] memory councilBefore = automatedVotingInternals.getCouncil();
        assertEq(councilBefore.length, 5);
        assertEq(councilBefore[0], user1);
        assertEq(councilBefore[1], address(0));
        assertEq(councilBefore[2], user3);
        assertEq(councilBefore[3], user4);
        assertEq(councilBefore[4], user5);
        assertEq(automatedVotingInternals.isElectionFinalized(1), false);
        automatedVotingInternals.finalizeElectionInternal(1);
        assertEq(automatedVotingInternals.isElectionFinalized(1), true);
        address[] memory councilAfter = automatedVotingInternals.getCouncil();
        assertEq(councilAfter.length, 5);
        assertEq(councilAfter[0], user1);
        assertEq(councilAfter[1], user6);
        assertEq(councilAfter[2], user3);
        assertEq(councilAfter[3], user4);
        assertEq(councilAfter[4], user5);
    }

    // _sortCandidates()

    function testSortCandidatesPositionStaysAtIndex0() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        
        assertEq(automatedVotingInternals.getCandidateAddress(1, 0), user1);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 1), user2);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 2), user3);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 3), user4);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 4), user5);

        address[] memory result = automatedVotingInternals.sortCandidates(1, user1, 1);

        /// @dev make sure voting didnt change the order
        assertEq(result[0], user1);
        assertEq(result[1], user2);
        assertEq(result[2], user3);
        assertEq(result[3], user4);
        assertEq(result[4], user5);

    }

    function testSortCandidatesPositionChangesFromLastToIndex0() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        
        assertEq(automatedVotingInternals.getCandidateAddress(1, 0), user1);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 1), user2);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 2), user3);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 3), user4);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 4), user5);

        address[] memory result = automatedVotingInternals.sortCandidates(1, user5, 1);

        /// @dev make last place went to first place
        assertEq(result[0], user5);
        assertEq(result[1], user1);
        assertEq(result[2], user2);
        assertEq(result[3], user3);
        assertEq(result[4], user4);
    }

    function testSortCandidatesPositionChangesFromIndex3ToIndex1() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        fundAccountAndStakeV2(user2, 1);
        fundAccountAndStakeV2(user3, 1);
        fundAccountAndStakeV2(user4, 1);
        fundAccountAndStakeV2(user5, 1);
        vm.prank(user1);
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(user1);
        automatedVotingInternals.vote(1, user1);

        assertEq(automatedVotingInternals.getCandidateAddress(1, 0), user1);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 1), user2);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 2), user3);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 3), user4);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 4), user5);

        address[] memory result = automatedVotingInternals.sortCandidates(1, user4, 1);

        /// @dev make sure index 3 went to index 1 then shifted
        assertEq(result[0], user1);
        assertEq(result[1], user4);
        assertEq(result[2], user2);
        assertEq(result[3], user3);
        assertEq(result[4], user5);
    }

    function testSortCandidatesPositionChangesFromIndex2ToIndex1() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        fundAccountAndStakeV2(user2, 1);
        fundAccountAndStakeV2(user3, 1);
        fundAccountAndStakeV2(user4, 1);
        fundAccountAndStakeV2(user5, 1);
        vm.prank(user1);
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(user1);
        automatedVotingInternals.vote(1, user1);

        assertEq(automatedVotingInternals.getCandidateAddress(1, 0), user1);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 1), user2);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 2), user3);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 3), user4);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 4), user5);

        address[] memory result = automatedVotingInternals.sortCandidates(1, user3, 1);

        /// @dev make sure index 2 went to index 1 then shifted
        assertEq(result[0], user1);
        assertEq(result[1], user3);
        assertEq(result[2], user2);
        assertEq(result[3], user4);
        assertEq(result[4], user5);
    }

    function testSortCandidatesPositionChangesFromIndex4ToIndex3() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        fundAccountAndStakeV2(user2, 1);
        fundAccountAndStakeV2(user3, 1);
        fundAccountAndStakeV2(user4, 1);
        fundAccountAndStakeV2(user5, 1);
        vm.prank(user1);
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(user1);
        automatedVotingInternals.vote(1, user1);
        vm.prank(user2);
        automatedVotingInternals.vote(1, user2);
        vm.prank(user3);
        automatedVotingInternals.vote(1, user3);

        assertEq(automatedVotingInternals.getCandidateAddress(1, 0), user1);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 1), user2);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 2), user3);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 3), user4);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 4), user5);

        address[] memory result = automatedVotingInternals.sortCandidates(1, user5, 1);

        /// @dev make sure index 4 swapped with 3
        assertEq(result[0], user1);
        assertEq(result[1], user2);
        assertEq(result[2], user3);
        assertEq(result[3], user5);
        assertEq(result[4], user4);
    }

    function testSortCandidatesPositionChangesFromIndex4ToIndex2() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        fundAccountAndStakeV2(user2, 1);
        fundAccountAndStakeV2(user3, 1);
        fundAccountAndStakeV2(user4, 1);
        fundAccountAndStakeV2(user5, 1);
        vm.prank(user1);
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(user1);
        automatedVotingInternals.vote(1, user1);
        vm.prank(user2);
        automatedVotingInternals.vote(1, user2);

        assertEq(automatedVotingInternals.getCandidateAddress(1, 0), user1);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 1), user2);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 2), user3);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 3), user4);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 4), user5);

        address[] memory result = automatedVotingInternals.sortCandidates(1, user5, 1);

        /// @dev make sure index 4 swapped with 2
        assertEq(result[0], user1);
        assertEq(result[1], user2);
        assertEq(result[2], user5);
        assertEq(result[3], user3);
        assertEq(result[4], user4);
    }

    function testSortCandidatesPositionStaysAtIndex4() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        fundAccountAndStakeV2(user2, 1);
        fundAccountAndStakeV2(user3, 1);
        fundAccountAndStakeV2(user4, 1);
        fundAccountAndStakeV2(user5, 1);
        vm.prank(user1);
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(user1);
        automatedVotingInternals.vote(1, user1);
        vm.prank(user2);
        automatedVotingInternals.vote(1, user2);
        vm.prank(user3);
        automatedVotingInternals.vote(1, user3);
        vm.prank(user4);
        automatedVotingInternals.vote(1, user4);

        assertEq(automatedVotingInternals.getCandidateAddress(1, 0), user1);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 1), user2);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 2), user3);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 3), user4);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 4), user5);

        address[] memory result = automatedVotingInternals.sortCandidates(1, user5, 1);

        /// @dev make sure index 4 doesnt move
        assertEq(result[0], user1);
        assertEq(result[1], user2);
        assertEq(result[2], user3);
        assertEq(result[3], user4);
        assertEq(result[4], user5);
    }

    function testSortCandidatesPositionStaysAtIndex3() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVotingInternals.startScheduledElection();
        fundAccountAndStakeV2(user1, 1);
        fundAccountAndStakeV2(user2, 1);
        fundAccountAndStakeV2(user3, 1);
        fundAccountAndStakeV2(user4, 1);
        fundAccountAndStakeV2(user5, 1);
        vm.prank(user1);
        automatedVotingInternals.nominateMultipleCandidates(1, council);
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(user1);
        automatedVotingInternals.vote(1, user1);
        vm.prank(user2);
        automatedVotingInternals.vote(1, user2);
        vm.prank(user3);
        automatedVotingInternals.vote(1, user3);

        assertEq(automatedVotingInternals.getCandidateAddress(1, 0), user1);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 1), user2);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 2), user3);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 3), user4);
        assertEq(automatedVotingInternals.getCandidateAddress(1, 4), user5);

        address[] memory result = automatedVotingInternals.sortCandidates(1, user4, 1);

        /// @dev make sure index 3 doesnt move
        assertEq(result[0], user1);
        assertEq(result[1], user2);
        assertEq(result[2], user3);
        assertEq(result[3], user4);
        assertEq(result[4], user5);
    }

    // _cancelOngoingElections()

    function testCancelOngoingElectionsStepDown() public {
        vm.prank(user1);
        automatedVotingInternals.stepDown();
        assertEq(automatedVotingInternals.isElectionFinalized(1), false);
        vm.prank(user2);
        automatedVotingInternals.stepDown();
        assertEq(automatedVotingInternals.isElectionFinalized(2), false);
        (, , , Enums.electionType theElectionType) = automatedVotingInternals
            .elections(1);
        assertTrue(theElectionType == Enums.electionType.single);
        automatedVotingInternals.cancelOngoingElectionsInternal();
        assertEq(automatedVotingInternals.isElectionFinalized(1), true);
        assertEq(automatedVotingInternals.isElectionFinalized(2), true);
    }

    function testCancelOngoingElectionsCommunity() public {
        fundAccountAndStakeV2(user1, 1);
        vm.startPrank(user1);
        automatedVotingInternals.startCommunityElection();
        assertEq(automatedVotingInternals.isElectionFinalized(1), false);
        (, , , Enums.electionType theElectionType) = automatedVotingInternals
            .elections(1);
        assertTrue(theElectionType == Enums.electionType.community);
        automatedVotingInternals.cancelOngoingElectionsInternal();
        assertEq(automatedVotingInternals.isElectionFinalized(1), true);
    }

    //todo: test everything with when a non-existent election is put in

    //todo: test elections 1ike Community reelection for when another re-election
    // is started right at 3 weeks end but the first election is not finalized yet
}
