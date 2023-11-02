// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CouncilGovernor, EnumerableSet } from "src/CouncilGovernor.sol";

contract CouncilGovernorPublic is CouncilGovernor {
	using EnumerableSet for EnumerableSet.AddressSet;

	EnumerableSet.AddressSet private winnerSet;

	constructor(address _safeProxy) CouncilGovernor(_safeProxy) {}

	function initiateNewCouncil(address[] calldata _winners) external {
		_resetSet();
		for (uint256 i = 0; i < _winners.length; i++) {
			winnerSet.add(_winners[i]);
		}
		_initiateNewCouncil(winnerSet);
	}

	function addMemberToCouncil(address _winner) external {
		_addMemberToCouncil(_winner);
	}

	function _resetSet() internal {
		for (uint256 i = 0; i < winnerSet.length(); i++) {
			winnerSet.remove(winnerSet.at(i));
		}
	}
}
