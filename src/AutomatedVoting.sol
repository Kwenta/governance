// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./interfaces/IAutomatedVoting.sol";

contract AutomatedVoting is IAutomatedVoting {
    
    address[] public council;
    mapping(uint256 => election) elections;

    struct election {
        uint256 startTime;
        uint256 endTime;
        bool isFinalized;
    }

    constructor(address[] memory _council) {
        council = _council;
    }
        

    function timeUntilNextScheduledElection() public view override returns (uint256) {
        return 0;
    }

    function timeUntilElectionStateEnd(uint256 election) public view override returns (uint256) {
        if (elections[election].isFinalized) {
            return 0;
        }
        else {
            return elections[election].endTime - block.timestamp;
        }
    }

    function getCouncil() public view override returns (address[] memory) {
        return council;
    }

    function isElectionFinalized(uint256 election) public view override returns (bool) {
        return elections[election].isFinalized;
    }

    function startScheduledElection() public override {

    }

    function startCouncilElection(address council) public override {

    }

    function startCKIPElection(address council) public override {

    }

    function stepDown() public override {

    }

    function finalizeElection(uint256 election) public override {

    }

    function vote(uint256 election, address candidate) public override {

    }

}