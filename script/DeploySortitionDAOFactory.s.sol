// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {SortitionDAOFactory} from "../src/factory/SortitionDAOFactory.sol";

/// @title DeploySortitionDAOFactory
/// @notice Deploys the SortitionDAOFactory once. Every DAO after that is created by
///         calling `createDAO` on the deployed factory rather than
///         redeploying the factory itself.
///
/// Usage:
///   forge script script/DeploySortitionDAOFactory.s.sol:DeploySortitionDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeploySortitionDAOFactory is Script {
    function run() external returns (SortitionDAOFactory factory) {
        vm.startBroadcast();

        factory = new SortitionDAOFactory();

        vm.stopBroadcast();

        console.log("SortitionDAOFactory deployed at:", address(factory));
    }
}
