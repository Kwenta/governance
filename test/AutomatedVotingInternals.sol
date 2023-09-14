// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {AutomatedVoting} from "../src/AutomatedVoting.sol";

contract AutomatedVotingInternals is AutomatedVoting {
    constructor(address _stakingRewards) AutomatedVoting(_stakingRewards) {}

    function wasStakedBeforeElectionInternal(
        address voter,
        uint256 _election
    ) public view returns (bool) {
        return _wasStakedBeforeElection(voter, _election);
    }

    function checkIfQuorumReached(
        uint256 _election
    ) public view returns (bool) {
        return _checkIfQuorumReached(_election);
    }

    function finalizeElectionInternal(uint256 _election) public {
        _finalizeElection(_election);
    }

    function sortCandidates(
        uint256 _election,
        address voteeName,
        uint256 newNumOfVotes
    ) public view returns (uint256) {
        _sortCandidates(_election, voteeName, newNumOfVotes);
    }

    function cancelOngoingElectionsInternal() public {
        _cancelOngoingElections();
    }
}
