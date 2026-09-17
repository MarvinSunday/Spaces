// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DecisionMarketsDAOFactory} from "../src/factory/DecisionMarketsDAOFactory.sol";

/// @title DeployDecisionMarketsDAOFactory
/// @notice Deploys the DecisionMarketsDAOFactory once. Unlike every other
///         factory in this system, its constructor also deploys the
///         shared, stateless clone implementations (ConditionalToken,
///         ConditionalVault, DecisionMarketPair) that every DAO it later
///         creates will reuse - and takes the chain's canonical WMON
///         address, since that is meant to be one shared deployment, not
///         something each DAO gets its own copy of.
///
/// Required env vars:
///   WMON_ADDRESS - address of the chain's canonical Wrapped MON contract
///
/// Usage:
///   export WMON_ADDRESS=0x...
///   forge script script/DeployDecisionMarketsDAOFactory.s.sol:DeployDecisionMarketsDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeployDecisionMarketsDAOFactory is Script {
    function run() external returns (DecisionMarketsDAOFactory factory) {
        address wmon = vm.envAddress("WMON_ADDRESS");

        vm.startBroadcast();

        factory = new DecisionMarketsDAOFactory(wmon);

        vm.stopBroadcast();

        console.log("DecisionMarketsDAOFactory deployed at:", address(factory));
        console.log("  conditionalTokenImplementation:", factory.conditionalTokenImplementation());
        console.log("  conditionalVaultImplementation:", factory.conditionalVaultImplementation());
        console.log("  decisionMarketPairImplementation:", factory.decisionMarketPairImplementation());
    }
}
