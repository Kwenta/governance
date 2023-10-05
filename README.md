# Governance Specification

## Scheduled Elections
- Scheduled election every 6 months (26 weeks)
    - Can be started anytime within a 6 month window (likely will happen at the start)
    - These 6 month windows or "epochs" start based off the startTime in the constructor
    - Scheduled elections cannot start before the startTime
- Cannot be started if a scheduled election is still in progress (i.e. overlap from last 6 month period)
- Takes place over 3 weeks
    - 1 week for nominations
    - 2 weeks for voting
- Cancels any ongoing elections and halts any new elections during the duration of the scheduled election
- Full Election that replaces all 5 council members

## Council Member Elections
- Single Election that replaces 1 council member
- The council member's rights are removed at the start of the election
- Council members require a majority threshold (typically 3/5) to boot another council member and trigger an election
- Completely implemented through GnosisSafe functionality
    - because of OwnerManage.sol requirements, threshold has to be revised as needed when removing members in single elections
    - (safe requires that the threshold is less than or equal to the number of owners, and new owners cannot be == 0)

## Community Re-Elections
- Full Election that replaces all 5 council members
- Community Re-Elections are triggered by a community member
- A Quorum validates the election at the end of voting. No quorum -> invalid and ignored election
- Quorum is set to 40% of the total supply but can be changed in the future
    - User staked amounts are recorded when vote() is called
    - combined user staked amounts / total supply must be >= quorum
- Cannot be started if one started within the last 3 weeks - to prevent spamming

## Council Member Steps Down
- Single Election that replaces 1 council member
- The council member's rights are removed at the start of the election
- Council member can step down at any time (except during a scheduled election), triggering a single election to replace the member
- Cannot step down if last member
    - due to a Safe requirement, there must always be at least 1 owner


# Notes for Continued Implementation:

- common ideas: scheduled elections cancel current elections, and halt new elections from starting during its 3 week time frame. Also community re-elections can't start if one was started within the last 3 weeks
- explanation: this is to prevent sticky elections - results are applied from elections when finalizeElection() is called, so if a new election were to start and end before the previous one is finalized, the results of the previous election could be finalized and applied now (making the results of the new election overwritten, which is undesired)

- CI is currently broken because a contract in the token repo uses a hardhat dependency whereas this repo uses foundry (and we want to keep this repo purely foundry). This has been bandaged locally temporarily by going into lib/token, then installing npm dependencies, and then adding this to the foundry.toml ```@openzeppelin/=lib/token/node_modules/@openzeppelin```

- todo: community re-elections should not be able to start if the last one !isElectionFinalized()
    - currently its if the last one was started within the last 3 weeks. this is innacurate though because overlapping could happen like specified above

- council array in AutomatedVoting was chosen to be a fixed array of 5 rather than a dynamic array

- multiple elections can be ongoing, except for scheduled elections
    - meaning the other 3 elections can be ongoing at the same time
    - multiple different single elections can be ongoing at the same time
        - multiple council member elections at the same time
        - multiple step down elections at the same time
    - BUT multiple scheduled elections can't happen at the same time
    - and multiple Community re-elections can't happen at the same time

- in the code, council member elections and step down elections are grouped into the same enum of "replacement", can also be thought of as single elections

- winners of an election are determined by taking the top 5 (or 1 for single elections) candidates with the most votes (this happens in _finalizeElection())
    - taken from the candidateAddress[] array
    - canidates are actively sorted as votes come in. candidateAddress[] array is shuffled so that left-->right, is most-->least votes
    - sorting is implemented in the _sortCandidates() function
        - currently using a O(n) insertion algorithm but needs to be changed to a O(1) linked list system
- vote counts are based off of the number of tokens staked by the voter
- voters can only vote for one candidate but can nominate as many as they want
- todo: change to --> voters can change their vote at any time during the voting period

- staked amounts are always taken historically from the startTime of an election - to prevent manipulation
    - this goes for both user staked amounts and totalSupply checks (for quorum)

- Scheduled elections cannot start before the startTime
- todo: this should be implemented as well for the other 3 elections

- At the end, AutomatedVoting needs upgradeability
    - details not specified yet

## Safe Integration:
- AutomatedVoting will inherit from GovernorModule which will have the module logic
- The starting and finalizing of elections should remove and add members to the safe as needed
- GovernorModule will be able to add owners, remove owners, change threshold, and swap owners (for full elections)
- Threshold is default 3/5 but needs to be changed according to the number of owners. There should always be a majority threshold.
    - 5 owners --> 3/5
    - 4 owners --> 3/4
    - 3 owners --> 2/3
    - 2 owners --> 2/2
    - 1 owner --> 1/1
- A guard (Safe hook) will have to be put in place after enabling the module to prevent any owners from removing the module and circumenting the governance process

## Tentative Deployment Process:
1. Deploy ```AutomatedVoting.sol```
2. Enable ```AutomatedVoting.sol``` as a module on the safe
3. Add a guard to the safe to prevent owners from removing the module/other exploits

## Relevant contracts for fundamental understanding:
```StakingRewardsV2.sol```, ```Safe.sol```, ```OwnerManager.sol```, ```ModuleManage.sol```, and ```GuardManager.sol```

## TLDR: High Level Overview of TODO:
1. finish minor TODOs in the AutomatedVoting.sol code (add/fix tests as neccesary)
2. finish implementing GovenorModule and test
3. Implement a Safe hook (guard) and test
4. Add upgradeability to AutomatedVoting.sol
5. fix echidna invariant testing then run echidna and mutation testing
6. (minor) fix CI
7. Polish
8. Audit
9. Deploy

# foundry-scaffold

[![Github Actions][gha-badge]][gha] 
[![Foundry][foundry-badge]][foundry] 
[![License: MIT][license-badge]][license]

[gha]: https://github.com/Kwenta/foundry-scaffold/actions
[gha-badge]: https://github.com/Kwenta/foundry-scaffold/actions/workflows/test.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

## Contracts

```
script/TestnetDeploy.s.sol ^0.8.13
└── lib/forge-std/src/Script.sol >=0.6.0 <0.9.0
    ├── lib/forge-std/src/console.sol >=0.4.22 <0.9.0
    ├── lib/forge-std/src/console2.sol >=0.4.22 <0.9.0
    └── lib/forge-std/src/StdJson.sol >=0.6.0 <0.9.0
        └── lib/forge-std/src/Vm.sol >=0.6.0 <0.9.0
src/Counter.sol ^0.8.13
test/Counter.t.sol ^0.8.13
├── lib/forge-std/src/Test.sol >=0.6.0 <0.9.0
│   ├── lib/forge-std/src/Script.sol >=0.6.0 <0.9.0 (*)
│   └── lib/forge-std/lib/ds-test/src/test.sol >=0.5.0
└── src/Counter.sol ^0.8.13
```

## Code Coverage

```
+----------------------------+---------------+---------------+---------------+---------------+
| File                       | % Lines       | % Statements  | % Branches    | % Funcs       |
+============================================================================================+
| script/TestnetDeploy.s.sol | 0.00% (0/3)   | 0.00% (0/4)   | 100.00% (0/0) | 0.00% (0/1)   |
|----------------------------+---------------+---------------+---------------+---------------|
| src/Counter.sol            | 100.00% (2/2) | 100.00% (2/2) | 100.00% (0/0) | 100.00% (2/2) |
|----------------------------+---------------+---------------+---------------+---------------|
| Total                      | 40.00% (2/5)  | 33.33% (2/6)  | 100.00% (0/0) | 66.67% (2/3)  |
+----------------------------+---------------+---------------+---------------+---------------+
```

## Run tests
```
forge test --fork-url $(grep MAINNET_RPC_URL .env | cut -d '=' -f2) -vvv
```

## Deployment Addresses

#### Optimism

#### Optimism Goerli