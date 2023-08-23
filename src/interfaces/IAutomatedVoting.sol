// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IAutomatedVoting {
    // Events

    /// @notice emitted when an council member is added
    /// @param councilMember the council member that was added
    event CouncilMemberAdded(address councilMember);

    /// @notice emitted when an council member is removed
    /// @param councilMember the council member that was removed
    event CouncilMemberRemoved(address councilMember);

    /// @notice emitted when an election ends
    /// @param election the election that ended
    event ElectionEnded(uint256 election);

    /// @notice emitted when an council member steps down
    /// @param councilMember the council member that stepped down
    event CouncilMemberStepDown(address councilMember);

    // Errors

    /// @notice emitted when the caller is not the council
    error CallerNotCouncil();

    /// @notice emitted when the caller is not staked
    error CallerNotStaked();

    /// @notice emitted when the election is not ready to be finalized
    error ElectionNotReadyToBeFinalized();

    /// @notice emitted when the election is already finalized
    error ElectionAlreadyFinalized();

    /// @notice emitted when the election is not ready to be started
    error ElectionNotReadyToBeStarted();

    /// @notice emitted when an council member cannot step down
    /// this could happen if everyone tries to step down at once
    error CouncilMemberCannotStepDown();

    /// @notice emitted when the caller has already voted for this election
    error AlreadyVoted();

    /// @notice emitted when the caller votes for too many candidates
    error TooManyCandidates();

    /// @notice emitted when candidate is not nominated
    error CandidateNotNominated();

    // View Functions

    /// @notice returns the last scheduled election
    function lastScheduledElection() external view returns (uint256);

    /// @notice returns the time until the next scheduled election
    function timeUntilNextScheduledElection() external view returns (uint256);

    /// @notice returns the time until the election state ends
    /// @param election the election to check
    function timeUntilElectionStateEnd(
        uint256 election
    ) external view returns (uint256);

    /// @notice returns the current council
    function getCouncil() external view returns (address[] memory);

    /// @notice returns if the election is finalized
    /// @param election the election to check
    function isElectionFinalized(uint256 election) external view returns (bool);

    // Mutative Functions

    /// @notice start the 6 month election cycle
    function startScheduledElection() external;

    /// @notice start an election to remove a member of the council
    /// @notice this is only callable by the council
    /// @param Council the council member to remove
    function startCouncilElection(address Council) external;

    /// @notice start an election to remove a member of the Council
    /// @notice this is only callable by the stakers through the CKIP
    /// @param Council the council member to remove
    function startCKIPElection(address Council) external;

    /// @notice step down from the council
    /// @dev this triggers an election to replace the member
    function stepDown() external;

    /// @notice finalize the election
    /// @param election the election to finalize
    function finalizeElection(uint256 election) external;

    /// @notice nominate someone in a single election
    /// @param _election the election to nominate in
    /// @param candidate the nominee to nominate
    function nominateInSingleElection(
        uint256 _election,
        address candidate
    ) external;

    /// @notice nominate people in a full election
    /// @param _election the election to nominate in
    /// @param candidates the nominee to nominate
    function nominateInFullElection(
        uint256 _election,
        address[] memory candidates
    ) external;

    /// @notice vote for a nominee in a single election
    /// @param _election the election to vote in
    /// @param candidate the nominee to vote for
    function voteInSingleElection(
        uint256 _election,
        address candidate
    ) external;

    /// @notice vote for nominees in a full election
    /// @param _election the election to vote in
    /// @param candidates the nominees to vote for
    function voteInFullElection(
        uint256 _election,
        address[] memory candidates
    ) external;
}
