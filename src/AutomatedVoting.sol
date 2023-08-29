// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IAutomatedVoting} from "./interfaces/IAutomatedVoting.sol";
import {IStakingRewards} from "../lib/token/contracts/interfaces/IStakingRewards.sol";
import {Enums} from "./Enums.sol";

contract AutomatedVoting is IAutomatedVoting {
    address[] public council;
    mapping(uint256 => election) public elections;
    mapping(uint256 => mapping(address => uint256)) public voteCounts;
    mapping(address => mapping(uint256 => bool)) hasVoted;
    mapping(uint256 => mapping(address => bool)) public isNominated;
    uint256[] public electionNumbers;
    uint256 public lastScheduledElection;
    uint256 public lastCKIPElection;
    IStakingRewards public stakingRewards;

    /// @dev this is for council removal elections
    mapping(address => uint256) public removalVotes;
    mapping(address => mapping(address => bool)) public hasVotedForMemberRemoval;
    address[] public membersUpForRemoval;

    struct election {
        uint256 startTime;
        uint256 endTime;
        bool isFinalized;
        Enums.electionType theElectionType;
        address[] candidateAddresses; // Array of candidate addresses for this election
        address[] winningCandidates; // Array of candidates that won
    }

    modifier onlyCouncil() {
        if (isCouncilMember(msg.sender)) {
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

    modifier wasStaked(uint256 _election) {
        //todo: add historical check for staker
        // based off when election started
        _;
    }

    modifier onlyDuringNomination(uint256 _election) {
        require(
            block.timestamp >= elections[_election].startTime &&
                block.timestamp <= elections[_election].startTime + 1 weeks,
            "Election not in nomination state"
        );
        _;
    }

    modifier onlyDuringVoting(uint256 _election) {
        require(
            block.timestamp >= elections[_election].startTime + 1 weeks &&
                block.timestamp <= elections[_election].endTime,
            "Election not in voting state"
        );
        _;
    }

    modifier onlySingleElection(uint256 _election) {
        require(
            elections[_election].theElectionType == Enums.electionType.council ||
                elections[_election].theElectionType ==
                Enums.electionType.stepDown,
            "Election not a single election"
        );
        _;
    }

    modifier onlyFullElection(uint256 _election) {
        require(
            elections[_election].theElectionType == Enums.electionType.CKIP ||
                elections[_election].theElectionType ==
                Enums.electionType.scheduled,
            "Election not a full election"
        );
        _;
    }

    constructor(address[] memory _council, address _stakingRewards) {
        council = _council;
        stakingRewards = IStakingRewards(_stakingRewards);
        lastScheduledElection = block.timestamp;
    }

    function timeUntilNextScheduledElection()
        public
        view
        override
        returns (uint256)
    {
        if (block.timestamp >= lastScheduledElection + 24 weeks) {
            return 0;
        } else {
            return 24 weeks - (block.timestamp - lastScheduledElection);
        }
    }

    function timeUntilElectionStateEnd(
        uint256 _election
    ) public view override returns (uint256) {
        /// @dev if the election is over or the election number is greater than the number of elections, return 0
        if (
            elections[_election].endTime <= block.timestamp ||
            _election >= electionNumbers.length
        ) {
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
            lastScheduledElection = block.timestamp;
            _startElection(Enums.electionType.scheduled);
            //todo: reset quorums and other elections because scheduled takes precedence
            // _finalizeElection(current ongoing elections)
        }
    }

    function startCouncilElection(
        address _memberToRemove
    ) public override onlyCouncil {
        /// @dev if the member to remove is not on the council, revert
        if (!isCouncilMember(_memberToRemove)) {
            revert MemberNotOnCouncil();
        }
        /// @dev if this member already voted, revert
        if (hasVotedForMemberRemoval[msg.sender][_memberToRemove]) {
            revert AlreadyVoted();
        }
        /// @dev record vote
        hasVotedForMemberRemoval[msg.sender][_memberToRemove] = true;
        removalVotes[_memberToRemove]++;

        /// @dev if threshold is reached, remove member and start election
        if (removalVotes[_memberToRemove] >= 3) {
            /// @dev burn rights
            for (uint i = 0; i < council.length; i++) {
                if (council[i] == _memberToRemove) {
                    delete council[i];
                }
            }

            /// @dev clear all counting/tracking for this member
            removalVotes[_memberToRemove] = 0;
            for (uint i = 0; i < council.length; i++) {
                hasVotedForMemberRemoval[council[i]][_memberToRemove] = false;
            }
            for (uint i = 0; i < membersUpForRemoval.length; i++) {
                if (membersUpForRemoval[i] == _memberToRemove) {
                    delete membersUpForRemoval[i];
                }
            }

            _startElection(Enums.electionType.council);
        }
    }

    function startCKIPElection() public override onlyStaker {
        /// @dev if a CKIP election is ongoing, revert
        if (block.timestamp < lastCKIPElection + 3 weeks) {
            revert ElectionNotReadyToBeStarted();
        } else {
            lastCKIPElection = block.timestamp;
            _startElection(Enums.electionType.CKIP);
        }
    }

    function stepDown() public override onlyCouncil {
        uint councilMemberCount = 0;
        for (uint i = 0; i < council.length; i++) {
            if (council[i] != address(0)) {
                councilMemberCount++;
            }
        }
        // make sure there is at least one council member
        if (councilMemberCount <= 1) {
            revert CouncilMemberCannotStepDown();
        }
        // burn msg.sender rights
        for (uint i = 0; i < council.length; i++) {
            if (council[i] == msg.sender) {
                delete council[i];
            }
        }
        // start election state
        _startElection(Enums.electionType.stepDown);
    }

    function finalizeElection(uint256 _election) public override {
        if (elections[_election].isFinalized) {
            revert ElectionAlreadyFinalized();
        } else if (block.timestamp >= elections[_election].endTime) {
            _finalizeElection(_election);
        } else {
            revert ElectionNotReadyToBeFinalized();
        }
    }

    function nominateInSingleElection(
        uint256 _election,
        address candidate
    )
        public
        override
        onlyStaker
        onlyDuringNomination(_election)
        onlySingleElection(_election)
    {
        elections[_election].candidateAddresses.push(candidate);
        isNominated[_election][candidate] = true;
    }

    function voteInSingleElection(
        uint256 _election,
        address candidate
    )
        public
        override
        onlyStaker
        onlyDuringVoting(_election)
        onlySingleElection(_election)
    {
        if (hasVoted[msg.sender][_election]) {
            revert AlreadyVoted();
        }
        address[] memory candidates = new address[](1);
        candidates[0] = candidate;
        if (!_candidatesAreNominated(_election, candidates)) {
            revert CandidateNotNominated();
        }
        hasVoted[msg.sender][_election] = true;
        voteCounts[_election][candidate]++;
    }

    function nominateInFullElection(
        uint256 _election,
        address[] calldata candidates
    )
        public
        override
        onlyStaker
        onlyDuringNomination(_election)
        onlyFullElection(_election)
    {
        for (uint256 i = 0; i < candidates.length; i++) {
            //todo: optimize this to not repeat the same candidates
            elections[_election].candidateAddresses.push(candidates[i]);
            isNominated[_election][candidates[i]] = true;
        }
    }

    function voteInFullElection(
        uint256 _election,
        address[] calldata candidates
    )
        public
        override
        onlyStaker
        onlyDuringVoting(_election)
        onlyFullElection(_election)
    {
        if (candidates.length > 5) {
            revert TooManyCandidates();
        }
        if (hasVoted[msg.sender][_election]) {
            revert AlreadyVoted();
        }
        if (!_candidatesAreNominated(_election, candidates)) {
            revert CandidateNotNominated();
        }
        hasVoted[msg.sender][_election] = true;
        for (uint256 i = 0; i < candidates.length; i++) {
            voteCounts[_election][candidates[i]]++;
        }
    }

    function _startElection(Enums.electionType electionType) internal {
        uint256 electionNumber = electionNumbers.length;
        electionNumbers.push(electionNumber);
        elections[electionNumber].startTime = block.timestamp;
        elections[electionNumber].endTime = block.timestamp + 3 weeks;
        elections[electionNumber].isFinalized = false;
        elections[electionNumber].theElectionType = electionType;
    }

    function _candidatesAreNominated(
        uint256 _election,
        address[] memory candidates
    ) internal view returns (bool) {
        for (uint256 i = 0; i < candidates.length; i++) {
            if (isNominated[_election][candidates[i]] == false) {
                return false;
            }
        }
        return true;
    }

    function isCouncilMember(
        address voter
    ) public view returns (bool isACouncilMember) {
        for (uint i = 0; i < council.length; i++) {
            if (council[i] == voter) {
                return true;
            }
        }
        if (!isACouncilMember) {
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

    function _checkIfQuorumReached(uint256 _election) internal returns (bool) {
        //todo: check if quorum reached
        //todo: if quorum reached, finalize election _finalizeElection(_election)
    }

    function _finalizeElection(uint256 _election) internal {
        elections[_election].isFinalized = true;
        if (elections[_election].theElectionType == Enums.electionType.scheduled || elections[_election].theElectionType == Enums.electionType.CKIP) {
            /// @dev this is for a full election
            (address[] memory winners, ) = getWinners(_election, 5);
            elections[_election].winningCandidates = winners;
            council = winners;
        } else if (elections[_election].theElectionType == Enums.electionType.council || elections[_election].theElectionType == Enums.electionType.stepDown) {
            /// @dev this is for a single election
            (address[] memory winners, ) = getWinners(_election, 1);
            elections[_election].winningCandidates = winners;
            //todo: figure out how to fill in a slot for a single election
        }
    }

    function getWinners(
        uint256 electionId,
        uint256 numberOfWinners
    ) public view returns (address[] memory, uint256[] memory) {
        require(elections[electionId].isFinalized, "Election not finalized");

        address[] memory winners = new address[](numberOfWinners);
        uint256[] memory voteCountsOfWinners = new uint256[](numberOfWinners);

        for (uint256 i = 0; i < numberOfWinners; i++) {
            address bestCandidate;
            uint256 maxVotes = 0;

            for (
                uint256 j = 0;
                j < elections[electionId].candidateAddresses.length;
                j++
            ) {
                address candidate = elections[electionId].candidateAddresses[j];
                if (
                    voteCounts[electionId][candidate] > maxVotes &&
                    !isWinner(candidate, winners, i)
                ) {
                    maxVotes = voteCounts[electionId][candidate];
                    bestCandidate = candidate;
                }
            }

            winners[i] = bestCandidate;
            voteCountsOfWinners[i] = maxVotes;
        }

        return (winners, voteCountsOfWinners);
    }

    function isWinner(
        address candidate,
        address[] memory winners,
        uint256 upToIndex
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < upToIndex; i++) {
            if (candidate == winners[i]) {
                return true;
            }
        }
        return false;
    }

    //todo: special functionality to boot someone off
    //todo: voting is one function/idea (stakers do it)

    //full council election
    //single council election

    //todo: no quorum, whoever has the most at the end
    //remove hasFinalized

    //removing council member has quorum

    //todo: make sure someone can't become a council member twice
    // check this on single elections
}
