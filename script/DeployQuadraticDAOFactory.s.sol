// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {QuadraticDAOFactory} from "../src/factory/QuadraticDAOFactory.sol";

/// @title DeployQuadraticDAOFactory
/// @notice Deploys the QuadraticDAOFactory once. Every DAO after that is created by
///         calling `createDAO` on the deployed factory rather than
///         redeploying the factory itself.
///
/// Usage:
///   forge script script/DeployQuadraticDAOFactory.s.sol:DeployQuadraticDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeployQuadraticDAOFactory is Script {
    function run() external returns (QuadraticDAOFactory factory) {
        vm.startBroadcast();

        factory = new QuadraticDAOFactory();

        vm.stopBroadcast();

        console.log("QuadraticDAOFactory deployed at:", address(factory));
    }
}
