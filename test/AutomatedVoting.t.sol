/ SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/AutomatedVoting.sol";

contract CounterTest is Test {
    AutomatedVoting public automatedVoting;

    function setUp() public {
        automatedVoting = new AutomatedVoting();
    }

    function testGetCouncil() public {
        //todo
    }
}