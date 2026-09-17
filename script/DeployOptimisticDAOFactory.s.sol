// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {OptimisticDAOFactory} from "../src/factory/OptimisticDAOFactory.sol";

/// @title DeployOptimisticDAOFactory
/// @notice Deploys the OptimisticDAOFactory once. Every DAO after that is created by
///         calling `createDAO` on the deployed factory rather than
///         redeploying the factory itself.
///
/// Usage:
///   forge script script/DeployOptimisticDAOFactory.s.sol:DeployOptimisticDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeployOptimisticDAOFactory is Script {
    function run() external returns (OptimisticDAOFactory factory) {
        vm.startBroadcast();

        factory = new OptimisticDAOFactory();

        vm.stopBroadcast();

        console.log("OptimisticDAOFactory deployed at:", address(factory));
    }
}
