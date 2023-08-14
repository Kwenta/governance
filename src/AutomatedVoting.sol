// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./interfaces/IAutomatedVoting.sol";
import "../lib/token/contracts/interfaces/IStakingRewards.sol";

contract AutomatedVoting is IAutomatedVoting {
    address[] public council;
    mapping(uint256 => election) elections;
    mapping(uint256 => mapping(address => uint256)) public voteCounts;
    mapping(address => mapping(uint256 => bool)) hasVoted;
    uint256[] public electionNumbers;
    uint256 lastScheduledElection;
    IStakingRewards public stakingRewards;

    struct election {
        uint256 startTime;
        uint256 endTime;
        bool isFinalized;
        string electionType;
        address[] candidateAddresses; // Array of candidate addresses for this election
        address[] nominatedCandidates; // Array of candidates elected
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

    modifier onlyDuringElection(uint256 _election) {
        require(
            block.timestamp >= elections[_election].startTime &&
            block.timestamp <= elections[_election].endTime,
            "Election not active"
        );
        _;
    }

    constructor(address[] memory _council, address _stakingRewards) {
        council = _council;
        stakingRewards = IStakingRewards(_stakingRewards);
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
        if (!elections[_election].isFinalized) {
            revert ElectionAlreadyFinalized();
        }
        else if (block.timestamp > elections[_election].endTime) {
            _finalizeElection(_election);
        } else {
            revert ElectionNotReadyToBeFinalized();
        }
    }

    function voteInSingleElection(
        uint256 _election,
        address candidate
    ) public override onlyStaker {
        if (hasVoted[msg.sender][_election]) {
            revert AlreadyVoted();
        }
        hasVoted[msg.sender][_election] = true;
        //todo: voting
    }

    function voteInFullElection(
        uint256 _election,
        address[] calldata candidates
    ) public override onlyStaker onlyDuringElection(_election) {
        if(isElectionFinalized(_election)){
            revert ElectionAlreadyFinalized();
        }
        if (hasVoted[msg.sender][_election]) {
            revert AlreadyVoted();
        }
        hasVoted[msg.sender][_election] = true;
        for (uint256 i = 0; i < candidates.length; i++) {
            address candidate = candidates[i];
            voteCounts[_election][candidate]++;
        }
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
        if (stakingRewards.balanceOf(voter) > 0) {
            return true;
        } else {
            return false;
        }
    }

    function _checkIfQuorumReached(uint256 _election) internal {
        //todo: check if quorum reached
        //todo: if quorum reached, finalize election _finalizeElection(_election)
    }

    function _finalizeElection(uint256 _election) internal {
        elections[_election].isFinalized = true;
    }

    //todo: special functionality to boot someone off
    //todo: voting is one function/idea (stakers do it)

    //full council election
    //single council election

    //todo: no quorum, whoever has the most at the end
    //remove hasFinalized

    //removing council member has quorum
}
