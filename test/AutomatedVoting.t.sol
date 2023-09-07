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

contract AutomatedVotingTest is Test {
    AutomatedVoting public automatedVoting;
    AutomatedVotingInternals public automatedVotingInternals;
    StakingRewards public stakingRewards;
    Kwenta public kwenta;
    RewardEscrow public rewardEscrow;
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;
    address public user6;
    uint256 public userNonce;
    uint256 public startTime;

    function setUp() public {
        /// @dev this is so lastScheduledElectionStartTime is != 0
        vm.warp(block.timestamp + 25 weeks);
        admin = createUser();
        user1 = createUser();
        user2 = createUser();
        user3 = createUser();
        user4 = createUser();
        user5 = createUser();
        user6 = createUser();
        kwenta = new Kwenta("Kwenta", "Kwe", 100_000, admin, address(this));
        rewardEscrow = new RewardEscrow(admin, address(kwenta));
        stakingRewards = new StakingRewards(
            address(kwenta),
            address(rewardEscrow),
            address(this)
        );
        address[] memory council = new address[](5);
        council[0] = user1;
        council[1] = user2;
        council[2] = user3;
        council[3] = user4;
        council[4] = user5;

        /// @dev set up council for automatedVoting and automatedVotingInternals
        automatedVoting = new AutomatedVoting(address(stakingRewards));
        automatedVotingInternals = new AutomatedVotingInternals(address(stakingRewards));
        kwenta.transfer(admin, 1);
        vm.startPrank(admin);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(0, council);
        automatedVotingInternals.nominateInFullElection(0, council);
        vm.warp(block.timestamp + 1 weeks);
        automatedVotingInternals.voteInFullElection(0, council);
        automatedVoting.voteInFullElection(0, council);
        vm.warp(block.timestamp + 2 weeks);
        automatedVotingInternals.finalizeElection(0);
        automatedVoting.finalizeElection(0);      
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
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(1, new address[](5));
    }

    function testFuzzOnlyDuringNomination(uint128 time) public {
        vm.assume(time <= 1 weeks);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.warp(block.timestamp + time);
        automatedVoting.nominateInFullElection(1, new address[](5));
    }

    function testOnlyDuringNominationLastSecond() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(1, new address[](5));
    }

    function testOnlyDuringNominationPassed() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(1, new address[](5));
    }

    function testOnlyDuringNominationNoElectionYet() public {
        vm.warp(block.timestamp + 23 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(1, new address[](5));
    }

    // onlyDuringVoting()

    function testOnlyDuringVotingAtStart() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(1, new address[](5));
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(1, new address[](5));
    }

    function testFuzzOnlyDuringVoting(uint128 time) public {
        vm.assume(time <= 2 weeks);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        automatedVoting.nominateInFullElection(1, new address[](5));
        vm.warp(block.timestamp + time);
        automatedVoting.voteInFullElection(1, new address[](5));
    }

    function testOnlyDuringVotingLastSecond() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        automatedVoting.nominateInFullElection(1, new address[](5));
        vm.warp(block.timestamp + 2 weeks);
        automatedVoting.voteInFullElection(1, new address[](5));
    }

    function testOnlyDuringVotingPassed() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.nominateInFullElection(1, new address[](5));
        vm.warp(block.timestamp + 2 weeks + 1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInFullElection(1, new address[](5));
    }

    function testOnlyDuringVotingNotVotingYet() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        automatedVoting.nominateInFullElection(1, new address[](5));
        vm.warp(block.timestamp + 1 weeks - 1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInFullElection(1, new address[](5));
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

    // isElectionFinalized(1

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
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(1);
        assertEq(automatedVoting.isElectionFinalized(1), true);
    }

    // startScheduledElection()

    function testStartScheduledElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks);
        assertEq(automatedVoting.lastScheduledElectionStartTime(), block.timestamp);
        assertEq(automatedVoting.electionNumbers(1), 1);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(1);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.scheduled);
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

    function testFuzzStartScheduledElectionLastElectionIsntFinalized(uint128 time) public {
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

    function testStartScheduledElectionAndCancelCKIPElection() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();
        assertEq(automatedVoting.isElectionFinalized(1), false);
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.isElectionFinalized(1), true);
    }

    function testStartScheduledElectionAndCancelCouncilState() public {
        address[] memory membersUpForRemoval = automatedVoting.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 0);
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
        membersUpForRemoval = automatedVoting.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 1);
        assertEq(membersUpForRemoval[0], user5);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user1, user5), true);
        assertEq(automatedVoting.removalVotes(user5), 1);
        vm.prank(user2);
        automatedVoting.startCouncilElection(user5);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user2, user5), true);
        assertEq(automatedVoting.removalVotes(user5), 2);
        /// @dev user 3 doesnt vote for user5, so user5 isnt booted
        vm.prank(user3);
        automatedVoting.startCouncilElection(user1);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user3, user5), false);
        assertEq(automatedVoting.removalVotes(user5), 2);    
        membersUpForRemoval = automatedVoting.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 2);
        assertEq(membersUpForRemoval[1], user1);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user3, user1), true);
        assertEq(automatedVoting.removalVotes(user1), 1); 

        /// @dev start scheduled election so everything should be clear but the council stays the same
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();

        /// @dev check accounting
        membersUpForRemoval = automatedVoting.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 2);
        assertEq(membersUpForRemoval[0], address(0));
        assertEq(membersUpForRemoval[1], address(0));
        assertEq(automatedVoting.isCouncilMember(user5), true);
        assertEq(automatedVoting.isCouncilMember(user1), true);
        assertEq(automatedVoting.removalVotes(user5), 0);
        assertEq(automatedVoting.removalVotes(user1), 0);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user1, user5), false);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user2, user5), false);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user3, user1), false);
    }

    function testStartScheduledElectionAndCancelCouncilElection() public {
        
    }

    // startCouncilElection()

    function testStartCouncilElectionSuccess() public {
        address[] memory membersUpForRemoval = automatedVoting.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 0);
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
        membersUpForRemoval = automatedVoting.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 1);
        assertEq(membersUpForRemoval[0], user5);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user1, user5), true);
        assertEq(automatedVoting.removalVotes(user5), 1);
        vm.prank(user2);
        automatedVoting.startCouncilElection(user5);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user2, user5), true);
        assertEq(automatedVoting.removalVotes(user5), 2);
        /// @dev member is booted after the third vote, election starts, and accounting is cleared
        vm.prank(user3);
        automatedVoting.startCouncilElection(user5);
        
        /// @dev check accounting
        membersUpForRemoval = automatedVoting.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 1);
        assertEq(membersUpForRemoval[0], address(0));
        assertEq(automatedVoting.isCouncilMember(user5), false);
        assertEq(automatedVoting.removalVotes(user5), 0);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user1, user5), false);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user2, user5), false);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user3, user5), false);

        /// @dev check election
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks);
        assertEq(automatedVoting.lastScheduledElectionStartTime(), block.timestamp - 3 weeks);
        assertEq(automatedVoting.electionNumbers(1), 1);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(1);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.council);
    }

    function testStartCouncilElectionNotCouncil() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotCouncil.selector)
        );
        automatedVoting.startCouncilElection(user5);
    }

    function testStartCouncilElectionMemeberToRemoveNotOnCoucil() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.MemberNotOnCouncil.selector
            )
        );
        automatedVoting.startCouncilElection(address(this));
    }

    function testStartCouncilElectionAlreadyVoted() public {
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
    }

    function testStartCouncilElectionScheduledElectionJustStarted() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ScheduledElectionInProgress.selector
            )
        );
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
    }

    function testFuzzStartCouncilElectionDuringScheduledElection(uint128 time) public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ScheduledElectionInProgress.selector
            )
        );
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
    }

    function testStartCouncilElectionScheduledElectionJustEnded() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        automatedVoting.nominateInFullElection(1, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(1, candidates);
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.finalizeElection(1);
        automatedVoting.startCouncilElection(user5);
    }

    // startCKIPelection()

    function testStartCKIPElectionSuccess() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();

        /// @dev check election
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks);
        assertEq(automatedVoting.lastScheduledElectionStartTime(), block.timestamp - 3 weeks);
        assertEq(automatedVoting.electionNumbers(1), 1);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(1);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.CKIP);
    }

    function testStartCKIPElectionNotStaked() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.startCKIPElection();
    }

    function testStartCKIPElectionNotReadyToStart() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startCKIPElection();
    }

    function testFuzzStartCKIPElectionNotReadyToStart(uint time) public {
        vm.assume(time < 3 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startCKIPElection();
    }

    function testStartCKIPElectionImmediatelyAfterCooldown() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.startCKIPElection();
    }

    function testStartCKIPElectionScheduledElectionJustStarted() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ScheduledElectionInProgress.selector
            )
        );
        automatedVoting.startCKIPElection();
    }

    function testFuzzStartCKIPElectionDuringScheduledElection(uint128 time) public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ScheduledElectionInProgress.selector
            )
        );
        automatedVoting.startCKIPElection();
    }

    function testStartCKIPElectionScheduledElectionJustEnded() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.finalizeElection(1);
        automatedVoting.startCKIPElection();
    }

    // stepDown()

    function testStepDownSuccess() public {
        vm.prank(user1);
        automatedVoting.stepDown();

        assertFalse(automatedVoting.isCouncilMember(user1));
        assertEq(automatedVoting.timeUntilElectionStateEnd(1), 3 weeks);
        assertEq(automatedVoting.electionNumbers(1), 1);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(1);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.stepDown);

        address[] memory council = automatedVoting.getCouncil();
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

    function testStepDownCannotStepDown() public {
        vm.prank(user1);
        automatedVoting.stepDown();
        vm.prank(user3);
        automatedVoting.stepDown();
        vm.prank(user4);
        automatedVoting.stepDown();
        vm.prank(user5);
        automatedVoting.stepDown();
        /// @dev cant step down because they are last member
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CouncilMemberCannotStepDown.selector
            )
        );
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
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        automatedVoting.nominateInFullElection(1, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(1, candidates);
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.finalizeElection(1);
        automatedVoting.stepDown();
    }

    // finalizeElection()

    function testFinalizeElectionAlreadyFinalized() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
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

    // nominateInSingleElection(1

    function testNominateInSingleElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();

        automatedVoting.nominateInSingleElection(1, user1);
        assertEq(automatedVoting.isNominated(0, user1), true);
    }

    function testNominateInSingleElectionNotStaked() public {
        vm.warp(block.timestamp + 21 weeks);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.nominateInSingleElection(1, user1);
    }

    function testNominateInSingleElectionNotDuringNomination() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.warp(block.timestamp + 1 weeks + 1);
        
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInSingleElection(1, user1);
    }

    function testNominateInSingleElectionNotSingleElection() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        
        vm.expectRevert("Election not a single election");
        automatedVoting.nominateInSingleElection(1, user1);
    }

    // voteInSingleElection()

    function testVoteInSingleElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();

        automatedVoting.nominateInSingleElection(1, user1);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInSingleElection(1, user1);
        assertEq(automatedVoting.voteCounts(1, user1), 1);
    }

    function testVoteInSingleElectionNotStaked() public {
        vm.warp(block.timestamp + 21 weeks);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.voteInSingleElection(1, user1);
    }

    function testVoteInSingleElectionNotDuringVoting() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();

        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInSingleElection(1, user1);
    }

    function testVoteInSingleElectionAlreadyEnded() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInSingleElection(1, user1);
    }

    function testVoteInSingleElectionNotSingleElection() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.warp(block.timestamp + 1 weeks + 1);

        vm.expectRevert("Election not a single election");
        automatedVoting.voteInSingleElection(1, user1);
    }

    function testVoteInSingleElectionAlreadyVoted() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 2);
        kwenta.approve(address(stakingRewards), 2);
        stakingRewards.stake(2);
        vm.prank(user2);
        automatedVoting.stepDown();

        automatedVoting.nominateInSingleElection(1, user1);
        vm.warp(block.timestamp + 1 weeks + 1);
        automatedVoting.voteInSingleElection(1, user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        automatedVoting.voteInSingleElection(1, user1);
    }

    function testVoteInSingleElectionCandidateNotNominated() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 2);
        kwenta.approve(address(stakingRewards), 2);
        stakingRewards.stake(2);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.warp(block.timestamp + 1 weeks + 1);
        
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CandidateNotNominated.selector)
        );
        automatedVoting.voteInSingleElection(1, user1);
    }

    // nominateInFullElection()

    function testNominateInFullElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        automatedVoting.nominateInFullElection(1, candidates);

        //todo: check the candidateAddresses array
        assertEq(automatedVoting.isNominated(0, user1), true);
        assertEq(automatedVoting.isNominated(0, user2), true);
        assertEq(automatedVoting.isNominated(0, user3), true);
        assertEq(automatedVoting.isNominated(0, user4), true);
        assertEq(automatedVoting.isNominated(0, user5), true);
    }

    function testNominateInFullElectionNotStaked() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.nominateInFullElection(1, candidates);
    }

    function testNominateInFullElectionNotElection() public {
        vm.warp(block.timestamp + 23 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(1, new address[](5));
    }

    function testNominateInFullElectionNominatingEnded() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(1, new address[](5));
    }

    function testNominateInFullElectionNotFullElection() public {
        vm.warp(block.timestamp + 21 weeks);
        vm.prank(user2);
        automatedVoting.stepDown();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;

        vm.expectRevert("Election not a full election");
        automatedVoting.nominateInFullElection(1, candidates);
    }

    // voteInFullElection()

    function testVoteInFullElectionSuccess() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        automatedVoting.nominateInFullElection(1, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(1, candidates);

        //todo: check the candidateAddresses array
        uint user1Votes = automatedVoting.voteCounts(1, user1);
        assertEq(user1Votes, 1);
        uint user2Votes = automatedVoting.voteCounts(1, user2);
        assertEq(user2Votes, 1);
        uint user3Votes = automatedVoting.voteCounts(1, user3);
        assertEq(user3Votes, 1);
        uint user4Votes = automatedVoting.voteCounts(1, user4);
        assertEq(user4Votes, 1);
        uint user5Votes = automatedVoting.voteCounts(1, user5);
        assertEq(user5Votes, 1);
        uint adminVotes = automatedVoting.voteCounts(1, admin);
        assertEq(adminVotes, 0);
    }

    function testVoteInFullElectionNotStaked() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        vm.startPrank(user1);
        automatedVoting.voteInFullElection(1, candidates);
    }

    function testVoteInFullElectionNotElection() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInFullElection(1, new address[](5));
    }

    function testVoteInFullElectionAlreadyEnded() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInFullElection(1, new address[](5));
    }

    function testVoteInFullElectionTooManyCandidates() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](6);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        candidates[5] = admin;
        vm.warp(block.timestamp + 1 weeks);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.TooManyCandidates.selector)
        );
        automatedVoting.voteInFullElection(1, candidates);
    }

    function testVoteInFullElectionAlreadyVoted() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        automatedVoting.nominateInFullElection(1, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(1, candidates);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        automatedVoting.voteInFullElection(1, candidates);
    }

    function testVoteInFullElectionCandidateNotNominated() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 2);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 2);
        stakingRewards.stake(2);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        vm.warp(block.timestamp + 1 weeks);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CandidateNotNominated.selector)
        );
        automatedVoting.voteInFullElection(1, candidates);
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
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        automatedVotingInternals.nominateInFullElection(1, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVotingInternals.voteInFullElection(1, candidates);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVotingInternals.finalizeElectionInternal(1);
        assertEq(automatedVotingInternals.isElectionFinalized(1), true);

        /// @dev check if the council changed
        assertEq(automatedVotingInternals.getCouncil(), candidates);
    }

        function testFinalizeElectionInternalStepDown() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVotingInternals.stepDown();
        automatedVotingInternals.nominateInSingleElection(1, user6);
        vm.warp(block.timestamp + 1 weeks);
        automatedVotingInternals.voteInSingleElection(1, user6);
        assertEq(automatedVotingInternals.voteCounts(1, user6), 1);

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

    function testFinalizeElectionInternalCouncil() public {
        vm.prank(user1);
        automatedVotingInternals.startCouncilElection(user5);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user1, user5), true);
        assertEq(automatedVotingInternals.removalVotes(user5), 1);
        vm.prank(user2);
        automatedVotingInternals.startCouncilElection(user5);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user2, user5), true);
        assertEq(automatedVotingInternals.removalVotes(user5), 2);
        /// @dev member is booted after the third vote, election starts, and accounting is cleared
        vm.prank(user3);
        automatedVotingInternals.startCouncilElection(user5);

        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVotingInternals.nominateInSingleElection(1, user6);
        vm.warp(block.timestamp + 1 weeks);
        automatedVotingInternals.voteInSingleElection(1, user6);
        vm.warp(block.timestamp + 3 weeks + 1);
        assertEq(automatedVotingInternals.isElectionFinalized(1), false);
        automatedVotingInternals.finalizeElectionInternal(1);
        assertEq(automatedVotingInternals.isElectionFinalized(1), true);

        assertEq(automatedVotingInternals.getCouncil().length, 5);
        assertEq(automatedVotingInternals.getCouncil()[0], user1);
        assertEq(automatedVotingInternals.getCouncil()[1], user2);
        assertEq(automatedVotingInternals.getCouncil()[2], user3);
        assertEq(automatedVotingInternals.getCouncil()[3], user4);
        assertEq(automatedVotingInternals.getCouncil()[4], user6);
    }

    // getWinners()

    function testGetWinners() public {
        vm.warp(block.timestamp + 21 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        automatedVoting.nominateInFullElection(1, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(1, candidates);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(1);

        (address[] memory winners, uint256[] memory votes) = automatedVoting
            .getWinners(0, 5);
        assertEq(winners.length, 5);
        assertEq(votes.length, 5);
        assertEq(winners[0], user1);
        assertEq(winners[1], user2);
        assertEq(winners[2], user3);
        assertEq(winners[3], user4);
        assertEq(winners[4], user5);
    }

    function testGetWinnersStepDown() public {
        vm.warp(block.timestamp + 21 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();
        automatedVoting.nominateInSingleElection(1, user1);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInSingleElection(1, user1);
        assertEq(automatedVoting.voteCounts(1, user1), 1);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(1);

        (address[] memory winners, uint256[] memory votes) = automatedVoting
            .getWinners(0, 1);
        assertEq(winners.length, 1);
        assertEq(votes.length, 1);
        assertEq(winners[0], user1);
        /// @dev reverts because index out of bounds (should do that)
        vm.expectRevert();
        assertEq(winners[1], user2);
    }

    //todo: test getWinners more (scrutinize it with a lot of fuzzing)

    // isWinner()

    function testIsWinner() public {
        address[] memory winners = new address[](1);
        winners[0] = user1;
        assertEq(
            automatedVotingInternals.isWinnerInternal(user1, winners, 1),
            true
        );
    }

    function testIsNotWinner() public {
        address[] memory winners = new address[](1);
        winners[0] = user1;
        assertEq(
            automatedVotingInternals.isWinnerInternal(user2, winners, 1),
            false
        );
    }

    // _cancelOngoingElections()

    function testCancelOngoingElectionsStepDown() public {
        vm.prank(user1);
        automatedVotingInternals.stepDown();
        assertEq(automatedVotingInternals.isElectionFinalized(1), false);
        vm.prank(user2);
        automatedVotingInternals.stepDown();
        assertEq(automatedVotingInternals.isElectionFinalized(2), false);
        (
            ,
            ,
            ,
            Enums.electionType theElectionType
        ) = automatedVotingInternals.elections(1);
        assertTrue(theElectionType == Enums.electionType.stepDown);
        automatedVotingInternals.cancelOngoingElectionsInternal();
        assertEq(automatedVotingInternals.isElectionFinalized(1), true);
        assertEq(automatedVotingInternals.isElectionFinalized(2), true);
    }

    function testCancelOngoingElectionsCKIP() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVotingInternals.startCKIPElection();
        assertEq(automatedVotingInternals.isElectionFinalized(1), false);
        (
            ,
            ,
            ,
            Enums.electionType theElectionType
        ) = automatedVotingInternals.elections(1);
        assertTrue(theElectionType == Enums.electionType.CKIP);
        automatedVotingInternals.cancelOngoingElectionsInternal();
        assertEq(automatedVotingInternals.isElectionFinalized(1), true);
    }

    function testCancelOngoingElectionsCouncil() public {
        address[] memory membersUpForRemoval = automatedVotingInternals.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 0);
        vm.prank(user1);
        automatedVotingInternals.startCouncilElection(user5);
        membersUpForRemoval = automatedVotingInternals.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 1);
        assertEq(membersUpForRemoval[0], user5);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user1, user5), true);
        assertEq(automatedVotingInternals.removalVotes(user5), 1);
        vm.prank(user2);
        automatedVotingInternals.startCouncilElection(user5);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user2, user5), true);
        assertEq(automatedVotingInternals.removalVotes(user5), 2);
        /// @dev user 3 doesnt vote for user5, so user5 isnt booted
        vm.prank(user3);
        automatedVotingInternals.startCouncilElection(user1);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user3, user5), false);
        assertEq(automatedVotingInternals.removalVotes(user5), 2);    
        membersUpForRemoval = automatedVotingInternals.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 2);
        assertEq(membersUpForRemoval[1], user1);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user3, user1), true);
        assertEq(automatedVotingInternals.removalVotes(user1), 1); 

        /// @dev cancel ongoing elections so everything should be clear but the council stays the same
        automatedVotingInternals.cancelOngoingElectionsInternal();

        /// @dev check accounting
        membersUpForRemoval = automatedVotingInternals.getMembersUpForRemoval();
        assertEq(membersUpForRemoval.length, 2);
        assertEq(membersUpForRemoval[0], address(0));
        assertEq(membersUpForRemoval[1], address(0));
        assertEq(automatedVotingInternals.isCouncilMember(user5), true);
        assertEq(automatedVotingInternals.isCouncilMember(user1), true);
        assertEq(automatedVotingInternals.removalVotes(user5), 0);
        assertEq(automatedVotingInternals.removalVotes(user1), 0);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user1, user5), false);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user2, user5), false);
        assertEq(automatedVotingInternals.hasVotedForMemberRemoval(user3, user1), false);
    }

    //todo: test isWinner for the < upToIndex change

    //todo: test everything with when a non-existent election is put in

    //todo: test onlyFullElection

    //todo: test elections 1ike CKIP reelection for when another re-election
    // is started right at 3 weeks end but the first election is not finalized yet

    //todo: test more of the membersUpForRemoval in startCouncil

    /// @dev create a new user address
    function createUser() public returns (address) {
        userNonce++;
        return vm.addr(userNonce);
    }
}
