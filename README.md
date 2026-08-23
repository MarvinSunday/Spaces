# Monad Spaces

A governance-agnostic DAO framework — an original, from-scratch on-chain governance protocol where a DAO's treasury and its governance rules are kept as two separate, swappable pieces, rather than locked together.

Not a fork of OpenZeppelin Governor or any existing framework. Every module — proposal lifecycle, voting, quorum/approval math, timelocks — is implemented from scratch.

## Why this exists

Most EVM chains handle DAO governance one of two ways today:

- **Snapshot** — off-chain voting. Votes are signed messages, not transactions; nothing is actually enforced by the blockchain, and someone still has to manually execute whatever the vote decided.
- **A custom-built governance system** — hard to get right, and once deployed, usually locked in. Changing the rules later means migrating the entire treasury to a new setup.

Monad Spaces solves both: every governance action is carried out automatically, fully on-chain, and a DAO's governance can evolve over time — new voting models, new quorum rules, even a full swap to a new `Governance` contract — without the treasury ever moving.

## Architecture

```
┌──────────────┐        controls        ┌──────────────┐
│  Governance   │ ─────────────────────▶ │   Treasury    │
│ (swappable —  │                        │ (stays put —  │
│  voting rules │ ◀───────────────────── │  holds funds) │
│  live here)   │      trusts            └──────────────┘
└──────────────┘
       │
       │ controls (mint rights)
       ▼
┌───────────────────┐        wraps        ┌──────────────────────┐
│  GovernanceToken    │ ◀─────────────────  │ StakedGovernanceToken │
│  (raw, liquid,      │       stake()        │ (voting power lives   │
│   transferable)     │ ─────────────────▶  │  here — must be       │
└───────────────────┘                       │  staked to vote)      │
                                             └──────────────────────┘
```

Every fund transfer, mint, or governance-config change goes through the same pipeline: propose → vote → quorum/approval check → timelock → execute. No address — not even a DAO's original creator — retains standing authority once it's live.

## Contracts

| Contract | Responsibility |
|---|---|
| `governance/Governance.sol` | Orchestration only — proposal creation, voting, quorum/approval enforcement, timelocks, execution. Holds no state of its own beyond what it inherits. |
| `governance/GovernanceStorage.sol` | Proposal storage, vote receipts, governance configuration. |
| `governance/GovernanceMath.sol` | Quorum, approval threshold, and config validation math. |
| `governance/GovernanceState.sol` | Proposal lifecycle state derivation. |
| `governance/GovernanceErrors.sol` / `GovernanceEvents.sol` | All custom errors and events. |
| `governance/Types.sol` | Shared structs and enums (`Proposal`, `GovernanceConfig`, `ProposalState`, `VoteType`, `DAOInfo`). |
| `token/GovernanceToken.sol` | The raw, liquid ERC20 (with `ERC20Votes` built in). Minting is `Governance`-controlled. |
| `token/StakedGovernanceToken.sol` | Vote-escrow wrapper. Holders must **stake** the raw token here to receive voting power — this is what `Governance` actually reads votes from. Auto-delegates to self on first stake. |
| `treasury/Treasury.sol` | Holds DAO funds (ETH + ERC20). Only acts on instructions from whichever address is currently its registered `governance`. |
| `factory/DAOFactory.sol` | Deploys and wires together a full DAO (token, staking wrapper, treasury, governance) in one transaction. |
| `distribution/WelcomeDistributor.sol` | Optional, standalone: distributes a capped budget of raw tokens to new members, one claim per address. Not part of the required core — deploy and fund separately if wanted. |

## Key design decisions

- **Governance and treasury are decoupled.** `Treasury` only checks "is the caller my registered `governance`?" — that address is swappable via `transferGovernance()`. A DAO can vote to move to an entirely new `Governance` contract without the treasury's funds ever moving.
- **Voting power requires staking, not just holding.** Plain token balance carries zero voting weight — tokens must be explicitly committed via `StakedGovernanceToken.stake()`. This is a deliberate choice to require real commitment before voting rights activate, and it composes cleanly: `Governance` treats the staking wrapper as an opaque address implementing the same interface a plain token would, so this required zero changes to `Governance.sol` itself.
- **Snapshot-based, flash-loan-resistant voting.** Every proposal snapshots voting power one block before its own creation block — voting weight can't be manufactured and used in the same block a proposal appears.

## Setup

```bash
git submodule update --init --recursive
forge install
forge build
```

## Testing

```bash
forge test
```

Full coverage across `Governance`, `Treasury`, `GovernanceToken`, `StakedGovernanceToken`, `DAOFactory`, `WelcomeDistributor`, plus end-to-end integration tests covering the full proposal lifecycle, quorum/approval edge cases, and governance-controlled minting/reconfiguration.

## Deployment

Two-step process — deploy the factory once, then create as many DAOs through it as needed:

```bash
forge script script/DeployDAOFactory.s.sol:DeployDAOFactory \
  --rpc-url <network-rpc-link> \
  --account <your-account> \
  --broadcast
```

```bash
export FACTORY_ADDRESS=0x...
export DAO_NAME="Your DAO"
export DAO_SYMBOL=SYM
export INITIAL_SUPPLY=1000000
export MAX_SUPPLY=10000000

forge script script/CreateDAO.s.sol:CreateDAO \
  --rpc-url <network-rpc-link> \
  --account <your-account> \
  --broadcast
```

Optional, per-DAO — set up new-member token distribution:

```bash
export TOKEN_ADDRESS=<underlying token address, not the staking wrapper>
export GOVERNANCE_ADDRESS=0x...
export OPERATOR_ADDRESS=<bot or admin wallet authorized to trigger distributions>

forge script script/DeployWelcomeDistributor.s.sol:DeployWelcomeDistributor \
  --rpc-url <network-rpc-link> \
  --account <your-account> \
  --broadcast
```
