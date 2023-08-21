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

    constructor() AutomatedVoting(new address[](1), address(0)) {
        council[0] = address(0x1);
        admin = address(0x2);
        kwenta = new Kwenta("Kwenta", "Kwe", 100_000, admin, address(this));
        rewardEscrow = new RewardEscrow(admin, address(kwenta));
        stakingRewards = new StakingRewards(
            address(kwenta),
            address(rewardEscrow),
            address(this)
        );
    }

    function echidna_test_example() public view returns (bool) {
        return council.length >= 1;
    }

}