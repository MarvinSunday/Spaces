// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ISwitchboard } from "@switchboard-xyz/on-demand-solidity/interfaces/ISwitchboard.sol";

/// @dev Matches SowellianGovernance's IMetricOracle interface exactly -
///      not imported directly to avoid a cross-folder dependency, same
///      pattern already used for the randomness adapters.
interface IMetricOracle {
    function latestValue() external view returns (int256 value, uint256 updatedAt);
}

/// @title SwitchboardPriceFeedAdapter
/// @author Marvin Sunday
/// @notice Wraps a Switchboard price/metric feed behind SowellianGovernance's
///         IMetricOracle interface.
/// @dev Switchboard feeds are PULL-based, same as their randomness product -
///      someone has to call `updateFeeds()` on the Switchboard contract
///      itself (with a fresh, oracle-signed payload fetched off-chain)
///      before this adapter's `latestValue()` reflects anything current.
///      This adapter does not do that itself; it only reads back whatever
///      was most recently pushed. In practice this needs a keeper - the
///      same operational requirement already flagged for
///      SwitchboardRandomnessAdapter, and one keeper process could cover
///      both if a DAO uses Switchboard for randomness and price data.
///
///      Verified against the real, installed Switchboard on-demand-solidity
///      package (switchboard-xyz/on-demand-solidity, v1.1.0) - not written
///      from documentation snippets alone.
contract SwitchboardPriceFeedAdapter is IMetricOracle {
    ISwitchboard public immutable switchboard;
    bytes32 public immutable feedId;

    error ZeroAddress();
    error FeedDoesNotExist();

    constructor(address switchboard_, bytes32 feedId_) {
        if (switchboard_ == address(0)) revert ZeroAddress();
        switchboard = ISwitchboard(switchboard_);
        feedId = feedId_;
        if (!switchboard.feedExists(feedId_)) revert FeedDoesNotExist();
    }

    /// @inheritdoc IMetricOracle
    function latestValue() external view returns (int256 value, uint256 updatedAt) {
        (int128 rawValue, uint256 timestamp, ) = switchboard.getLatestValue(feedId);
        return (int256(rawValue), timestamp);
    }
}
