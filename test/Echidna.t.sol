// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {AutomatedVoting} from "../src/AutomatedVoting.sol";
import {StakingRewards} from "../lib/token/contracts/StakingRewards.sol";
import {Kwenta} from "../lib/token/contracts/Kwenta.sol";
import {RewardEscrow} from "../lib/token/contracts/RewardEscrow.sol";

contract EchidnaTest is AutomatedVoting {

    Kwenta public kwenta;
    RewardEscrow public rewardEscrow;
    address public admin;

    constructor() AutomatedVoting(address(0)) {
        council[0] = address(0x1);
        council[1] = address(0x2);
        council[2] = address(0x3);
        council[3] = address(0x4);
        council[4] = address(0x5);
        admin = address(0x6);
        kwenta = new Kwenta("Kwenta", "Kwe", 100_000, admin, address(this));
        rewardEscrow = new RewardEscrow(admin, address(kwenta));
        stakingRewards = new StakingRewards(
            address(kwenta),
            address(rewardEscrow),
            address(this)
        );
    }

    function echidna_council_length_always_greater_than_0() public view returns (bool) {
        return council.length >= 1;
    }

    function echidna_council_length_always_equal_to_5() public view returns (bool) {
        return council.length == 5;
    }

    function echidna_next_scheduled_election_always_less_than_24_weeks() public view returns (bool) {
        return timeUntilNextScheduledElection() <= 24 weeks;
    }

    function echidna_election_state_always_less_than_3_weeks() public view returns (bool) {
        return timeUntilElectionStateEnd(0) <= 3 weeks;
    }

}