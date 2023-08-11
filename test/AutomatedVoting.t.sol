// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/AutomatedVoting.sol";

contract CounterTest is Test {
    AutomatedVoting public automatedVoting;

    function setUp() public {
        address[] memory council = new address[](1);
        council[0] = address(0x1);
        automatedVoting = new AutomatedVoting(council);
    }

    function testGetCouncil() public {
        address[] memory result = automatedVoting.getCouncil();
        assertEq(result.length, 1, "Council should have 1 member");
        assertEq(result[0], address(0x1), "Council member should be 0x1");
    }

    //todo: test everything with when a non-existent election is put in
}
