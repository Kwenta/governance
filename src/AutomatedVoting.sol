// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./interfaces/IAutomatedVoting.sol";

contract AutomatedVoting is IAutomatedVoting {
    
    address[] public council;
    mapping(uint256 => election) elections;
    uint256[] public electionNumbers;
    uint256 lastScheduledElection;

    struct election {
        uint256 startTime;
        uint256 endTime;
        bool isFinalized;
    }

    constructor(address[] memory _council) {
        council = _council;
    }
        

    function timeUntilNextScheduledElection() public view override returns (uint256) {
        if (block.timestamp > lastScheduledElection + 24 weeks ) {
            return 0;
        }
        else {
            return block.timestamp + 24 weeks - lastScheduledElection;
        }
    }

    function timeUntilElectionStateEnd(uint256 _election) public view override returns (uint256) {
        if (elections[_election].isFinalized) {
            return 0;
        }
        else {
            return elections[_election].endTime - block.timestamp;
        }
    }

    function getCouncil() public view override returns (address[] memory) {
        return council;
    }

    function isElectionFinalized(uint256 _election) public view override returns (bool) {
        return elections[_election].isFinalized;
    }

    function startScheduledElection() public override {
        _recordElectionState();
    }

    function startCouncilElection(address _council) public override {

    }

    function startCKIPElection(address _council) public override {

    }

    function stepDown() public override {
        //todo: burn msg.sender rights
        _recordElectionState();
    }

    function finalizeElection(uint256 _election) public override {

    }

    function vote(uint256 _election, address candidate) public override {

    }

    function _recordElectionState() internal {
        lastScheduledElection = block.timestamp;
        uint256 electionNumber = electionNumbers.length;
        electionNumbers.push(electionNumber);
        elections[electionNumber].startTime = block.timestamp;
        elections[electionNumber].endTime = block.timestamp + 2 weeks;
        elections[electionNumber].isFinalized = false;
    }

}