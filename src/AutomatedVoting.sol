// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IAutomatedVoting} from "./interfaces/IAutomatedVoting.sol";
import {IStakingRewardsV2} from "../lib/token/contracts/interfaces/IStakingRewardsV2.sol";
import {Enums} from "./Enums.sol";
import {Safe} from "safe-contracts/Safe.sol";
import {Enum} from "safe-contracts/common/Enum.sol";

//todo: integrate with safe module here
contract AutomatedVoting is IAutomatedVoting {
    // /// @notice safeProxy contract
    // Safe public safeProxy;

    /// @notice array of council members
    address[5] public council;

    /// @notice mapping of election number to election
    mapping(uint256 => Election) public elections;

    /// @notice counter for elections
    /// @dev always stores the next election number
    uint256 public electionCounter;

    /// @notice tracker for timestamp start of last scheduled election
    uint256 public lastScheduledElectionStartTime;

    /// @notice tracker for last scheduled election number
    /// @dev prevents elections from overlapping active scheduled elections
    uint256 public lastScheduledElectionNumber;

    /// @notice tracker for timestamp start of last community election
    /// @dev prevents stakers calling within the 3 week cooldown period
    uint256 public lastCommunityElection;

    /// @notice tracker for the last finalized election
    /// @dev decreases the looping necessary to _cancelOngoingElections
    uint256 public lastFinalizedElection;

    /// @notice staking rewards V2 contract
    IStakingRewardsV2 public immutable stakingRewardsV2;

    /// @notice constant for election duration
    /// @dev 1 week nomination, 2 weeks voting
    uint256 constant ELECTION_DURATION = 3 weeks;

    /// @notice constant for quorum
    /// @dev 40% of total supply has to vote to make a community election valid
    /// @dev this is constant but open to be changed in an upgrade
    uint256 constant QUORUM = 40;

    struct Election {
        uint256 startTime;
        uint256 totalVote; ///@dev for quorum calculation
        bool isFinalized; //todo: enum status, ongoing, invalid, finalized //todo: set elections to ongoing
        Enums.electionType theElectionType;
        address[] candidateAddresses;
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

    modifier wasStakedBeforeElection(uint256 _election) {
        if (_wasStakedBeforeElection(msg.sender, _election)) {
            _;
        } else {
            revert CallerWasNotStakedBeforeElectionStart();
        }
    }

    modifier notDuringScheduledElection() {
        /// @dev make sure there is no ongoing scheduled election
        /// @dev isElectionFinalized is for edge case when a scheduled election is over 3 weeks but
        /// has not been finalized yet (scheduled election will be the last election in the array)
        if (
            block.timestamp >= lastScheduledElectionStartTime + 3 weeks && //todo: check if mutation testing removes sub conditions from if statements (out of curiosity)
            isElectionFinalized(lastScheduledElectionNumber) //@todo remove first check
        ) {
            _;
        } else {
            revert ScheduledElectionInProgress();
        }
    }

    modifier onlyDuringNomination(uint256 _election) {
        if (isDuringNomination(_election)) {
            _;
        } else {
            revert ElectionNotDuringNomination();
        }
    }

    modifier onlyDuringVoting(uint256 _election) {
        if (isDuringVoting(_election)) {
            _;
        } else {
            revert ElectionNotDuringVoting();
        }
    }

    // modifier onlySafe() {
    //     require(
    //         safeProxy.isOwner(msg.sender),
    //         "AutomatedVoting: caller is not a safe owner"
    //     );
    //     _;
    // }

    //todo: put all safe stuff on governor module

    constructor(address _stakingRewardsV2) {
        stakingRewardsV2 = IStakingRewardsV2(_stakingRewardsV2);
        // safeProxy = Safe(payable(address(_safeProxy)));

        //todo: make a strict timeline for elections
        // strict start date set in constructor

        //todo: 1 scheduled election per period
        // truncate by 6 months and make an "epochID"
    }

    /// @inheritdoc IAutomatedVoting
    function isDuringNomination(
        uint256 _election
    ) public view override returns (bool) {
        return
            /// @dev not inclusive of the start to prevent nomination during startTime
            block.timestamp > elections[_election].startTime &&
            block.timestamp <= elections[_election].startTime + 1 weeks;
    }

    /// @inheritdoc IAutomatedVoting
    function isDuringVoting(
        uint256 _election
    ) public view override returns (bool) {
        return
            /// @dev not inclusive of the start to prevent nomination during voting
            block.timestamp > elections[_election].startTime + 1 weeks &&
            block.timestamp <= electionEndTime(_election);
    }

    function electionEndTime(
        uint256 _election
    ) public view override returns (uint256) {
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
            _election >= electionCounter
        ) {
            return 0;
        } else {
            return electionEndTime(_election) - block.timestamp;
        }
    }

    /// @inheritdoc IAutomatedVoting
    function getCandidateAddress(
        uint256 _election,
        uint256 index
    ) public view override returns (address candidate) {
        return elections[_election].candidateAddresses[index];
    }

    /// @inheritdoc IAutomatedVoting
    function getVoteCounts(
        uint256 _election,
        address nominee
    ) public view override returns (uint256 count) {
        return elections[_election].voteCounts[nominee];
    }

    /// @inheritdoc IAutomatedVoting
    function getIsNominated(
        uint256 _election,
        address nominee
    ) public view override returns (bool isNominated) {
        return elections[_election].isNominated[nominee];
    }

    /// @inheritdoc IAutomatedVoting
    function getHasVoted(
        uint256 _election,
        address voter
    ) public view override returns (bool hasVoted) {
        return elections[_election].hasVoted[voter];
    }

    /// @notice gets the current council
    /// @return address[] the current council
    function getCouncil() public view override returns (address[5] memory) {
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
            (lastScheduledElectionNumber != 0 &&
                !isElectionFinalized(lastScheduledElectionNumber))
        ) {
            revert ElectionNotReadyToBeStarted();
        } else {
            lastScheduledElectionStartTime = block.timestamp;
            lastScheduledElectionNumber = electionCounter;
            /// @dev cancel ongoing elections before _startElection so
            /// this scheduled election isnt cancelled
            _cancelOngoingElections();
            _startElection(Enums.electionType.scheduled);
        }
    }

    /// @notice vote in a council election
    /// @notice a 3/5 threshold of calling this function must be reached
    /// @dev rather than starting an election with a time
    /// @param _memberToRemove the member to remove from the council
    function startCouncilElection(
        address _memberToRemove
    ) public override onlyCouncil notDuringScheduledElection {
        // /// @dev burn member rights
        // //todo: figure out how to get prevOwner
        // address prevOwner = address(0);
        // bytes memory addOwner = abi.encodeWithSignature(
        //     "removeOwner(address,address,uint256)",
        //     prevOwner,
        //     _memberToRemove,
        //     3
        // );
        // safeProxy.execTransactionFromModule(
        //     address(safeProxy),
        //     0,
        //     addOwner,
        //     Enum.Operation.Call
        // );
        for (uint i = 0; i < council.length; i++) {
            if (council[i] == _memberToRemove) {
                delete council[i];
            }
        }
        _startElection(Enums.electionType.single);
    }

    /// @notice starts a community election
    function startCommunityElection()
        public
        override
        notDuringScheduledElection
    {
        if (stakingRewardsV2.balanceOf(msg.sender) == 0) {
            revert CallerNotStaked();
        }
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

    /// @notice nominates a candidate
    /// @param _election the election to nominate a candidate for
    /// @param candidate the candidate to nominate
    function nominateCandidate(
        uint256 _election,
        address candidate
    )
        public
        override
        wasStakedBeforeElection(_election)
        onlyDuringNomination(_election)
    {
        _nominate(_election, candidate);
    }

    /// @notice nominates multiple candidates
    /// @param _election the election to nominate candidates for
    /// @param candidates the candidates to nominate
    function nominateMultipleCandidates(
        uint256 _election,
        address[] calldata candidates
    )
        public
        override
        wasStakedBeforeElection(_election)
        onlyDuringNomination(_election)
    {
        for (uint256 i = 0; i < candidates.length; i++) {
            _nominate(_election, candidates[i]);
        }
    }

    /// @notice nominates a candidate
    function _nominate(uint256 election, address candidate) internal {
        if (elections[election].isNominated[candidate]) {
            revert CandidateAlreadyNominated();
        }
        /// @dev this prevent a council member from being nominated in a single election (becoming member twice)
        if (
            elections[election].theElectionType == Enums.electionType.single &&
            isCouncilMember(candidate)
        ) {
            revert CandidateIsAlreadyCouncilMember();
        }
        elections[election].candidateAddresses.push(candidate);
        elections[election].isNominated[candidate] = true;
    }

    /// @notice votes for a candidate in a single election
    /// @param _election the election to vote in
    /// @param candidate the candidate to vote for
    function vote(
        uint256 _election,
        address candidate
    )
        public
        override
        wasStakedBeforeElection(_election)
        onlyDuringVoting(_election)
    {
        if (elections[_election].hasVoted[msg.sender]) {
            revert AlreadyVoted();
        }
        if (elections[_election].isNominated[candidate] == false) {
            revert CandidateNotNominated();
        }
        if (
            elections[_election].theElectionType == Enums.electionType.community
        ) {
            uint256 userStaked = stakingRewardsV2.balanceAtTime(
                msg.sender,
                elections[_election].startTime
            );
            elections[_election].totalVote += userStaked;
        }
        elections[_election].hasVoted[msg.sender] = true;
        uint newNumberOfVotes = elections[_election].voteCounts[candidate] + stakingRewardsV2.balanceAtTime( //todo: test for staking amounts addition
                msg.sender,
                elections[_election].startTime
            );
        elections[_election].candidateAddresses = _sortCandidates(
            _election,
            candidate,
            newNumberOfVotes
        );
        elections[_election].voteCounts[candidate] = newNumberOfVotes;
    }

    /// @dev starts an election internally by recording state
    function _startElection(Enums.electionType electionType) internal {
        uint256 electionNumber = electionCounter;
        electionCounter++;
        elections[electionNumber].startTime = block.timestamp;
        elections[electionNumber].isFinalized = false;
        elections[electionNumber].theElectionType = electionType;
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

    /// @dev helper function to determine if a voter was staked before the election start
    function _wasStakedBeforeElection(
        address voter,
        uint256 _election
    ) internal view returns (bool isStaker) {
        uint256 electionStartTime = elections[_election].startTime;
        if (stakingRewardsV2.balanceAtTime(voter, electionStartTime) > 0) {
            return true;
        } else {
            return false;
        }
    }

    function _checkIfQuorumReached(
        uint256 _election
    ) internal view returns (bool) {
        uint256 electionStartTime = elections[_election].startTime;
        uint256 quorumPercentage = (elections[_election].totalVote * 100) /
            stakingRewardsV2.totalSupplyAtTime(electionStartTime);
        if (quorumPercentage < QUORUM) {
            return false;
        } else {
            return true;
        }
    }

    /// @dev internal function to finalize elections depending on type
    function _finalizeElection(uint256 _election) internal {
        elections[_election].isFinalized = true;
        if (
            elections[_election].theElectionType == Enums.electionType.scheduled
        ) {
            /// @dev this is for a full election
            address[5] memory winners;
            winners[0] = elections[_election].candidateAddresses[0];
            winners[1] = elections[_election].candidateAddresses[1];
            winners[2] = elections[_election].candidateAddresses[2];
            winners[3] = elections[_election].candidateAddresses[3];
            winners[4] = elections[_election].candidateAddresses[4];
            council = winners;
        } else if (
            elections[_election].theElectionType == Enums.electionType.community
        ) {
            if (_checkIfQuorumReached(_election)) {
                /// @dev this is for a full election
                address[5] memory winners;
                winners[0] = elections[_election].candidateAddresses[0];
                winners[1] = elections[_election].candidateAddresses[1];
                winners[2] = elections[_election].candidateAddresses[2];
                winners[3] = elections[_election].candidateAddresses[3];
                winners[4] = elections[_election].candidateAddresses[4];
                council = winners;
            } else {
                /// @dev do nothing because quorum not reached
                //todo: maybe emit an event that quorum was not reached
            }
        } else if (
            elections[_election].theElectionType == Enums.electionType.single
        ) {
            /// @dev this is for a single election
            address winner = elections[_election].candidateAddresses[0];
            for (uint i = 0; i < council.length; i++) {
                if (council[i] == address(0)) {
                    council[i] = winner;
                    break;
                }
            }
        }
    }

    /// @notice The 1 sweep O(n) sorting algorithm
    /// @dev (this only works because only 1 item is unsorted each time):
    function _sortCandidates(
        uint256 _election,
        address voteeName,
        uint256 newNumOfVotes
    ) internal view returns (address[] memory newCandidates) {
        //todo: redo with new linked list system

        address[] memory candidates = elections[_election].candidateAddresses;
        newCandidates = new address[](candidates.length);
        bool hasSwapped = false;
        bool hasReachedVotee = false;

        for (uint256 i = 0; i < candidates.length; i++) {
            address candidate = candidates[i];
            // keep it in place
            if (elections[_election].voteCounts[candidate] >= newNumOfVotes)
                newCandidates[i] = candidate;
                // either swap, get previous one, or keep it in place depending on stage in sweep
            else if (
                elections[_election].voteCounts[candidate] < newNumOfVotes
            ) {
                if (!hasSwapped && !hasReachedVotee) {
                    // swap it (first iteration in this block)
                    newCandidates[i] = voteeName;
                    hasSwapped = true;
                    // get previous one (from 2nd iteration in this block until we reach the votee)
                } else if (!hasReachedVotee)
                    newCandidates[i] = candidates[i - 1];
                    // keep it in place (all iterations in this block after the votee)
                else newCandidates[i] = candidate;
            }
            if (candidate == voteeName) {
                hasReachedVotee = true;
            }
        }
        return newCandidates;
    }

    /// @dev internal helper function cancel ongoing elections when a scheduled election starts
    /// @dev we assume there is always a motivated party to finalize finished elections promptly
    /// otherwise previous elections will be nullified
    function _cancelOngoingElections() internal {
        for (uint i = lastFinalizedElection; i < electionCounter; i++) {
            if (elections[i].isFinalized == false) {
                elections[i].isFinalized = true;
            }
        }
        lastFinalizedElection = electionCounter;
    }
}
