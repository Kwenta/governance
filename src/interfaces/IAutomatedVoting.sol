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

    /// @notice start an election to remove a member of the elite council
    /// @notice this is only callable by the elite council
    /// @param eliteCouncil the elite council member to remove
    function startEliteCouncilElection(address eliteCouncil) external;

    /// @notice start an election to remove a member of the eliteCouncil
    /// @notice this is only callable by the stakers through the CKIP
    /// @param eliteCouncil the elite council member to remove
    function startCKIPElection(address eliteCouncil) external;

    /// @notice step down from the elite council
    /// @dev this triggers an election to replace the member
    function stepDown() external;

    /// @notice finalize the election
    /// @param election the election to finalize
    function finalizeElection(uint256 election) external;

    /// @notice vote for a nominee
    /// @param nominee the nominee to vote for
    function vote(address nominee) external;

}