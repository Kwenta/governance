// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CouncilManager, EnumerableSet, Safe } from "src/libraries/CouncilManager.sol";

contract CouncilManagerMock {
	using EnumerableSet for EnumerableSet.AddressSet;

	Safe public immutable safeProxy;

	EnumerableSet.AddressSet private winnerSet;

	constructor(address _safeProxy) {
		safeProxy = Safe(payable(_safeProxy));
	}

	function initiateNewCouncil(address[] calldata _winners) external {
		_resetSet();
		for (uint256 i = 0; i < _winners.length; i++) {
			winnerSet.add(_winners[i]);
		}
		CouncilManager._initiateNewCouncil(safeProxy, winnerSet);
	}

	function addMemberToCouncil(address _winner) external {
		CouncilManager._addMemberToCouncil(safeProxy, _winner);
	}

	function _resetSet() internal {
		for (uint256 i = 0; i < winnerSet.length(); i++) {
			winnerSet.remove(winnerSet.at(i));
		}
	}
}
