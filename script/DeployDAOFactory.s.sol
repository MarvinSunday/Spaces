// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DAOFactory} from "../src/factory/DAOFactory.sol";

/// @title DeployDAOFactory
/// @notice Deploys the DAOFactory once. Every DAO after that is created by
///         calling `createDAO` on the deployed factory (see CreateDAO.s.sol)
///         rather than redeploying the factory itself.
///
/// Usage:
///   forge script script/DeployDAOFactory.s.sol:DeployDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeployDAOFactory is Script {
    function run() external returns (DAOFactory factory) {
        vm.startBroadcast();

        factory = new DAOFactory();

        vm.stopBroadcast();

        console.log("DAOFactory deployed at:", address(factory));
    }
}
