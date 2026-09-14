// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ISwitchboard } from "@switchboard-xyz/on-demand-solidity/interfaces/ISwitchboard.sol";
import { SwitchboardTypes } from "@switchboard-xyz/on-demand-solidity/libraries/SwitchboardTypes.sol";
import { IRandomnessSource } from "./IRandomnessSource.sol";

/// @title SwitchboardRandomnessAdapter
/// @author Marvin Sunday
/// @notice Wraps Switchboard's On-Demand Randomness (ISwitchboard) behind
///         the shared IRandomnessSource interface.
/// @dev Switchboard is a PULL-based oracle, unlike Chainlink's push/
///      callback model - this is a real, structural difference worth
///      understanding before deploying with it:
///
///      1. This adapter calls `switchboard.createRandomness(requestId,
///         minSettlementDelay)` to register the request.
///      2. After `minSettlementDelay` has passed, someone must fetch the
///         oracle's signed response OFF-CHAIN (via Switchboard's
///         TypeScript SDK) and submit it on-chain by calling
///         `settleRandomness(encodedRandomness)` DIRECTLY on the
///         Switchboard contract - not on this adapter, and not something
///         this adapter can do on its own, since it requires off-chain
///         data this contract has no way to fetch.
///      3. Once settled, this adapter's `getRandomness`/`isFulfilled`
///         simply read the result back from Switchboard's own storage.
///
///      In practice, step 2 needs a keeper - some off-chain process
///      (e.g. the DAO's own bot backend) that watches for pending
///      requests and submits the settlement transaction once ready.
///      Nothing in this contract or SortitionGovernance does that
///      automatically; it must be run as a separate service.
///
///      Verified against the real, installed Switchboard on-demand-solidity
///      package (switchboard-xyz/on-demand-solidity, v1.1.0) - not written
///      from documentation snippets alone.
contract SwitchboardRandomnessAdapter is IRandomnessSource {
    ISwitchboard public immutable switchboard;

    /// @notice Minimum seconds Switchboard must wait before a request can
    ///         be settled - passed through to every request.
    uint64 public immutable minSettlementDelay;

    /// @notice Tracks which request IDs this adapter has actually issued,
    ///         so `requestRandomness` can reject accidental reuse before
    ///         even reaching Switchboard.
    mapping(bytes32 => bool) public requested;

    error ZeroAddress();
    error AlreadyRequested();
    error NotYetSettled();

    constructor(address switchboard_, uint64 minSettlementDelay_) {
        if (switchboard_ == address(0)) revert ZeroAddress();
        switchboard = ISwitchboard(switchboard_);
        minSettlementDelay = minSettlementDelay_;
    }

    /// @inheritdoc IRandomnessSource
    function requestRandomness(bytes32 requestId) external payable {
        if (requested[requestId]) revert AlreadyRequested();
        requested[requestId] = true;

        switchboard.createRandomness(requestId, minSettlementDelay);
    }

    /// @inheritdoc IRandomnessSource
    function isFulfilled(bytes32 requestId) public view returns (bool) {
        SwitchboardTypes.Randomness memory r = switchboard.getRandomness(requestId);
        return r.settledAt != 0;
    }

    /// @inheritdoc IRandomnessSource
    function getRandomness(bytes32 requestId) external view returns (uint256) {
        if (!isFulfilled(requestId)) revert NotYetSettled();
        return switchboard.getRandomness(requestId).value;
    }
}
