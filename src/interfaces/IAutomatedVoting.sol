// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IAutomatedVoting {
    // Events

    // Errors

    // View Functions

    /// @notice returns the time until the next scheduled election
    function timeUntilNextScheduledElection() external view returns (uint256);

    function timeUntilElectionStateEnd(uint256 election) external view returns (uint256);

    // Mutative Functions

    /// @notice start the 6 month election cycle
    function startScheduledElection() external;

}