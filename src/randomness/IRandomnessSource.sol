// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IRandomnessSource
/// @author Marvin Sunday
/// @notice A provider-agnostic interface for verifiable on-chain randomness.
///         Any contract that needs randomness (SortitionGovernance, for
///         example) depends only on this interface - which underlying
///         provider (Chainlink VRF, Switchboard On-Demand, or a future
///         one) is an implementation detail, swappable per DAO the same
///         way every governance model in this system is swappable.
/// @dev The two providers built against this interface have genuinely
///      different request-ID conventions - Chainlink generates its own
///      numeric request ID when you call it; Switchboard takes a caller-
///      chosen bytes32 ID upfront. This interface standardizes on the
///      caller-chosen bytes32 convention (Switchboard's shape, since it's
///      the more restrictive one to satisfy) - the Chainlink adapter
///      internally maps our bytes32 ID to Chainlink's numeric one.
interface IRandomnessSource {
    /// @notice Requests randomness for a caller-chosen, unique request ID.
    ///         Reverts if this ID has already been used.
    function requestRandomness(bytes32 requestId) external payable;

    /// @notice Whether randomness for this request ID has been resolved.
    function isFulfilled(bytes32 requestId) external view returns (bool);

    /// @notice The resolved random value. Reverts if not yet fulfilled -
    ///         callers must check `isFulfilled` first.
    function getRandomness(bytes32 requestId) external view returns (uint256);
}
