// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { VRFConsumerBaseV2Plus } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import { VRFV2PlusClient } from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import { IRandomnessSource } from "./IRandomnessSource.sol";

/// @title ChainlinkRandomnessAdapter
/// @author Marvin Sunday
/// @notice Wraps Chainlink VRF v2.5 behind the shared IRandomnessSource
///         interface.
/// @dev Chainlink is a PUSH-based oracle, the opposite of Switchboard's
///      pull model - the VRF coordinator calls this contract back
///      automatically once the randomness is ready, no keeper needed.
///
///      The real complexity here: Chainlink generates its OWN numeric
///      request ID when `requestRandomWords` is called, but
///      IRandomnessSource standardizes on a caller-chosen bytes32 ID (to
///      match Switchboard's convention). This adapter bridges the two
///      with an internal id <-> id mapping, set up before the external
///      call and consulted in the fulfillment callback.
///
///      Requires a funded Chainlink VRF subscription that this contract's
///      address has been added to as a consumer - see Chainlink's VRF
///      subscription manager for the network you deploy to.
///
///      Verified against the real, installed Chainlink contracts package
///      (chainlink/contracts, v1.4.0) - not written from documentation
///      snippets alone.
contract ChainlinkRandomnessAdapter is IRandomnessSource, VRFConsumerBaseV2Plus {
    bytes32 public immutable keyHash;
    uint256 public immutable subscriptionId;
    uint16 public immutable requestConfirmations;
    uint32 public immutable callbackGasLimit;

    /// @dev Our bytes32 request ID -> Chainlink's own numeric request ID.
    mapping(bytes32 => uint256) public chainlinkRequestIdOf;
    /// @dev Reverse lookup, used inside the fulfillment callback.
    mapping(uint256 => bytes32) internal _requestIdOfChainlinkId;

    mapping(bytes32 => bool) public requested;
    mapping(bytes32 => uint256) internal _randomnessOf;
    mapping(bytes32 => bool) internal _fulfilled;

    error AlreadyRequested();
    error NotYetFulfilled();

    constructor(
        address vrfCoordinator_,
        bytes32 keyHash_,
        uint256 subscriptionId_,
        uint16 requestConfirmations_,
        uint32 callbackGasLimit_
    ) VRFConsumerBaseV2Plus(vrfCoordinator_) {
        keyHash = keyHash_;
        subscriptionId = subscriptionId_;
        requestConfirmations = requestConfirmations_;
        callbackGasLimit = callbackGasLimit_;
    }

    /// @inheritdoc IRandomnessSource
    function requestRandomness(bytes32 requestId) external payable {
        if (requested[requestId]) revert AlreadyRequested();
        requested[requestId] = true;

        uint256 chainlinkRequestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({ nativePayment: msg.value > 0 })
                )
            })
        );

        chainlinkRequestIdOf[requestId] = chainlinkRequestId;
        _requestIdOfChainlinkId[chainlinkRequestId] = requestId;
    }

    /// @dev Called automatically by the VRF coordinator once randomness is
    ///      ready - never called directly by any other address, enforced
    ///      by VRFConsumerBaseV2Plus's rawFulfillRandomWords wrapper.
    function fulfillRandomWords(uint256 chainlinkRequestId, uint256[] calldata randomWords) internal override {
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
