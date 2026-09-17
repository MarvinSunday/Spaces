// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../token/GovernanceToken.sol";
import "../token/StakedGovernanceToken.sol";
import "../treasury/Treasury.sol";

/// @title DAOFactoryLib
/// @notice Shared deployment helper used by every per-model DAO factory in
///         this system - deploys and wires the three pieces every
///         token-based governance model needs (GovernanceToken,
///         StakedGovernanceToken, Treasury), exactly matching the
///         original DAOFactory's own deployment order and temporary-
///         controller handoff pattern. Every factory in this codebase
///         behaves identically for this shared part, regardless of which
///         governance model it ultimately wires up - only what happens
///         after this point (deploying the specific governance contract
///         and handing off control) differs per model.
/// @dev Library functions here are internal, so they compile inline into
///      each calling factory's own bytecode rather than requiring a
///      separate deployed library contract - `address(this)` inside
///      deployCore correctly resolves to whichever factory called it,
///      not to the library itself, since there is no DELEGATECALL
///      boundary for internal library calls.
library DAOFactoryLib {
    function deployCore(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address creator
    ) internal returns (GovernanceToken token, StakedGovernanceToken stakedToken, Treasury treasury) {
        // Initial supply goes to the DAO creator; the factory is only the
        // temporary Ownable owner so it can hand off minting rights to
        // governance once governance exists.
        token = new GovernanceToken(name, symbol, initialSupply, maxSupply, creator, address(this));
        stakedToken = new StakedGovernanceToken(address(token), string.concat("Staked ", name), string.concat("s", symbol));
        treasury = new Treasury(address(this));
    }
}
