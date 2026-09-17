# DAO Spaces

A governance-agnostic DAO framework — an original, from-scratch on-chain governance protocol where a DAO's treasury and its governance rules are kept as two separate, swappable pieces, rather than locked together.

Every module — proposal lifecycle, voting, quorum/approval math, timelocks, and every one of the ten governance models below — is implemented from scratch, purpose-built for this framework.

## Why this exists

Most EVM chains handle DAO governance one of two ways today:

- **Snapshot** — off-chain voting. Votes are signed messages, not transactions; nothing is actually enforced by the blockchain, and someone still has to manually execute whatever the vote decided.
- **A custom-built governance system** — hard to get right, and once deployed, usually locked in. Changing the rules later means migrating the entire treasury to a new setup, and a DAO is stuck with whichever single decision-making model it launched with.

DAO Spaces solves both: every governance action is carried out automatically, fully on-chain, and a DAO isn't locked into one way of deciding things. It can start with a small trusted board, grow into token-weighted voting, switch to quadratic voting to reduce whale influence, adopt continuous "conviction" voting instead of snap votes, let a randomly-drawn council govern instead of an elected one, or let markets themselves decide outcomes — all without the treasury ever moving. Every one of the ten models has a complete path from zero to a live, wired-up DAO: a factory and a pair of deploy scripts, not just a contract sitting unreachable in `src/`.

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

Ten independent implementations, all satisfying the same trusted-caller relationship with `Treasury`, each with its own factory:

| Model | How it decides | Factory |
|---|---|---|
| **Token-weighted** (`Governance.sol`) | Classic one-token-one-vote, snapshot-based | `DAOFactory` |
| **Delegated** | Token holders elect a small council; only the council proposes and votes | `DelegateDAOFactory` |
| **Board (Multisig)** | N-of-M designated signers approve directly — no token required at all | `BoardDAOFactory` |
| **Quadratic** | Voting weight is the square root of staked balance, dampening whale influence | `QuadraticDAOFactory` |
| **Optimistic** | Proposals pass by default after a challenge window, unless disputed and voted down | `OptimisticDAOFactory` |
| **Conviction** | Continuous support accumulates over time rather than a single snap vote | `ConvictionDAOFactory` |
| **Sortition** | Council seats filled by a verifiably random draw from an opt-in eligible pool | `SortitionDAOFactory` |
| **Liquid** | Direct voting always available, plus fully revocable delegation to anyone, with bounded transitive chains | `LiquidDAOFactory` |
| **Sowellian** | A pari-mutuel prediction market on proposal outcomes, with bonded resolution and an optimistic challenge process | `SowellianDAOFactory` |
| **Decision Markets** | Pure market-based resolution: a proposal's fate is decided by comparing two live trading markets against each other over a fixed window, with no oracle, resolver, or vote involved at all — see [Decision Markets](#decision-markets) below | `DecisionMarketsDAOFactory` |

Each model lives in its own folder under `src/governance/`, and each is independently tested.

## Contracts

| Contract | Responsibility |
|---|---|
| `governance/Governance.sol` + supporting files | Token-weighted orchestration — proposal creation, voting, quorum/approval, timelocks, execution |
| `governance/delegate/`, `board/`, `quadratic/`, `optimistic/`, `conviction/`, `sortition/`, `liquid/`, `sowellian/`, `futarchy/` | The other nine governance models, each self-contained |
| `governance/opportunity-market/` | A separate, non-governance system — confidential opportunity backing. See [Opportunity Markets](#opportunity-markets) below. |
| `token/GovernanceToken.sol` | The raw, liquid ERC20 (with `ERC20Votes` built in). Minting is `Governance`-controlled. |
| `token/StakedGovernanceToken.sol` | Vote-escrow wrapper. Holders must **stake** the raw token here to receive voting power. Supports an optional, opt-in lock (used by `ConvictionGovernance`) so committed support can't be sold or unstaked out from under a proposal. |
| `treasury/Treasury.sol` | Holds DAO funds. Only acts on instructions from whichever address is currently its registered `governance`. |
| `factory/` | One factory per governance model — `DAOFactory` for the original, plus nine more (`DelegateDAOFactory`, `BoardDAOFactory`, `QuadraticDAOFactory`, `OptimisticDAOFactory`, `ConvictionDAOFactory`, `SortitionDAOFactory`, `LiquidDAOFactory`, `SowellianDAOFactory`, `DecisionMarketsDAOFactory`), all sharing a `DAOFactoryLib` deployment helper for the common token/treasury setup. |
| `distribution/WelcomeDistributor.sol` | Optional: distributes a capped budget of raw tokens to new members, one claim per address. |
| `randomness/` | A provider-agnostic randomness interface (`IRandomnessSource`), with adapters for two real oracle networks — used by `SortitionGovernance` |
| `oracles/` | A provider-agnostic price-feed interface (`IMetricOracle`), with adapters for two real oracle networks — used by `SowellianGovernance` |

## Key design decisions

- **Governance and treasury are decoupled.** `Treasury` only checks "is the caller my registered `governance`?" — that address is swappable via `transferGovernance()`. A DAO can vote to move to an entirely different governance model, with a completely different decision-making mechanism, without the treasury's funds ever moving.
- **Voting power requires staking, not just holding**, in every token-based model. Plain balance carries zero voting weight — tokens must be explicitly committed via `StakedGovernanceToken.stake()`.
- **Snapshot-based, flash-loan-resistant voting** wherever a discrete vote happens — every proposal snapshots voting power at a fixed past block, so weight can't be manufactured and used in the same transaction a proposal appears. Where a model can't use a fixed snapshot at all (`ConvictionGovernance`'s continuous support has no single voting moment), committed tokens are locked instead, closing the same class of gap through a different mechanism.
- **Randomness and price data are provider-agnostic**, not hardcoded to one vendor. `SortitionGovernance` and `SowellianGovernance` each depend only on a small interface; which real oracle network sits behind it is a swappable, per-deployment choice.
- **Every factory shares one deployment helper, not nine copies of the same logic.** `DAOFactoryLib.deployCore(...)` is an internal library function, inlined into each calling factory's own bytecode — `address(this)` inside it correctly resolves to whichever factory called it. `BoardDAOFactory` is the one exception, since `BoardGovernance` needs no token at all.

## Decision Markets

The newest and most involved governance model in the library, worth its own explanation. Instead of a vote or a bet-then-verify prediction market, a proposal's two possible outcomes — pass and fail — each get their own live trading market, running in parallel over a fixed window. Real tokens are split into a matched pair of "pass" and "fail" conditional tokens; people trade whichever side they believe in; and at the end of the window, whichever market's time-weighted average price ended up meaningfully higher decides the outcome. Winning-side tokens redeem 1:1 for real value; losing-side tokens are worthless. Nothing about this needs an oracle, a human resolver, or a vote — the market's own price comparison **is** the verdict.

The underlying constant-product AMM used to run these markets is a derivative of Uniswap V2's official core contracts (`github.com/Uniswap/v2-core`), licensed GPL-3.0-or-later — confirmed by direct comparison against that real source before reuse. `src/governance/futarchy/DecisionMarketPair.sol` carries that same GPL-3.0-or-later license accordingly; every other contract in this repository is MIT.

Seed liquidity for a proposal's two markets is reclaimable after finalization via `reclaimLiquidity()` — permissionless to call, but the recovered funds always return to the original proposer, since that capital was theirs, not a punitive bond.

**Status note:** this is, along with `SowellianGovernance`, the highest-stakes and most recently built part of the library — it moves real capital based on market-driven resolution. Test it thoroughly before it touches anything real.

## Opportunity Markets

A separate system from the ten governance models above — it never touches a `Treasury` and doesn't execute DAO proposals. `OpportunityMarketFactory` lets anyone deploy their own independent market: list candidate opportunities, back the ones you believe in with a private amount, and — crucially — **which opportunity you backed stays encrypted too, not just how much.** Nobody's own stake is ever redistributed to anyone else; the deployer separately commits a reward pool, paid out only to backers of whichever opportunity the deployer later confirms turned out real.

Built on Zama's fhEVM (Fully Homomorphic Encryption) — encrypted amounts and targets are computed on directly, without ever being decrypted on-chain. The one deliberate exception: the deployer is granted standing decrypt permission on every individual bet (for their own statistics), alongside the backer's own permission — nobody else, public or otherwise, can decrypt either value.

**Network note:** this targets **Ethereum Sepolia**, not Monad. Zama's confidential-computing infrastructure (the coprocessor, ACL, and KMS contracts `FHE.sol` depends on) is, as of this writing, only genuinely deployed on Ethereum Sepolia and Ethereum mainnet — not on Monad, and not on Base or HyperEVM despite `$ZAMA` token activity existing on both of those (a bridged token is not the same as the confidential-computing platform itself). Point `--rpc-url` at Sepolia for anything in this section.

Setup needs two additional dependencies beyond the rest of this repo:

```bash
npm install @fhevm/solidity@0.13.3
forge install zama-ai/forge-fhevm
```

with matching entries in `remappings.txt`:

```
@fhevm/solidity/=node_modules/@fhevm/solidity/
encrypted-types/=node_modules/encrypted-types/
forge-fhevm/=lib/forge-fhevm/src/
```

and in `foundry.toml`:

```toml
evm_version = "cancun"
```

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

Opportunity Markets needs its own additional setup — see [Opportunity Markets](#opportunity-markets) above.

## Testing

```bash
forge test
```

Every governance model, the treasury/token/factory core, the randomness and oracle adapters, and the full futarchy system each have their own dedicated test file under `test/`. Opportunity Markets is tested against `forge-fhevm`, a Foundry-native library that deploys the real fhEVM host contracts inside the test environment rather than mocking them.

## Deployment

Every governance model follows the identical two-step shape: deploy that model's factory once, then call its `createDAO` (or, for Opportunity Markets, `createMarket`) as many times as needed. The original token-weighted model:

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

Every one of the other nine models has the same `Deploy<Model>DAOFactory.s.sol` / `Create<Model>DAO.s.sol` pair — `DeployDelegateDAOFactory.s.sol` + `CreateDelegateDAO.s.sol`, `DeployBoardDAOFactory.s.sol` + `CreateBoardDAO.s.sol`, and so on through `DecisionMarketsDAOFactory`. Each `Create*` script's own header comment lists its exact required and optional environment variables — they differ per model (`BoardGovernance` needs no token env vars at all; `DelegateGovernance` and `SortitionGovernance` take a comma-separated `INITIAL_COUNCIL` and derive council size from it automatically; `SortitionGovernance` additionally requires a real, already-deployed `RANDOMNESS_SOURCE` address, since that's genuine chain-specific infrastructure no factory should guess at).

Opportunity Markets follows the same shape but targets Sepolia and takes no config struct at all:

```bash
forge script script/DeployOpportunityMarketFactory.s.sol:DeployOpportunityMarketFactory \
  --rpc-url <sepolia-rpc-link> \
  --account <your-account> \
  --broadcast
```

```bash
export FACTORY_ADDRESS=0x...
export UNDERLYING_TOKEN=0x...

forge script script/CreateOpportunityMarket.s.sol:CreateOpportunityMarket \
  --rpc-url <sepolia-rpc-link> \
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

## Known gaps

- **Opportunity Markets' reward-pool payout math stops short of full on-chain automation.** Encrypted-by-encrypted division isn't supported by Zama's library at all, so the payout is computed as an encrypted multiply followed by a division against a publicly-revealed aggregate total (see the contract's own doc comment) — correct, but relies on a real, disclosed design constraint rather than a single clean operation.