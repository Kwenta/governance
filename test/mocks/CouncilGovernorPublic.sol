// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CouncilGovernor, Safe, Error, EnumerableSet } from "src/CouncilGovernor.sol";

contract CouncilGovernorPublic is CouncilGovernor {
	using EnumerableSet for EnumerableSet.AddressSet;

	EnumerableSet.AddressSet winnerSet;

	constructor(address _safeProxy) CouncilGovernor(_safeProxy) {}

	function initiateNewCouncil(address[] calldata winners) external {
		_resetSet();
		for (uint256 i = 0; i < winners.length; i++) {
			winnerSet.add(winners[i]);
		}
		_initiateNewCouncil(winnerSet);
	}

	function _resetSet() internal {
		for (uint256 i = 0; i < winnerSet.length(); i++) {
			winnerSet.remove(winnerSet.at(i));
		}
	}
}
