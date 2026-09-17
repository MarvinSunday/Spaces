// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {SowellianDAOFactory} from "../src/factory/SowellianDAOFactory.sol";

/// @title DeploySowellianDAOFactory
/// @notice Deploys the SowellianDAOFactory once. Every DAO after that is created by
///         calling `createDAO` on the deployed factory rather than
///         redeploying the factory itself.
///
/// Usage:
///   forge script script/DeploySowellianDAOFactory.s.sol:DeploySowellianDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeploySowellianDAOFactory is Script {
    function run() external returns (SowellianDAOFactory factory) {
        vm.startBroadcast();

        factory = new SowellianDAOFactory();

        vm.stopBroadcast();

        console.log("SowellianDAOFactory deployed at:", address(factory));
    }
}
