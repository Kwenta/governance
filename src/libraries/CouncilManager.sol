// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Error } from "src/libraries/Error.sol";

import { Safe } from "safe-contracts/Safe.sol";
import { Enum } from "safe-contracts/common/Enum.sol";
import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

library CouncilManager {
	using EnumerableSet for EnumerableSet.AddressSet;

	/// @notice default signer threshold in the safe
	uint256 internal constant THRESHOLD = 3;
	/// @notice number of seats in the council (number of Safe owners)
	uint256 internal constant COUNCIL_SEATS_NUMBER = 5;
	/// @notice first and last default address in a Safe's owner mapping
	address internal constant DEFAULT_SENTINEL_ADDRESS = address(0x1);

	/// @notice adds and replaces new members to the council based on the last election's results
	/// @param _safeProxy the proxy address of a safe
	/// @param _winners the winners of an election
	function _initiateNewCouncil(Safe _safeProxy, EnumerableSet.AddressSet storage _winners) internal {
		for (uint256 i = 0; i < _winners.length(); i++) {
			address winner = _winners.at(i);
			/// @dev we first check if a winner isn't in the council yet
			if (_safeProxy.isOwner(winner)) continue;

			address[] memory currentOwners = _safeProxy.getOwners();

			/// @dev if there is a free seat, we add a new owner
			if (currentOwners.length < COUNCIL_SEATS_NUMBER) {
				/// @dev we make sure to readjust the threshold
				uint256 threshold = THRESHOLD > currentOwners.length + 1 ? currentOwners.length + 1 : THRESHOLD;
				if (!_addOwnerWithThreshold(_safeProxy, winner, threshold)) revert Error.CouldNotModifyCouncil();
				/// @dev if no free seats available, we need to swap a current owner by a new elected one
			} else {
				/// @dev we go through all the current owners
				for (uint256 j = 0; j < currentOwners.length; ) {
					/// @dev if a current owner isn't found in the winners set, we replace it
					if (!_winners.contains(currentOwners[j])) {
						/// @dev we asssume the index before is always
						address previousOwner = j == 0 ? DEFAULT_SENTINEL_ADDRESS : currentOwners[j - 1];
						if (!_swapOwner(_safeProxy, previousOwner, currentOwners[j], winner))
							revert Error.CouldNotModifyCouncil();
						break;
					}
					unchecked {
						++j;
					}
				}
			}
		}
	}

	/// @notice adds a new member to the council
	/// @param _safeProxy the proxy address of a safe
	/// @param _winner the winner of a replacement election
	function _addMemberToCouncil(Safe _safeProxy, address _winner) internal {
		if (_safeProxy.getOwners().length == COUNCIL_SEATS_NUMBER) revert Error.NoSeatAvailableInCouncil();
		if (!_addOwnerWithThreshold(_safeProxy, _winner, THRESHOLD)) revert Error.CouldNotModifyCouncil();
	}

	function _removeMemberFromCouncil(Safe _safeProxy, address _member) internal {
		address[] memory currentOwners = _safeProxy.getOwners();
		if (currentOwners.length < COUNCIL_SEATS_NUMBER) revert Error.NotEnoughMembersInCouncil();
		for (uint256 i = 0; i < currentOwners.length; ) {
			if (currentOwners[i] == _member) {
				address previousOwner = i == 0 ? DEFAULT_SENTINEL_ADDRESS : currentOwners[i - 1];
				if (!_removeOwner(_safeProxy, previousOwner, _member, THRESHOLD - 1))
					revert Error.CouldNotModifyCouncil();
			}
			unchecked {
				++i;
			}
		}
	}

	/// @notice calls addOwnerWithThreshold() on a safe
	/// @dev done with execTransactionFromModule()
	/// @param _safeProxy the proxy address of a safe
	/// @param _newOwner the address of the new safe owner
	/// @param _threshold the wanted threshold when adding the new owner
	function _addOwnerWithThreshold(Safe _safeProxy, address _newOwner, uint256 _threshold) internal returns (bool) {
		bytes memory addOwner = abi.encodeWithSignature(
			"addOwnerWithThreshold(address,uint256)",
			_newOwner,
			_threshold
		);
		return _safeProxy.execTransactionFromModule(address(_safeProxy), 0, addOwner, Enum.Operation.Call);
	}

	/// @notice calls removeOwner() on a safe
	/// @dev done with execTransactionFromModule()
	/// @param _safeProxy the proxy address of a safe
	/// @param _prevOwner the address of the safe owner placed before the one we want to remove
	/// @param _owner the address of the safe owner we want to remove
	/// @param _threshold the wanted threshold when removing the owner
	function _removeOwner(
		Safe _safeProxy,
		address _prevOwner,
		address _owner,
		uint256 _threshold
	) internal returns (bool) {
		bytes memory removeOwner = abi.encodeWithSignature(
			"removeOwner(address,address,uint256)",
			_prevOwner,
			_owner,
			_threshold
		);
		return _safeProxy.execTransactionFromModule(address(_safeProxy), 0, removeOwner, Enum.Operation.Call);
	}

	/// @notice calls swapOwner() on a safe
	/// @dev done with execTransactionFromModule()
	/// @param _safeProxy the proxy address of a safe
	/// @param _prevOwner the address of the safe owner placed before the one we want to remove
	/// @param _oldOwner the address of the safe owner we want to remove
	/// @param _newOwner the address of the new owner
	function _swapOwner(
		Safe _safeProxy,
		address _prevOwner,
		address _oldOwner,
		address _newOwner
	) internal returns (bool) {
		bytes memory swapOwner = abi.encodeWithSignature(
			"swapOwner(address,address,address)",
			_prevOwner,
			_oldOwner,
			_newOwner
		);
		return _safeProxy.execTransactionFromModule(address(_safeProxy), 0, swapOwner, Enum.Operation.Call);
	}
}
