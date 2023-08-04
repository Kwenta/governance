// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IAutomatedVoting {
    // Events

    /// @notice emitted when an elite council member is added
    /// @param eliteCouncilMember the elite council member that was added
    event EliteCouncilMemberAdded(address eliteCouncilMember);

    /// @notice emitted when an elite council member is removed
    /// @param eliteCouncilMember the elite council member that was removed
    event EliteCouncilMemberRemoved(address eliteCouncilMember);

    /// @notice emitted when an election ends
    /// @param election the election that ended
    event ElectionEnded(uint256 election);

    /// @notice emitted when an elite council member steps down
    /// @param eliteCouncilMember the elite council member that stepped down
    event EliteCouncilMemberStepDown(address eliteCouncilMember);

    // Errors

    /// @notice emitted when the caller is not the elite council
    error CallerNotEliteCouncil();

    /// @notice emitted when the caller is not staked
    error CallerNotStaked();

    /// @notice emitted when the election is not ready to be finalized
    error ElectionNotReadyToBeFinalized();

    /// @notice emitted when the election is not ready to be started
    error ElectionNotReadyToBeStarted();

    /// @notice emitted when an elite council member cannot step down
    /// this could happen if everyone tries to step down at once
    error EliteCouncilMemberCannotStepDown();

    /// @notice emitted when the caller has already voted for this election
    error AlreadyVoted();

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