// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./interfaces/IAutomatedVoting.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract AutomatedVoting is IAutomatedVoting, Initializable {
    address[] public council;
    mapping(uint256 => election) elections;
    mapping(address => mapping(uint256 => bool)) hasVoted;
    uint256[] public electionNumbers;
    uint256 lastScheduledElection;

    struct election {
        uint256 startTime;
        uint256 endTime;
        bool isFinalized;
    }

    modifier onlyCouncil() {
        if (_isCouncilMember(msg.sender)) {
            _;
        } else {
            revert CallerNotCouncil();
        }
    }

    modifier onlyStaker() {
        if (_isStaker(msg.sender)) {
            _;
        } else {
            revert CallerNotStaked();
        }
    }

    constructor() {
        _disableInitializers();
    }

    initialize(address[] memory _council) initializer public {
        council = _council;
    }

    function timeUntilNextScheduledElection()
        public
        view
        override
        returns (uint256)
    {
        if (block.timestamp > lastScheduledElection + 24 weeks) {
            return 0;
        } else {
            return block.timestamp + 24 weeks - lastScheduledElection;
        }
    }

    function timeUntilElectionStateEnd(
        uint256 _election
    ) public view override returns (uint256) {
        if (elections[_election].isFinalized) {
            return 0;
        } else {
            return elections[_election].endTime - block.timestamp;
        }
    }

    function getCouncil() public view override returns (address[] memory) {
        return council;
    }

    function isElectionFinalized(
        uint256 _election
    ) public view override returns (bool) {
        return elections[_election].isFinalized;
    }

    function startScheduledElection() public override {
        if (block.timestamp < lastScheduledElection + 24 weeks) {
            revert ElectionNotReadyToBeStarted();
        } else {
            _recordElectionState();
        }
    }

    function startCouncilElection(
        address _council
    ) public override onlyCouncil {}

    function startCKIPElection(address _council) public override onlyStaker {}

    function stepDown() public override {
        //todo: burn msg.sender rights
        _recordElectionState();
    }

    function finalizeElection(uint256 _election) public override {
        if (block.timestamp > elections[_election].endTime) {
            _finalizeElection(_election);
        } else {
            revert ElectionNotReadyToBeFinalized();
        }
    }

    function voteInScheduledElection(
        uint256 _election,
        address[] calldata candidates
    ) public override onlyStaker {
        if(hasVoted[msg.sender][_election]) {
            revert AlreadyVoted();
        }
        hasVoted[msg.sender][_election] = true;
        //todo: voting
        _checkIfQuorumReached(_election);
    }

    function voteInCouncilElection(
        uint256 _election,
        address candidate
    ) public override onlyCouncil {
        if(hasVoted[msg.sender][_election]) {
            revert AlreadyVoted();
        }
        hasVoted[msg.sender][_election] = true;
        //todo: voting
        _checkIfQuorumReached(_election);
    }

    function voteInCKIPElection(
        uint256 _election,
        address[] calldata candidates
    ) public override onlyStaker {
        if(hasVoted[msg.sender][_election]) {
            revert AlreadyVoted();
        }
        hasVoted[msg.sender][_election] = true;
        //todo: voting
        _checkIfQuorumReached(_election);
    }

    /// @dev this likely needs refactoring/changing
    function _recordElectionState() internal {
        lastScheduledElection = block.timestamp;
        uint256 electionNumber = electionNumbers.length;
        electionNumbers.push(electionNumber);
        elections[electionNumber].startTime = block.timestamp;
        elections[electionNumber].endTime = block.timestamp + 2 weeks;
        elections[electionNumber].isFinalized = false;
    }

    function _isCouncilMember(
        address voter
    ) internal view returns (bool isCouncilMember) {
        for (uint i = 0; i < council.length; i++) {
            if (council[i] == voter) {
                return true;
            }
        }
        if (!isCouncilMember) {
            return false;
        }
    }

    function _isStaker(address voter) internal view returns (bool isStaker) {
        //todo: check if voter is staker
    }

    function _checkIfQuorumReached(uint256 _election) internal {
        //todo: check if quorum reached
        //todo: if quorum reached, finalize election _finalizeElection(_election)
    }

    function _finalizeElection(uint256 _election) internal {
        elections[_election].isFinalized = true;
    }

}
