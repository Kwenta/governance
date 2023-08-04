// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IAutomatedVoting {
    // Events

    // Errors

    // View Functions

    /// @notice returns the time until the next scheduled election
    function timeUntilNextScheduledElection() external view returns (uint256);

    /// @notice returns the time until the election state ends
    /// @param election the election to check
    function timeUntilElectionStateEnd(uint256 election) external view returns (uint256);

    // Mutative Functions

    /// @notice start the 6 month election cycle
    function startScheduledElection() external;

    /// @notice finalize the election
    /// @param election the election to finalize
    function finalizeElection(uint256 election) external;

}