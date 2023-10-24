// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Error {
	error ZeroAddress();
	error ZeroAmount();
	error ElectionNotReadyToBeStarted();
	error ElectionAlreadyFinalizedOrInvalid();
	error ElectionNotReadyToBeFinalized();
	error ElectionNotCancelable();
	error NotInNominationWindow();
	error NotInVotingWindow();
	error CandidateAlreadyNominated();
	error CandidateNotNominated();
	error CandidateAlreadyInCouncil();
	error NotStakingBeforeElection();
	error AlreadyVoted();
}
