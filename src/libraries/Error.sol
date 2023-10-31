// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Error {
	error ZeroAddress();
	error ZeroAmount();
	error Unauthorized();
	error ElectionCannotStart();
	error ElectionFinalizedOrInvalid();
	error ElectionNotReadyToBeFinalized();
	error ElectionAlreadyOngoing();
	error ElectionNotCancelable();
	error NotInNominationWindow();
	error NotInVotingWindow();
	error CandidateAlreadyNominated();
	error CandidateNotNominated();
	error CallerIsNotStaking();
	error AlreadyVoted();
	error CandidateAlreadyInCouncil();
	error NotEnoughMembersInCouncil();
	error NoSeatAvailableInCouncil();
	error NotInCouncil();
}
