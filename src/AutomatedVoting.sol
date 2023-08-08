// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./interfaces/IAutomatedVoting.sol";

contract AutomatedVoting is IAutomatedVoting {
    
    constructor() {
        
    }

    function timeUntilNextScheduledElection() public view override returns (uint256) {
        return 0;
    }

    function timeUntilElectionStateEnd(uint256 election) public view override returns (uint256) {
        return 0;
    }

    function getCouncil() public view override returns (address[] memory) {
        address[] memory council = new address[](1);
        council[0] = msg.sender; //TODO: replace with actual council
        return council;
    }

    function isElectionFinalized(uint256 election) public view override returns (bool) {
        
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