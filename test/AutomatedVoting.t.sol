// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {AutomatedVoting} from "../src/AutomatedVoting.sol";
import {StakingRewards} from "../lib/token/contracts/StakingRewards.sol";
import {Kwenta} from "../lib/token/contracts/Kwenta.sol";
import {RewardEscrow} from "../lib/token/contracts/RewardEscrow.sol";

contract AutomatedVotingTest is Test {
    AutomatedVoting public automatedVoting;
    StakingRewards public stakingRewards;
    Kwenta public kwenta;
    RewardEscrow public rewardEscrow;
    address public admin;
    uint256 public userNonce;
    uint256 public startTime;

    function setUp() public {
        startTime = block.timestamp;
        admin = createUser();
        kwenta = new Kwenta(
            "Kwenta",
            "Kwe",
            100_000,
            admin,
            address(this)
        );
        rewardEscrow = new RewardEscrow(admin, address(kwenta));
        stakingRewards = new StakingRewards(address(kwenta), address(rewardEscrow), address(this));
        address[] memory council = new address[](1);
        council[0] = address(0x1);
        automatedVoting = new AutomatedVoting(council, address(stakingRewards));
    }

    // getCouncil()

    function testGetCouncil() public {
        address[] memory result = automatedVoting.getCouncil();
        assertEq(result.length, 1, "Council should have 1 member");
        assertEq(result[0], address(0x1), "Council member should be 0x1");
    }

    // timeUntilNextScheduledElection()

    function testTimeUntilNextScheduledElection() public {
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 24 weeks - startTime);
    }

    function testTimeUntilNextScheduledElectionOverdue() public {
        vm.warp(block.timestamp + 24 weeks);
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 0);
    }

    function testFuzzTimeUntilNextScheduledElection(uint128 time) public {
        vm.assume(time < 24 weeks);
        vm.warp(block.timestamp + time);
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 24 weeks - startTime - time);
    }

    // timeUntilElectionStateEnd()

    function testTimeUntilElectionStateEndNoElection() public {
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 0);
    }

    function testTimeUntilElectionStateEndNewScheduledElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 2 weeks);
    }

    function testTimeUntilElectionStateEndFinishedElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 2 weeks);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 0);
    }

    function testTimeUntilElectionStateEndOtherElections() public {
        //todo: test other election states
    }

    function testFuzzTimeUntilElectionStateEndNewScheduledElection(uint128 time) public {
        vm.assume(time < 2 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 2 weeks - time);
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
        vm.warp(block.timestamp + 2 weeks + 1);
        automatedVoting.finalizeElection(0);
        assertEq(automatedVoting.isElectionFinalized(0), true);
    }

    //todo: test everything with when a non-existent election is put in

    /// @dev create a new user address
    function createUser() public returns (address) {
        userNonce++;
        return vm.addr(userNonce);
    }
}
