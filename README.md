# DAO Spaces

A governance-agnostic DAO framework — an original, from-scratch on-chain governance protocol where a DAO's treasury and its governance rules are kept as two separate, swappable pieces, rather than locked together.

Every module — proposal lifecycle, voting, quorum/approval math, timelocks, and every one of the ten governance models below — is implemented from scratch, purpose-built for this framework.

## Why this exists

Most EVM chains handle DAO governance one of two ways today:

- **Snapshot** — off-chain voting. Votes are signed messages, not transactions; nothing is actually enforced by the blockchain, and someone still has to manually execute whatever the vote decided.
- **A custom-built governance system** — hard to get right, and once deployed, usually locked in. Changing the rules later means migrating the entire treasury to a new setup, and a DAO is stuck with whichever single decision-making model it launched with.

DAO Spaces solves both: every governance action is carried out automatically, fully on-chain, and a DAO isn't locked into one way of deciding things. It can start with a small trusted board, grow into token-weighted voting, switch to quadratic voting to reduce whale influence, adopt continuous "conviction" voting instead of snap votes, let a randomly-drawn council govern instead of an elected one, or let markets themselves decide outcomes — all without the treasury ever moving.

## Architecture

```
┌──────────────┐        controls        ┌──────────────┐
│  Governance   │ ─────────────────────▶ │   Treasury    │
│ (swappable —  │                        │ (stays put —  │
│  any of 10    │ ◀───────────────────── │  holds funds) │
│  models)      │      trusts            └──────────────┘
└──────────────┘
       │
       │ controls (mint rights)
       ▼
┌───────────────────┐        wraps        ┌──────────────────────┐
│  GovernanceToken    │ ◀─────────────────  │ StakedGovernanceToken │
│  (raw, liquid,      │       stake()        │ (voting power lives   │
│   transferable)     │ ─────────────────▶  │  here, and can be      │
└───────────────────┘                       │  locked when a model   │
                                             │  requires it — see     │
                                             │  ConvictionGovernance) │
                                             └──────────────────────┘
```

`Treasury`'s entire trust model is one question: *"is the caller my registered `governance` address?"* — nothing about how that address arrived at a decision matters to it. That single design choice is what makes every model below a genuine drop-in replacement for any other, not a special case.

## Governance models

Ten independent implementations, all satisfying the same trusted-caller relationship with `Treasury`:

| Model | How it decides |
|---|---|
| **Token-weighted** (`Governance.sol`) | Classic one-token-one-vote, snapshot-based |
| **Delegated** | Token holders elect a small council; only the council proposes and votes |
| **Board (Multisig)** | N-of-M designated signers approve directly — no token required at all |
| **Quadratic** | Voting weight is the square root of staked balance, dampening whale influence |
| **Optimistic** | Proposals pass by default after a challenge window, unless disputed and voted down |
| **Conviction** | Continuous support accumulates over time rather than a single snap vote |
| **Sortition** | Council seats filled by a verifiably random draw from an opt-in eligible pool |
| **Liquid** | Direct voting always available, plus fully revocable delegation to anyone, with bounded transitive chains |
| **Sowellian** | A pari-mutuel prediction market on proposal outcomes, with bonded resolution and an optimistic challenge process |
| **Decision Markets** | Pure market-based resolution: a proposal's fate is decided by comparing two live trading markets against each other over a fixed window, with no oracle, resolver, or vote involved at all — see [Decision Markets](#decision-markets) below |

Each model lives in its own folder under `src/governance/`, and each is independently tested.

## Contracts

| Contract | Responsibility |
|---|---|
| `governance/Governance.sol` + supporting files | Token-weighted orchestration — proposal creation, voting, quorum/approval, timelocks, execution |
| `governance/delegate/`, `board/`, `quadratic/`, `optimistic/`, `conviction/`, `sortition/`, `liquid/`, `sowellian/`, `futarchy/` | The other nine governance models, each self-contained |
| `token/GovernanceToken.sol` | The raw, liquid ERC20 (with `ERC20Votes` built in). Minting is `Governance`-controlled. |
| `token/StakedGovernanceToken.sol` | Vote-escrow wrapper. Holders must **stake** the raw token here to receive voting power. Supports an optional, opt-in lock (used by `ConvictionGovernance`) so committed support can't be sold or unstaked out from under a proposal. |
| `treasury/Treasury.sol` | Holds DAO funds. Only acts on instructions from whichever address is currently its registered `governance`. |
| `factory/DAOFactory.sol` | Deploys and wires together a full DAO using the original token-weighted governance model. *(Note: the other nine models don't yet have a factory path — see [Known gaps](#known-gaps).)* |
| `distribution/WelcomeDistributor.sol` | Optional: distributes a capped budget of raw tokens to new members, one claim per address. |
| `randomness/` | A provider-agnostic randomness interface (`IRandomnessSource`), with adapters for two real oracle networks — used by `SortitionGovernance` |
| `oracles/` | A provider-agnostic price-feed interface (`IMetricOracle`), with adapters for two real oracle networks — used by `SowellianGovernance` |

## Key design decisions

- **Governance and treasury are decoupled.** `Treasury` only checks "is the caller my registered `governance`?" — that address is swappable via `transferGovernance()`. A DAO can vote to move to an entirely different governance model, with a completely different decision-making mechanism, without the treasury's funds ever moving.
- **Voting power requires staking, not just holding**, in every token-based model. Plain balance carries zero voting weight — tokens must be explicitly committed via `StakedGovernanceToken.stake()`.
- **Snapshot-based, flash-loan-resistant voting** wherever a discrete vote happens — every proposal snapshots voting power at a fixed past block, so weight can't be manufactured and used in the same transaction a proposal appears. Where a model can't use a fixed snapshot at all (`ConvictionGovernance`'s continuous support has no single voting moment), committed tokens are locked instead, closing the same class of gap through a different mechanism.
- **Randomness and price data are provider-agnostic**, not hardcoded to one vendor. `SortitionGovernance` and `SowellianGovernance` each depend only on a small interface; which real oracle network sits behind it is a swappable, per-deployment choice.

## Decision Markets

The newest and most involved model in the library, worth its own explanation. Instead of a vote or a bet-then-verify prediction market, a proposal's two possible outcomes — pass and fail — each get their own live trading market, running in parallel over a fixed window. Real tokens are split into a matched pair of "pass" and "fail" conditional tokens; people trade whichever side they believe in; and at the end of the window, whichever market's time-weighted average price ended up meaningfully higher decides the outcome. Winning-side tokens redeem 1:1 for real value; losing-side tokens are worthless. Nothing about this needs an oracle, a human resolver, or a vote — the market's own price comparison **is** the verdict.

The underlying constant-product AMM used to run these markets is a derivative of Uniswap V2's official core contracts (`github.com/Uniswap/v2-core`), licensed GPL-3.0-or-later — confirmed by direct comparison against that real source before reuse. `src/governance/futarchy/DecisionMarketPair.sol` carries that same GPL-3.0-or-later license accordingly; every other contract in this repository is MIT.

**Status note:** this is, along with `SowellianGovernance`, the highest-stakes and most recently built part of the library — it moves real capital based on market-driven resolution. Test it thoroughly before it touches anything real.

## Setup

```bash
git submodule update --init --recursive
forge install
forge build
```

Two of the newer models pull in additional npm-based dependencies (used by the randomness and oracle adapters):

```bash
npm install @switchboard-xyz/on-demand-solidity@1.1.0
npm install @chainlink/contracts@1.4.0
```

with matching entries in `remappings.txt`:

```
@switchboard-xyz/on-demand-solidity/=node_modules/@switchboard-xyz/on-demand-solidity/
@chainlink/contracts/=node_modules/@chainlink/contracts/
```

## Testing

```bash
forge test
```

Every governance model, the treasury/token/factory core, the randomness and oracle adapters, and the full futarchy system each have their own dedicated test file under `test/`.

## Deployment

The original token-weighted model has a full deployment path:

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

The other nine governance models don't yet have deploy scripts — see below.

## Known gaps

- **No factory path for the newer nine governance models.** `DAOFactory` only deploys the original token-weighted model. Deploying `BoardGovernance`, `SortitionGovernance`, `DecisionMarketsGovernance`, and the rest currently means deploying and wiring the pieces manually.
- **No deploy scripts** for any of the nine newer models, matching the point above.
- **Decision Markets' seed liquidity isn't automatically reclaimed.** The LP tokens minted when a proposal's markets are seeded stay held by the governance contract indefinitely — recoverable only via a future governance action, not built as a feature yet.