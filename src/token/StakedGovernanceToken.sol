// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title StakedGovernanceToken
/// @author Marvin Sunday
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

    /// @notice Admin address - can transfer itself and designate which
    ///         single governance contract (if any) is allowed to lock
    ///         balances. Defaults to the deployer; not tied to any
    ///         constructor param change, so this stays fully compatible
    ///         with DAOFactory's existing deployment call.
    address public owner;

    /// @notice The one governance contract currently authorized to call
    ///         lock()/unlock() - address(0) means locking is disabled
    ///         entirely. Only needed by governance models that require
    ///         committed support to stay committed (ConvictionGovernance,
    ///         for example) - every other model in this system never
    ///         calls this at all, and stays exactly as liquid as before.
    address public authorizedLocker;

    /// @notice How much of an account's balance is currently locked -
    ///         neither transferable nor unstakable below this amount.
    mapping(address => uint256) public lockedBalance;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AuthorizedLockerUpdated(address indexed previousLocker, address indexed newLocker);
    event Locked(address indexed account, uint256 amount);
    event Unlocked(address indexed account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error ZeroUnderlying();
    error ZeroAddress();
    error Unauthorized();
    error InsufficientUnlockedBalance();
    error InsufficientLockedBalance();

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyAuthorizedLocker() {
        if (msg.sender != authorizedLocker) revert Unauthorized();
        _;
    }

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
        owner = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN (OWNER-ONLY)
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Designates which governance contract may lock/unlock
    ///         balances. Pass address(0) to disable locking entirely.
    function setAuthorizedLocker(address locker) external onlyOwner {
        emit AuthorizedLockerUpdated(authorizedLocker, locker);
        authorizedLocker = locker;
    }

    /*//////////////////////////////////////////////////////////////
                        LOCKING (AUTHORIZED LOCKER ONLY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Locks `amount` of `account`'s balance - it becomes neither
    ///         transferable nor unstakable until unlocked. Reverts if this
    ///         would lock more than the account's current unlocked
    ///         balance.
    function lock(address account, uint256 amount) external onlyAuthorizedLocker {
        uint256 newLocked = lockedBalance[account] + amount;
        if (newLocked > balanceOf(account)) revert InsufficientUnlockedBalance();
        lockedBalance[account] = newLocked;
        emit Locked(account, amount);
    }

    /// @notice Releases `amount` of a previously locked balance.
    function unlock(address account, uint256 amount) external onlyAuthorizedLocker {
        uint256 current = lockedBalance[account];
        if (amount > current) revert InsufficientLockedBalance();
        lockedBalance[account] = current - amount;
        emit Unlocked(account, amount);
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

    /// @dev Enforces locked balances on any outgoing movement - both a
    ///      plain transfer() and unstake()'s _burn() route through this
    ///      same hook, so both are correctly blocked below the locked
    ///      amount. Minting (from == address(0)) is never restricted.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        if (from != address(0)) {
            uint256 available = balanceOf(from) - lockedBalance[from];
            if (value > available) revert InsufficientUnlockedBalance();
        }
        super._update(from, to, value);
    }

    function nonces(address account)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(account);
    }
}
