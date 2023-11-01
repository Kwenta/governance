// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Error } from "src/libraries/Error.sol";

import { Safe } from "safe-contracts/Safe.sol";
import { Enum } from "safe-contracts/common/Enum.sol";
import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

contract CouncilGovernor {
	using EnumerableSet for EnumerableSet.AddressSet;

	uint256 public constant THRESHOLD = 3;
	uint256 public constant COUNCIL_SEATS_NUMBER = 5;
	address public constant DEFAULT_SENTINEL_ADDRESS = address(0x1);

	Safe public safeProxy;

	constructor(address _safeProxy) {
		if (_safeProxy == address(0)) revert Error.ZeroAddress();
		safeProxy = Safe(payable(address(_safeProxy)));
	}

	modifier safeOnly() {
		if (msg.sender != address(safeProxy)) revert Error.Unauthorized();
		_;
	}

	function _initiateNewCouncil(EnumerableSet.AddressSet storage _winners) internal {
		for (uint i = 0; i < _winners.length(); i++) {
			address winner = _winners.at(i);
			/// @dev we first check if a winner isn't in the council yet
			if (_isCouncilMember(winner)) continue;

			address[] memory currentOwners = safeProxy.getOwners();

			/// @dev if there is a free seat, we add a new owner
			if (currentOwners.length < _winners.length()) {
				/// @dev we make sure the threshold isn't too high
				uint256 threshold = THRESHOLD > currentOwners.length + 1 ? currentOwners.length + 1 : THRESHOLD;
				_addOwnerWithThreshold(winner, threshold);
				/// @dev if no free seats available, we need to swap a current owner by a new elected one
			} else {
				/// @dev we go through all the current owners
				for (uint j = 0; j < currentOwners.length; ) {
					/// @dev if a current owner isn't found in the winners set, we replace it
					if (!_winners.contains(currentOwners[j])) {
						/// @dev we asssume the index before is always
						address previousOwner = j == 0 ? DEFAULT_SENTINEL_ADDRESS : currentOwners[j - 1];
						_swapOwner(previousOwner, currentOwners[j], winner);
						break;
					}
					unchecked {
						++j;
					}
				}
			}
		}
	}

	function _addMemberToCouncil(address _winner) internal {
		if (safeProxy.getOwners().length == COUNCIL_SEATS_NUMBER) revert Error.NoSeatAvailableInCouncil();
		_addOwnerWithThreshold(_winner, THRESHOLD);
	}

	function _removeMemberFromCouncil(address _member) internal {
		address[] memory currentOwners = safeProxy.getOwners();
		if (currentOwners.length < COUNCIL_SEATS_NUMBER) revert Error.NotEnoughMembersInCouncil();
		for (uint i = 0; i < currentOwners.length; ) {
			if (currentOwners[i] == _member) {
				address previousOwner = i == 0 ? DEFAULT_SENTINEL_ADDRESS : currentOwners[i - 1];
				_removeOwner(previousOwner, _member, THRESHOLD - 1);
			}
			unchecked {
				++i;
			}
		}
	}

	/// @notice this is to call addOwnerWithThreshold() on the safe
	/// @dev done with execTransactionFromModule()
	function _addOwnerWithThreshold(address _newOwner, uint256 _threshold) internal {
		bytes memory addOwner = abi.encodeWithSignature(
			"addOwnerWithThreshold(address,uint256)",
			_newOwner,
			_threshold
		);
		safeProxy.execTransactionFromModule(address(safeProxy), 0, addOwner, Enum.Operation.Call);
	}

	function _removeOwner(address _prevOwner, address _owner, uint256 _threshold) internal {
		bytes memory removeOwner = abi.encodeWithSignature(
			"removeOwner(address,address,uint256)",
			_prevOwner,
			_owner,
			_threshold
		);
		safeProxy.execTransactionFromModule(address(safeProxy), 0, removeOwner, Enum.Operation.Call);
	}

	/// @notice this is to call replaceOwner() on the safe
	/// @dev done with execTransactionFromModule()
	function _swapOwner(address prevOwner, address oldOwner, address newOwner) internal {
		bytes memory swapOwner = abi.encodeWithSignature(
			"swapOwner(address,address,address)",
			prevOwner,
			oldOwner,
			newOwner
		);
		safeProxy.execTransactionFromModule(address(safeProxy), 0, swapOwner, Enum.Operation.Call);
	}

	function _isCouncilMember(address _account) internal view returns (bool) {
		return safeProxy.isOwner(_account);
	}

	function _getOwners() internal view returns (address[] memory) {
		return safeProxy.getOwners();
	}
}
