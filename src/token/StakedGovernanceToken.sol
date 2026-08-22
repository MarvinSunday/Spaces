// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title StakedGovernanceToken
/// @author Marvin Sunday (@MarvinSunday4 on X)
/// @notice A vote-escrow wrapper around a DAO's GovernanceToken. Holders
///         must stake (commit) their underlying tokens here to receive
///         voting power - staking mints an equal amount of this token 1:1,
///         and it's *this* token that carries ERC20Votes checkpointing and
///         delegation, exactly as the underlying token did on its own.
///         Unstaking burns the staked balance, removes the voting power,
///         and returns the underlying tokens.
/// @dev Governance.sol only ever treats `governanceToken` as an opaque
///      address implementing IGovernanceToken (balanceOf, getVotes,
///      getPastVotes, getPastTotalSupply, delegate, transfer, etc). This
///      contract satisfies that interface directly - ERC20 + ERC20Votes
///      already provides every method Governance calls - so a DAO can
///      point `governanceToken` at this contract instead of the raw
///      GovernanceToken with zero changes to Governance.sol itself. See
///      Governance.setGovernanceToken for how an existing DAO migrates to
///      this staking model without touching its Treasury.
contract StakedGovernanceToken is ERC20Permit, ERC20Votes, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The underlying governance token being staked.
    IERC20 public immutable underlying;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error ZeroUnderlying();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address underlying_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        if (underlying_ == address(0)) revert ZeroUnderlying();
        underlying = IERC20(underlying_);
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE / UNSTAKE
    //////////////////////////////////////////////////////////////*/

    /// @notice Commits `amount` of the underlying governance token to this
    ///         contract in exchange for an equal amount of staked voting
    ///         power. Requires prior approval of this contract to spend
    ///         `amount` of the underlying token.
    /// @dev Auto-delegates to self on first stake, so voting power is
    ///      active immediately without a separate delegate() call - this
    ///      is the single most common footgun with plain ERC20Votes
    ///      (holding tokens with zero active voting weight because
    ///      delegation was never called). An account that has already
    ///      delegated elsewhere keeps that delegation on subsequent stakes.
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        if (delegates(msg.sender) == address(0)) {
            _delegate(msg.sender, msg.sender);
        }

        underlying.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);

        emit Staked(msg.sender, amount);
    }

    /// @notice Burns `amount` of staked voting power and returns the
    ///         equivalent underlying tokens.
    /// @dev Voting power for any proposal already snapshotted before this
    ///      call is unaffected - ERC20Votes checkpoints are historical, so
    ///      unstaking cannot retroactively invalidate a vote already cast
    ///      or a proposal's already-recorded quorum/approval snapshot.
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _burn(msg.sender, amount);
        underlying.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                REQUIRED OVERRIDES (OZ MULTIPLE INHERITANCE)
    //////////////////////////////////////////////////////////////*/

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
