// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DelegateDAOFactory} from "../src/factory/DelegateDAOFactory.sol";

/// @title DeployDelegateDAOFactory
/// @notice Deploys the DelegateDAOFactory once. Every delegate-governed DAO
///         after that is created by calling `createDAO` on the deployed
///         factory (see CreateDelegateDAO.s.sol) rather than redeploying
///         the factory itself.
///
/// Usage:
///   forge script script/DeployDelegateDAOFactory.s.sol:DeployDelegateDAOFactory \
///     --rpc-url <RPC_URL> \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract DeployDelegateDAOFactory is Script {
    function run() external returns (DelegateDAOFactory factory) {
        vm.startBroadcast();

        factory = new DelegateDAOFactory();

        vm.stopBroadcast();

        console.log("DelegateDAOFactory deployed at:", address(factory));
    }
}
