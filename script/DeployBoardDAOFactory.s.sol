// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BoardDAOFactory} from "../src/factory/BoardDAOFactory.sol";

/// @title DeployBoardDAOFactory
/// @notice Deploys the BoardDAOFactory once. Every DAO after that is created by
///         calling `createDAO` on the deployed factory rather than
///         redeploying the factory itself.
///
/// Usage:
///   forge script script/DeployBoardDAOFactory.s.sol:DeployBoardDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeployBoardDAOFactory is Script {
    function run() external returns (BoardDAOFactory factory) {
        vm.startBroadcast();

        factory = new BoardDAOFactory();

        vm.stopBroadcast();

        console.log("BoardDAOFactory deployed at:", address(factory));
    }
}
