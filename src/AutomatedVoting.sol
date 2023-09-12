// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IAutomatedVoting} from "./interfaces/IAutomatedVoting.sol";
import {IStakingRewards} from "../lib/token/contracts/interfaces/IStakingRewards.sol";
import {Enums} from "./Enums.sol";

//todo: integrate with safe module here
contract AutomatedVoting is IAutomatedVoting {
    /// @notice array of council members
    address[] public council;

    /// @notice mapping of election number to election
    mapping(uint256 => election) public elections;

    /// @notice counter for elections
    /// @dev always stores the next election number
    uint256 public electionNumbers;

    /// @notice tracker for timestamp start of last scheduled election
    uint256 public lastScheduledElectionStartTime;

    /// @notice tracker for last scheduled election number
    uint256 public lastScheduledElectionNumber;

    /// @notice tracker for timestamp start of last community election
    uint256 public lastCommunityElection;

    /// @notice staking rewards contract
    IStakingRewards public stakingRewards;

    // mapping(uint256 => uint256) public stakedAmountsForQuorum;

    /// @notice constant for election duration
    /// @dev 1 week nomination, 2 weeks voting
    uint256 constant ELECTION_DURATION = 3 weeks;

    //todo: change community to community
    //todo: capitalize
    struct election {
        uint256 startTime;
        bool isFinalized;
        Enums.electionType theElectionType; //todo: review enums, compress if able
        address[] candidateAddresses; // Array of candidate addresses for this election
        //todo: remove winningCandidates and use only candidateAddresses and actively rearrange when voting happens
        mapping(address => uint256) voteCounts;
        mapping(address => bool) isNominated;
        mapping(address => bool) hasVoted;
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

    modifier notDuringScheduledElection() {
        /// @dev make sure there is no ongoing scheduled election
        /// @dev isElectionFinalized is for edge case when a scheduled election is over 3 weeks but
        /// has not been finalized yet (scheduled election will be the last election in the array)
        if (
            block.timestamp >= lastScheduledElectionStartTime + 3 weeks &&
            isElectionFinalized(lastScheduledElectionNumber)
        ) {
            _;
        } else {
            revert ScheduledElectionInProgress();
        }
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
                block.timestamp <= electionEndTime(_election),
            "Election not in voting state"
        );
        _;
    }

    modifier onlySingleElection(uint256 _election) {
        require(
            elections[_election].theElectionType ==
                Enums.electionType.single,
            "Election not a single election"
        );
        _;
    }

    modifier onlyFullElection(uint256 _election) {
        require(
                elections[_election].theElectionType ==
                Enums.electionType.scheduled || elections[_election].theElectionType == Enums.electionType.community,
            "Election not a full election"
        );
        _;
    }

    //todo: modifier onlyActiveElections (for when an election gets canceled and finalized)

    //todo: change to stakingV2
    constructor(address _stakingRewards) {
        council = new address[](5);
        stakingRewards = IStakingRewards(_stakingRewards);
        /// @dev start a scheduled election
        /// (bypasses election 0 not finalized check)
        lastScheduledElectionStartTime = block.timestamp;
        lastScheduledElectionNumber = electionNumbers;
        _startElection(Enums.electionType.scheduled);
    }

    function electionEndTime(uint256 _election) public view override returns (uint256) {
        return elections[_election].startTime + ELECTION_DURATION;
    }

    /// @notice gets the time until the next scheduled election
    /// @return uint256 the time until the next scheduled election
    function timeUntilNextScheduledElection()
        public
        view
        override
        returns (uint256)
    {
        if (block.timestamp >= lastScheduledElectionStartTime + 24 weeks) {
            return 0;
        } else {
            return
                24 weeks - (block.timestamp - lastScheduledElectionStartTime);
        }
    }

    /// @notice gets the time until the election state ends
    /// @param _election the election to check
    /// @return uint256 the time until the election state ends
    function timeUntilElectionStateEnd(
        uint256 _election
    ) public view override returns (uint256) {
        /// @dev if the election is over or the election number is greater than the number of elections, return 0
        if (
            electionEndTime(_election) <= block.timestamp ||
            _election >= electionNumbers
        ) {
            return 0;
        } else {
            return electionEndTime(_election) - block.timestamp;
        }
    }

    /// @notice gets the current council
    /// @return address[] the current council
    function getCouncil() public view override returns (address[] memory) {
        return council;
    }

    /// @notice checks if an election is finalized
    /// @param _election the election to check
    /// @return bool election is finalized
    function isElectionFinalized(
        uint256 _election
    ) public view override returns (bool) {
        return elections[_election].isFinalized;
    }

    /// @notice starts the scheduled election
    /// can only be started every 24 weeks
    function startScheduledElection() public override {
        if (
            block.timestamp < lastScheduledElectionStartTime + 24 weeks ||
            !isElectionFinalized(lastScheduledElectionNumber)
        ) {
            revert ElectionNotReadyToBeStarted();
        } else {
            lastScheduledElectionStartTime = block.timestamp;
            lastScheduledElectionNumber = electionNumbers;
            /// @dev cancel ongoing elections before _startElection so
            /// this scheduled election isnt cancelled
            _cancelOngoingElections();
            _startElection(Enums.electionType.scheduled);
        }
    }

    //todo: integrate with safe module here
    /// @notice vote in a council election
    /// @notice a 3/5 threshold of calling this function must be reached
    /// @dev rather than starting an election with a time
    /// @param _memberToRemove the member to remove from the council
    function startCouncilElection(
        address _memberToRemove
    ) public override onlyCouncil notDuringScheduledElection {
        //todo: integrate with safe here
        _startElection(Enums.electionType.single);
    }

    /// @notice starts a community election
    function startCommunityElection()
        public
        override
        onlyStaker
        notDuringScheduledElection
    {
        /// @dev if a community election is ongoing, revert
        if (block.timestamp < lastCommunityElection + 3 weeks) {
            revert ElectionNotReadyToBeStarted();
        } else {
            lastCommunityElection = block.timestamp;
            _startElection(Enums.electionType.community);
        }
    }

    /// @notice function for council member to step down
    /// @dev cannot step down if there is only one council member
    function stepDown() public override onlyCouncil notDuringScheduledElection {
        uint councilMemberCount = 0;
        for (uint i = 0; i < council.length; i++) {
            if (council[i] != address(0)) {
                councilMemberCount++;
            }
        }
        // make sure there is at least one council member //todo: can stepdown if last
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
        _startElection(Enums.electionType.single);
    }

    /// @notice finalizes an election
    /// @param _election the election to finalize
    function finalizeElection(uint256 _election) public override {
        if (elections[_election].isFinalized) {
            revert ElectionAlreadyFinalized();
        } else if (block.timestamp >= electionEndTime(_election)) {
            _finalizeElection(_election);
        } else {
            revert ElectionNotReadyToBeFinalized();
        }
    }

    /// @notice nominates a candidate for a single election
    /// @param _election the election to nominate a candidate for
    /// @param candidate the candidate to nominate
    function nominateInSingleElection( //todo: remove access controls, single nominate
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
        elections[_election].isNominated[candidate] = true;
    }

    /// @notice votes for a candidate in a single election
    /// @param _election the election to vote in
    /// @param candidate the candidate to vote for
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
        if (elections[_election].hasVoted[msg.sender]) {
            revert AlreadyVoted();
        }
        address[] memory candidates = new address[](1);
        candidates[0] = candidate;
        if (!_candidatesAreNominated(_election, candidates)) {
            revert CandidateNotNominated();
        }
        // if (elections[_election].theElectionType == Enums.electionType.community) {
        //     uint256 userStaked = stakingRewards.balanceOf(msg.sender);
        //     stakedAmountsForQuorum[_election] += userStaked;
        // }
        elections[_election].hasVoted[msg.sender] = true;
        elections[_election].voteCounts[candidate]++;
    }

    /// @notice nominates candidates for a full election
    /// @param _election the election to nominate candidates for
    /// @param candidates the candidates to nominate
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
            elections[_election].isNominated[candidates[i]] = true;
        }
    }

    /// @notice votes for candidates in a full election
    /// @param _election the election to vote in
    /// @param candidates the candidates to vote for
    function voteInFullElection(
        uint256 _election,
        address[] calldata candidates //todo: only vote for 1
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
        if (elections[_election].hasVoted[msg.sender]) {
            revert AlreadyVoted();
        }
        if (!_candidatesAreNominated(_election, candidates)) {
            revert CandidateNotNominated();
        }
        elections[_election].hasVoted[msg.sender] = true;
        for (uint256 i = 0; i < candidates.length; i++) {
            elections[_election].voteCounts[candidates[i]]++;
        }
    }

    /// @dev starts an election internally by recording state
    function _startElection(Enums.electionType electionType) internal {
        uint256 electionNumber = electionNumbers;
        electionNumbers++;
        elections[electionNumber].startTime = block.timestamp;
        elections[electionNumber].isFinalized = false;
        elections[electionNumber].theElectionType = electionType;
    }

    /// @dev helper function to determine if the candidates are nominated
    function _candidatesAreNominated(
        uint256 _election,
        address[] memory candidates
    ) internal view returns (bool) {
        for (uint256 i = 0; i < candidates.length; i++) {
            if (elections[_election].isNominated[candidates[i]] == false) {
                return false;
            }
        }
        return true;
    }

    /// @notice checks if a voter is a council member
    /// @param voter the voter to check
    /// @return isACouncilMember voter is a council member
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

    /// @dev helper function to determine if a voter is a staker
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

    /// @dev internal function to finalize elections depending on type
    function _finalizeElection(uint256 _election) internal {
        elections[_election].isFinalized = true;
        if (
            elections[_election].theElectionType ==
            Enums.electionType.scheduled
        ) {
            
            /// @dev this is for a full election
            (address[] memory winners, ) = getWinners(_election, 5);
            council = winners;
        } else if (elections[_election].theElectionType ==
            Enums.electionType.community) {
            // if (elections[_election].theElectionType == Enums.electionType.single) {
            //     uint256 quorumPercentage = stakedAmountsForQuorum[_election] * 100 / stakingRewards.totalSupply();
            //     if (quorumPercentage < 40) {
            //         //todo: emit event that quorum was not reached
            //         return;
            //     }
            // }
        }else if (
            elections[_election].theElectionType ==
            Enums.electionType.single
        ) {
            /// @dev this is for a single election
            (address[] memory winners, ) = getWinners(_election, 1);
            for (uint i = 0; i < council.length; i++) {
                if (council[i] == address(0)) {
                    council[i] = winners[0];
                    break;
                }
            }
        }
    }

    /// @notice calculates the winners of an election
    /// @param electionId the election to calculate winners for
    /// @param numberOfWinners the number of winners to calculate
    /// @return winners the addresses of the winners
    /// @return voteCountsOfWinners the vote counts of the winners
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
                    elections[electionId].voteCounts[candidate] > maxVotes &&
                    !isWinner(candidate, winners, i)
                ) {
                    maxVotes = elections[electionId].voteCounts[candidate];
                    bestCandidate = candidate;
                }
            }

            winners[i] = bestCandidate;
            voteCountsOfWinners[i] = maxVotes;
        }

        return (winners, voteCountsOfWinners);
    }

    /// @dev internal helper function to determine if the candidate is already a winner for this election
    /// this is to prevent double winning
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

    /// @dev internal helper function cancel ongoing elections when a scheduled election starts
    function _cancelOngoingElections() internal {
        //todo: optimize this
        for (uint i = 0; i < electionNumbers; i++) {
            if (elections[i].isFinalized == false) {
                elections[i].isFinalized = true;
            }
        }
        //todo:
        // for (uint i = lastFinalizedElection; i < currentElectionNumber; i++) {
        //     if (elections[i].isFinalized == false) {
        //         elections[i].isFinalized = true;
        //     }
        // }
        // //lastFinalizedElection = currentElectionNumber;
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
