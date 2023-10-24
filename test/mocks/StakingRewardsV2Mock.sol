// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStakingRewardsV2 } from "src/interfaces/IStakingRewardsV2.sol";

contract StakingRewardsV2Mock is IStakingRewardsV2 {
	mapping(address => uint256) public balances;
	uint256 public totalSupply;

	function balanceOf(address _account) external view returns (uint256) {
		return balances[_account];
	}

	function balanceAtTime(address _account, uint256) external view returns (uint256) {
		return balances[_account];
	}

	function totalSupplyAtTime(uint256) external view returns (uint256) {
		return totalSupply;
	}

	function stake(uint256 _amount) external {
		balances[msg.sender] += _amount;
		totalSupply += _amount;
	}
}
