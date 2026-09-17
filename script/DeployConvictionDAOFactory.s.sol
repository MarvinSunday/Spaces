// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ConvictionDAOFactory} from "../src/factory/ConvictionDAOFactory.sol";

/// @title DeployConvictionDAOFactory
/// @notice Deploys the ConvictionDAOFactory once. Every DAO after that is created by
///         calling `createDAO` on the deployed factory rather than
///         redeploying the factory itself.
///
/// Usage:
///   forge script script/DeployConvictionDAOFactory.s.sol:DeployConvictionDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeployConvictionDAOFactory is Script {
    function run() external returns (ConvictionDAOFactory factory) {
        vm.startBroadcast();

        factory = new ConvictionDAOFactory();

        vm.stopBroadcast();

        console.log("ConvictionDAOFactory deployed at:", address(factory));
    }
}
