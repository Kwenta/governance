// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { OwnerManager } from "safe-contracts/base/OwnerManager.sol";
import { ModuleManager, Enum } from "safe-contracts/base/ModuleManager.sol";

contract SafeProxyMock is OwnerManager, ModuleManager {
	function initializeOwners(address[] memory _owners, uint256 _threshold) public {
		setupOwners(_owners, _threshold);
	}

	function execTransactionFromModule(
		address to,
		uint256 value,
		bytes memory data,
		Enum.Operation operation
	) public virtual override returns (bool success) {
		// Execute transaction without further confirmations.
		success = execute(to, value, data, operation, type(uint256).max);
		if (success) emit ExecutionFromModuleSuccess(msg.sender);
		else emit ExecutionFromModuleFailure(msg.sender);
	}
}
