// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
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
    uint256 public userNonce;
    uint256 public startTime;

    function setUp() public {
        startTime = block.timestamp;
        admin = createUser();
        user1 = createUser();
        user2 = createUser();
        user3 = createUser();
        user4 = createUser();
        user5 = createUser();
        kwenta = new Kwenta("Kwenta", "Kwe", 100_000, admin, address(this));
        rewardEscrow = new RewardEscrow(admin, address(kwenta));
        stakingRewards = new StakingRewards(
            address(kwenta),
            address(rewardEscrow),
            address(this)
        );
        address[] memory council = new address[](1);
        council[0] = address(0x1);
        automatedVoting = new AutomatedVoting(council, address(stakingRewards));
        automatedVotingInternals = new AutomatedVotingInternals(
            council,
            address(stakingRewards)
        );
    }

    // onlyCouncil()

    // onlyStaker()

    // onlyDuringNomination()

    function testOnlyDuringNominationAtStart() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testFuzzOnlyDuringNomination(uint128 time) public {
        vm.assume(time <= 1 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.warp(block.timestamp + time);
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testOnlyDuringNominationLastSecond() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testOnlyDuringNominationPassed() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert(
            "Election not in nomination state"
        );
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testOnlyDuringNominationNoElectionYet() public {
        vm.warp(block.timestamp + 23 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert(
            "Election not in nomination state"
        );
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    // onlyDuringElection()

    // getCouncil()

    function testGetCouncil() public {
        address[] memory result = automatedVoting.getCouncil();
        assertEq(result.length, 1, "Council should have 1 member");
        assertEq(result[0], address(0x1), "Council member should be 0x1");
    }

    // timeUntilNextScheduledElection()

    function testTimeUntilNextScheduledElection() public {
        assertEq(
            automatedVoting.timeUntilNextScheduledElection(),
            24 weeks - startTime
        );
    }

    function testTimeUntilNextScheduledElectionOverdue() public {
        vm.warp(block.timestamp + 24 weeks);
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 0);
    }

    function testFuzzTimeUntilNextScheduledElection(uint128 time) public {
        vm.assume(time < 24 weeks);
        vm.warp(block.timestamp + time);
        assertEq(
            automatedVoting.timeUntilNextScheduledElection(),
            24 weeks - startTime - time
        );
    }

    // timeUntilElectionStateEnd()

    function testTimeUntilElectionStateEndNoElection() public {
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 0);
    }

    function testTimeUntilElectionStateEndNewScheduledElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks);
    }

    function testTimeUntilElectionStateEndFinishedElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 0);
    }

    function testTimeUntilElectionStateEndOtherElections() public {
        //todo: test other election states
    }

    function testFuzzTimeUntilElectionStateEndNewScheduledElection(
        uint128 time
    ) public {
        vm.assume(time < 3 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks - time);
    }

    // isElectionFinalized()

    function testIsElectionFinalizedNoElection() public {
        assertEq(automatedVoting.isElectionFinalized(0), false);
    }

    function testIsElectionFinalizedNewElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.isElectionFinalized(0), false);
    }

    function testIsElectionFinalizedFinishedElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(0);
        assertEq(automatedVoting.isElectionFinalized(0), true);
    }

    // startScheduledElection()

    function testFuzzStartScheduledElectionNotReady(uint128 time) public {
        vm.assume(time < 24 weeks);
        vm.warp(block.timestamp + time - startTime);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startScheduledElection();
    }

    function testStartScheduledElectionReady() public {
        vm.warp(block.timestamp + 24 weeks - startTime);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks);
        assertEq(automatedVoting.lastScheduledElection(), block.timestamp);
        assertEq(automatedVoting.electionNumbers(0), 0);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(0);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.full);
    }

    // startCouncilElection()

    // startCKIPelection()

    // stepDown()

    // finalizeElection()

    function testFinalizeElectionAlreadyFinalized() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionAlreadyFinalized.selector
            )
        );
        automatedVoting.finalizeElection(0);
    }

    function testFinalizeElection() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(0);
        assertEq(automatedVoting.isElectionFinalized(0), true);
    }

    function testFuzzFinalizeElectionNotReady(uint128 time) public {
        vm.assume(time < 2 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeFinalized.selector
            )
        );
        automatedVoting.finalizeElection(0);
    }

    // voteInSingleElection()

    // nominateInFullElection()

    function testNominateInFullElectionSuccess() public {
        vm.warp(block.timestamp + 24 weeks);
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
        automatedVoting.nominateInFullElection(0, candidates);

        //todo: check the candidateAddresses array
        assertEq(automatedVoting.isNominated(0, user1), true);
        assertEq(automatedVoting.isNominated(0, user2), true);
        assertEq(automatedVoting.isNominated(0, user3), true);
        assertEq(automatedVoting.isNominated(0, user4), true);
        assertEq(automatedVoting.isNominated(0, user5), true);

    }

    function testNominateInFullElectionNotStaked() public {
        vm.warp(block.timestamp + 24 weeks);
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
        automatedVoting.nominateInFullElection(0, candidates);
    }

    function testNominateInFullElectionNotElection() public {
        vm.warp(block.timestamp + 23 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testNominateInFullElectionNominatingEnded() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    // voteInFullElection()

    function testVoteInFullElectionSuccess() public {
        vm.warp(block.timestamp + 24 weeks);
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
        automatedVoting.nominateInFullElection(0, candidates);
        automatedVoting.voteInFullElection(0, candidates);

        //todo: check the candidateAddresses array
        uint user1Votes = automatedVoting.voteCounts(0, user1);
        assertEq(user1Votes, 1);
        uint user2Votes = automatedVoting.voteCounts(0, user2);
        assertEq(user2Votes, 1);
        uint user3Votes = automatedVoting.voteCounts(0, user3);
        assertEq(user3Votes, 1);
        uint user4Votes = automatedVoting.voteCounts(0, user4);
        assertEq(user4Votes, 1);
        uint user5Votes = automatedVoting.voteCounts(0, user5);
        assertEq(user5Votes, 1);
        uint adminVotes = automatedVoting.voteCounts(0, admin);
        assertEq(adminVotes, 0);
    }

    function testVoteInFullElectionNotStaked() public {
        vm.warp(block.timestamp + 24 weeks);
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
        automatedVoting.voteInFullElection(0, candidates);
    }

    function testVoteInFullElectionNotElection() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not active");
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    function testVoteInFullElectionAlreadyEnded() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not active");
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    function testVoteInFullElectionTooManyCandidates() public {
        vm.warp(block.timestamp + 24 weeks);
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
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.TooManyCandidates.selector)
        );
        automatedVoting.voteInFullElection(0, candidates);
    }

    function testVoteInFullElectionAlreadyVoted() public {
        vm.warp(block.timestamp + 24 weeks);
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
        automatedVoting.nominateInFullElection(0, candidates);
        automatedVoting.voteInFullElection(0, candidates);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        automatedVoting.voteInFullElection(0, candidates);
    }

    // _isCouncilMember()

    function testIsCouncilMember() public {
        assertEq(automatedVotingInternals.isCouncilMember(address(0x1)), true);
    }

    function testIsNotCouncilMember() public {
        assertEq(automatedVotingInternals.isCouncilMember(address(0x2)), false);
    }

    // _isStaker()

    // _checkIfQuorumReached()

    // _finalizeElection()

    function testFinalizeElectionInternal() public {
        vm.warp(block.timestamp + 24 weeks);
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
        automatedVotingInternals.nominateInFullElection(0, candidates);
        automatedVotingInternals.voteInFullElection(0, candidates);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVotingInternals.finalizeElectionInternal(0);
        assertEq(automatedVotingInternals.isElectionFinalized(0), true);

        /// @dev check if the council changed
        assertEq(automatedVotingInternals.getCouncil(), candidates);
    }

    // getWinners()

    function testGetWinners() public {
        vm.warp(block.timestamp + 24 weeks);
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
        automatedVoting.nominateInFullElection(0, candidates);
        automatedVoting.voteInFullElection(0, candidates);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(0);

        (address[] memory winners, uint256[] memory votes) =
            automatedVoting.getWinners(0, 5);
        assertEq(winners.length, 5);
        assertEq(votes.length, 5);
        assertEq(winners[0], user1);
        assertEq(winners[1], user2);
        assertEq(winners[2], user3);
        assertEq(winners[3], user4);
        assertEq(winners[4], user5);
    }

    //todo: test getWinners more

    // isWinner()

    function testIsWinner() public {
        address[] memory winners = new address[](1);
        winners[0] = user1;
        assertEq(automatedVotingInternals.isWinnerInternal(user1, winners, 1), true);
    }

    function testIsNotWinner() public {
        address[] memory winners = new address[](1);
        winners[0] = user1;
        assertEq(automatedVotingInternals.isWinnerInternal(user2, winners, 1), false);
    }

    //todo: test isWinner for the < upToIndex change

    //todo: test everything with when a non-existent election is put in

    //todo: test modifiers like onlyDuringElection

    /// @dev create a new user address
    function createUser() public returns (address) {
        userNonce++;
        return vm.addr(userNonce);
    }
}
