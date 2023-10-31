// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

interface IElectionModule {
	enum ElectionType {
		Scheduled,
		Community,
		Replacement
	}

	enum ElectionStatus {
		Invalid,
		Ongoing,
		Finalized
	}

	struct Election {
		uint256 startTime;
		uint256 totalVotes;
		ElectionStatus status;
		ElectionType electionType;
		EnumerableSet.AddressSet candidates;
		EnumerableSet.AddressSet winners;
		mapping(address => uint256) voteCounts;
		mapping(address => bool) hasVoted;
	}

	event ElectionStarted(uint256 indexed electionId, ElectionType indexed electionType);
	event ElectionCanceled(uint256 indexed electionId);
	event CandidateNominated(uint256 indexed electionId, address indexed candidate);
	event VoteRecorded(uint256 indexed electionId, address indexed voter, address candidate);
	event ElectionFinalized(uint256 indexed electionId);
	event QuorumThresholdSet(uint256 oldThreshold, uint256 newThreshold);
}
