// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LiquidDAOFactory} from "../src/factory/LiquidDAOFactory.sol";

/// @title DeployLiquidDAOFactory
/// @notice Deploys the LiquidDAOFactory once. Every DAO after that is created by
///         calling `createDAO` on the deployed factory rather than
///         redeploying the factory itself.
///
/// Usage:
///   forge script script/DeployLiquidDAOFactory.s.sol:DeployLiquidDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeployLiquidDAOFactory is Script {
    function run() external returns (LiquidDAOFactory factory) {
        vm.startBroadcast();

        factory = new LiquidDAOFactory();

        vm.stopBroadcast();

        console.log("LiquidDAOFactory deployed at:", address(factory));
    }
}
