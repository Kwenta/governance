# Governance Specification

## Common Election rules

-   Scheduled, Community or Replacement elections can be started only when `block.timestamp >= startTime`, with `startTime` specified in the constructor.
-   To avoid user confusion and UX nightmare, only one election can occur a the time.
-   An election needs to be finalized (validated or cancelled) for another one to be able to start.
-   Takes place over 3 weeks
    -   1 week for nominations
    -   2 weeks for voting
-   An election can be cancelled and will be considered invalid if:
    -   It has no candidates
    -   Not enough candidates are elected
    -   A scheduled election can be started (meaning any ongoing Replacement or Community election will be cancelled)

## Scheduled Elections

-   Scheduled election every 6 months (26 weeks)
    -   Can be started anytime within a 6 month window (likely will happen at the start)
    -   The 6 months window starts at `Election.startTime`, for finalized scheduled elections only.
    -   If previous scheduled election is cancelled/invalid, its `startTime` won't be taken into account for the new epoch calculation.
-   Cannot be started if a scheduled election is still in progress (i.e. overlap from last 6 month period)
-   Cancels any ongoing election
-   Full Election that replaces all 5 council members

## Community Re-Elections

-   Full Election that replaces all 5 council members
-   Community Re-Elections are triggered by a community member
-   A Quorum validates the election at the end of voting. No quorum -> invalid and ignored election
-   Quorum is set to 40% of the StakingRewardsV2 total supply but can be changed in the future
    -   User staked amounts are recorded when vote() is called
    -   combined user staked amounts / total supply must be >= quorum

## Council Member Elections

-   Single Election that replaces 1 council member
-   The council member's rights are removed at the start of the election
-   Can only be called by the Safe, meaning it requires a majority of signers to agree (typically 3/5)

## Council Member Steps Down

-   Single Election that replaces 1 council member
-   The council member's rights are removed at the start of the election
-   Council member can step down at any time (except when another election is ongoing), triggering a single election to replace the member
-   Cannot step down if last member
    -   due to a Safe requirement, there must always be at least 1 owner
