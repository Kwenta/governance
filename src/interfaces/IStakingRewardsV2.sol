// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStakingRewardsV2 {
	/// @notice Returns the total number of staked tokens for a user
	/// the sum of all escrowed and non-escrowed tokens
	/// @param _account: address of potential staker
	/// @return amount of tokens staked by account
	function balanceOf(address _account) external view returns (uint256);

	/// @notice get a users balance at a given timestamp
	/// @param _account: address of account to check
	/// @param _timestamp: timestamp to check
	/// @return balance at given timestamp
	/// @dev if called with a timestamp that equals the current block timestamp, then the function might return inconsistent
	/// values as further transactions changing the balances can still occur within the same block.
	function balanceAtTime(address _account, uint256 _timestamp) external view returns (uint256);

	/// @notice get the total supply at a given timestamp
	/// @param _timestamp: timestamp to check
	/// @return total supply at given timestamp
	/// @dev if called with a timestamp that equals the current block timestamp, then the function might return inconsistent
	/// values as further transactions changing the balances can still occur within the same block.
	function totalSupplyAtTime(uint256 _timestamp) external view returns (uint256);
}
