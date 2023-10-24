// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";

import { CouncilGovernorPublic } from "test/mocks/CouncilGovernorPublic.sol";
import { SafeProxyMock } from "test/mocks/SafeProxyMock.sol";

contract CouncilGovernorTest is Test {
	SafeProxyMock safeProxy;
	CouncilGovernorPublic councilGovernor;

	address user1 = vm.addr(1);
	address user2 = vm.addr(2);
	address user3 = vm.addr(3);
	address user4 = vm.addr(4);
	address user5 = vm.addr(5);

	uint256 public constant SAFE_THRESHOLD = 3;
	uint256 constant SEATS_NUMBER = 5;

	event AddedOwner(address indexed owner);
	event RemovedOwner(address indexed owner);

	function setUp() public {
		safeProxy = new SafeProxyMock();
	}
}

contract initiateNewCouncil is CouncilGovernorTest {
	function test_SameCouncilElected() public {
		// we initialize the safe with 5 owners
		address[] memory safeOwners = new address[](5);
		safeOwners[0] = user1;
		safeOwners[1] = user2;
		safeOwners[2] = user3;
		safeOwners[3] = user4;
		safeOwners[4] = user5;

		safeProxy.initializeOwners(safeOwners, SAFE_THRESHOLD);
		councilGovernor = new CouncilGovernorPublic(address(safeProxy));

		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.getOwners().length == SEATS_NUMBER);

		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user2));
		assertTrue(safeProxy.isOwner(user3));
		assertTrue(safeProxy.isOwner(user4));
		assertTrue(safeProxy.isOwner(user5));

		// we now simulate a vote electing the same members
		councilGovernor.initiateNewCouncil(safeOwners);

		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.getOwners().length == SEATS_NUMBER);

		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user2));
		assertTrue(safeProxy.isOwner(user3));
		assertTrue(safeProxy.isOwner(user4));
		assertTrue(safeProxy.isOwner(user5));
	}

	function test_SomeMembersReelected() public {
		// we initialize the safe with 5 owners
		address[] memory safeOwners = new address[](5);
		safeOwners[0] = user1;
		safeOwners[1] = user2;
		safeOwners[2] = user3;
		safeOwners[3] = user4;
		safeOwners[4] = user5;

		safeProxy.initializeOwners(safeOwners, SAFE_THRESHOLD);
		councilGovernor = new CouncilGovernorPublic(address(safeProxy));

		// we now simulate a vote reelecting a few members and electing new ones
		safeOwners[2] = vm.addr(6);
		safeOwners[3] = vm.addr(7);
		safeOwners[4] = vm.addr(8);

		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user3);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(6));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user4);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(7));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user5);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(8));

		councilGovernor.initiateNewCouncil(safeOwners);

		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.getOwners().length == SEATS_NUMBER);

		// reelected members
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user2));
		// new members
		assertTrue(safeProxy.isOwner(vm.addr(6)));
		assertTrue(safeProxy.isOwner(vm.addr(7)));
		assertTrue(safeProxy.isOwner(vm.addr(8)));
		// old members
		assertFalse(safeProxy.isOwner(user3));
		assertFalse(safeProxy.isOwner(user4));
		assertFalse(safeProxy.isOwner(user5));
	}

	function test_FreeSeatsForNewMembersWithFullReelection() public {
		// we initialize the safe with 2 owners
		address[] memory safeOwners = new address[](2);
		safeOwners[0] = user1;
		safeOwners[1] = user2;

		safeProxy.initializeOwners(safeOwners, 1);
		councilGovernor = new CouncilGovernorPublic(address(safeProxy));

		assertTrue(safeProxy.getThreshold() == 1);
		assertTrue(safeProxy.getOwners().length == 2);

		// we now simulate a vote keeping both members in and adding 3 new ones
		safeOwners = new address[](5);
		safeOwners[0] = user3;
		safeOwners[1] = user4;
		safeOwners[2] = user2;
		safeOwners[3] = user5;
		safeOwners[4] = user1;

		vm.expectEmit(true, false, false, false);
		emit AddedOwner(user3);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(user4);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(user5);

		councilGovernor.initiateNewCouncil(safeOwners);

		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.getOwners().length == 5);

		// reelected members
		assertTrue(safeProxy.isOwner(user1));
		assertTrue(safeProxy.isOwner(user2));
		// new members
		assertTrue(safeProxy.isOwner(user3));
		assertTrue(safeProxy.isOwner(user4));
		assertTrue(safeProxy.isOwner(user5));
	}

	function test_FreeSeatsForNewMembersWithPartialReelection() public {
		// we initialize the safe with 2 owners
		address[] memory safeOwners = new address[](2);
		safeOwners[0] = user1;
		safeOwners[1] = user2;

		safeProxy.initializeOwners(safeOwners, 1);
		councilGovernor = new CouncilGovernorPublic(address(safeProxy));

		assertTrue(safeProxy.getThreshold() == 1);
		assertTrue(safeProxy.getOwners().length == 2);

		// we now simulate a vote keeping only one member in and adding 4 new ones
		safeOwners = new address[](5);
		safeOwners[0] = user3;
		safeOwners[1] = user4;
		safeOwners[2] = vm.addr(6);
		safeOwners[3] = user5;
		safeOwners[4] = user1;

		emit AddedOwner(user3);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(user4);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(6));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user2);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(user5);

		councilGovernor.initiateNewCouncil(safeOwners);

		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.getOwners().length == 5);

		// reelected members
		assertTrue(safeProxy.isOwner(user1));
		// new members
		assertTrue(safeProxy.isOwner(user3));
		assertTrue(safeProxy.isOwner(user4));
		assertTrue(safeProxy.isOwner(user5));
		assertTrue(safeProxy.isOwner(vm.addr(6)));
		// old members
		assertFalse(safeProxy.isOwner(user2));
	}

	function test_FreeSeatsForNewMembersWithNoReelection() public {
		// we initialize the safe with 2 owners
		address[] memory safeOwners = new address[](2);
		safeOwners[0] = user1;
		safeOwners[1] = user2;

		safeProxy.initializeOwners(safeOwners, 1);
		councilGovernor = new CouncilGovernorPublic(address(safeProxy));

		assertTrue(safeProxy.getThreshold() == 1);
		assertTrue(safeProxy.getOwners().length == 2);

		// we now simulate a vote removing only both members and adding 5 new ones
		safeOwners = new address[](5);
		safeOwners[0] = user3;
		safeOwners[1] = user4;
		safeOwners[2] = vm.addr(6);
		safeOwners[3] = user5;
		safeOwners[4] = vm.addr(7);

		emit AddedOwner(user3);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(user4);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(6));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user1);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(user5);
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user2);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(7));

		councilGovernor.initiateNewCouncil(safeOwners);

		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.getOwners().length == 5);

		// new members
		assertTrue(safeProxy.isOwner(user3));
		assertTrue(safeProxy.isOwner(user4));
		assertTrue(safeProxy.isOwner(user5));
		assertTrue(safeProxy.isOwner(vm.addr(6)));
		assertTrue(safeProxy.isOwner(vm.addr(7)));
		// old members
		assertFalse(safeProxy.isOwner(user1));
		assertFalse(safeProxy.isOwner(user2));
	}

	function test_WholeNewCouncilElected() public {
		// we initialize the safe with 5 owners
		address[] memory safeOwners = new address[](5);
		safeOwners[0] = user1;
		safeOwners[1] = user2;
		safeOwners[2] = user3;
		safeOwners[3] = user4;
		safeOwners[4] = user5;

		safeProxy.initializeOwners(safeOwners, SAFE_THRESHOLD);
		councilGovernor = new CouncilGovernorPublic(address(safeProxy));

		// we now simulate a vote replacing all members
		safeOwners[0] = vm.addr(6);
		safeOwners[1] = vm.addr(7);
		safeOwners[2] = vm.addr(8);
		safeOwners[3] = vm.addr(9);
		safeOwners[4] = vm.addr(10);

		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user1);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(6));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user2);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(7));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user3);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(8));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user4);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(9));
		vm.expectEmit(true, false, false, false);
		emit RemovedOwner(user5);
		vm.expectEmit(true, false, false, false);
		emit AddedOwner(vm.addr(10));

		councilGovernor.initiateNewCouncil(safeOwners);

		assertTrue(safeProxy.getThreshold() == SAFE_THRESHOLD);
		assertTrue(safeProxy.getOwners().length == 5);

		// new members
		assertTrue(safeProxy.isOwner(vm.addr(6)));
		assertTrue(safeProxy.isOwner(vm.addr(7)));
		assertTrue(safeProxy.isOwner(vm.addr(7)));
		assertTrue(safeProxy.isOwner(vm.addr(8)));
		assertTrue(safeProxy.isOwner(vm.addr(9)));
		assertTrue(safeProxy.isOwner(vm.addr(10)));
		// old members
		assertFalse(safeProxy.isOwner(user1));
		assertFalse(safeProxy.isOwner(user2));
		assertFalse(safeProxy.isOwner(user3));
		assertFalse(safeProxy.isOwner(user4));
		assertFalse(safeProxy.isOwner(user5));
	}
}
