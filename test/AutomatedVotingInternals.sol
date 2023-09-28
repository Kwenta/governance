// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {AutomatedVoting} from "../src/AutomatedVoting.sol";

contract AutomatedVotingInternals is AutomatedVoting {
    constructor(
        address _stakingRewards,
        uint256 startTime,
        address _safeProxy
    ) AutomatedVoting(_stakingRewards, startTime, _safeProxy) {}

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
    ) public view returns (address[] memory) {
        return _sortCandidates(_election, voteeName, newNumOfVotes);
    }

    function cancelOngoingElectionsInternal() public {
        _cancelOngoingElections();
    }

    function replaceOwnerInternal(address oldOwner, address newOwner) public {
        replaceOwner(oldOwner, newOwner);
    }

    function addOwnerWithThresholdInternal(address newOwner) public {
        addOwnerWithThreshold(newOwner);
    }

    function removeOwnerInternal(
        address prevOwner,
        address owner,
        uint256 threshold
    ) public {
        removeOwner(prevOwner, owner, threshold);
    }

}
