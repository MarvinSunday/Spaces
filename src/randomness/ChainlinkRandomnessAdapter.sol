// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { VRFV2PlusWrapperConsumerBase } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import { IRandomnessSource } from "./IRandomnessSource.sol";

/// @title ChainlinkRandomnessAdapter
/// @author Marvin Sunday
/// @notice Wraps Chainlink VRF v2.5's direct-funding ("pay-as-you-go")
///         wrapper behind the shared IRandomnessSource interface.
/// @dev Deliberately uses the wrapper/direct-funding flow instead of a
///      pre-funded subscription. Subscriptions make sense when a contract
///      calls VRF frequently or wants to share one funding pool across
///      many consumers - neither applies here. SortitionGovernance calls
///      this rarely (once per election term, not per-transaction), so
///      maintaining a subscription that sits idle between rounds - and
///      has to be separately created, funded, and monitored - is real
///      operational overhead for no benefit. Direct funding pays exactly
///      when a request happens, in native currency, no subscription setup
///      at all: no keyHash, no subscription ID, nothing to run dry
///      unexpectedly between rounds.
///
///      Still PUSH-based like the subscription flow - the wrapper calls
///      this contract back automatically once randomness is ready, no
///      keeper needed (unlike the Switchboard adapter).
///
///      Verified against the real, installed Chainlink contracts package
///      (chainlink/contracts, v1.4.0) - not written from documentation
///      snippets alone.
contract ChainlinkRandomnessAdapter is IRandomnessSource, VRFV2PlusWrapperConsumerBase {
    uint16 public immutable requestConfirmations;
    uint32 public immutable callbackGasLimit;
    uint32 public constant NUM_WORDS = 1;

    /// @dev Our bytes32 request ID -> Chainlink's own numeric request ID.
    mapping(bytes32 => uint256) public chainlinkRequestIdOf;
    /// @dev Reverse lookup, used inside the fulfillment callback.
    mapping(uint256 => bytes32) internal _requestIdOfChainlinkId;

    mapping(bytes32 => bool) public requested;
    mapping(bytes32 => uint256) internal _randomnessOf;
    mapping(bytes32 => bool) internal _fulfilled;

    error AlreadyRequested();
    error NotYetFulfilled();
    error InsufficientPayment();
    error RefundFailed();

    constructor(
        address vrfWrapper_,
        uint16 requestConfirmations_,
        uint32 callbackGasLimit_
    ) VRFV2PlusWrapperConsumerBase(vrfWrapper_) {
        requestConfirmations = requestConfirmations_;
        callbackGasLimit = callbackGasLimit_;
    }

    /// @notice The exact native-currency payment `requestRandomness` needs
    ///         right now - query this first so the caller sends enough.
    function requestPrice() public view returns (uint256) {
        return i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, NUM_WORDS);
    }

    /// @inheritdoc IRandomnessSource
    function requestRandomness(bytes32 requestId) external payable {
        if (requested[requestId]) revert AlreadyRequested();
        requested[requestId] = true;

        uint256 price = requestPrice();
        if (msg.value < price) revert InsufficientPayment();

        (uint256 chainlinkRequestId, ) = requestRandomnessPayInNative(
            callbackGasLimit,
            requestConfirmations,
            NUM_WORDS,
            ""
        );

        chainlinkRequestIdOf[requestId] = chainlinkRequestId;
        _requestIdOfChainlinkId[chainlinkRequestId] = requestId;

        if (msg.value > price) {
            (bool ok, ) = msg.sender.call{value: msg.value - price}("");
            if (!ok) revert RefundFailed();
        }
    }

    /// @dev Called automatically by the VRF wrapper once randomness is
    ///      ready - never called directly by any other address, enforced
    ///      by VRFV2PlusWrapperConsumerBase's rawFulfillRandomWords wrapper.
    function fulfillRandomWords(uint256 chainlinkRequestId, uint256[] memory randomWords) internal override {
        bytes32 requestId = _requestIdOfChainlinkId[chainlinkRequestId];
        _randomnessOf[requestId] = randomWords[0];
        _fulfilled[requestId] = true;
    }

    /// @inheritdoc IRandomnessSource
    function isFulfilled(bytes32 requestId) external view returns (bool) {
        return _fulfilled[requestId];
    }

    /// @inheritdoc IRandomnessSource
    function getRandomness(bytes32 requestId) external view returns (uint256) {
        if (!_fulfilled[requestId]) revert NotYetFulfilled();
        return _randomnessOf[requestId];
    }
}
