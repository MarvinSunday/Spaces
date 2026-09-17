// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/delegate/DelegateGovernance.sol";
import "../treasury/Treasury.sol";
import "../token/GovernanceToken.sol";
import "../token/StakedGovernanceToken.sol";
import "../governance/Types.sol";
import "./DAOFactoryLib.sol";

/// @title DelegateDAOFactory
/// @notice Deploys and wires together a governance token, staking wrapper,
///         treasury, and DelegateGovernance contract for a new DAO - the
///         same deployment shape as the original DAOFactory, with the
///         addition of the initial elected council DelegateGovernance
///         requires at construction.
contract DelegateDAOFactory {
    uint256 public daoCount;
    mapping(uint256 => DAOInfo) public daos;
    mapping(address => address[]) public creatorDAOs;

    event DAOCreated(uint256 indexed daoId, address indexed creator, address governance, address treasury, address token);

    function createDAO(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        DelegateGovernance.DelegateGovernanceConfig calldata config,
        address[] calldata initialCouncil
    ) external returns (address governance) {
        (GovernanceToken token, StakedGovernanceToken stakedToken, Treasury treasury) =
            DAOFactoryLib.deployCore(name, symbol, initialSupply, maxSupply, msg.sender);

        DelegateGovernance gov = new DelegateGovernance(
            name,
            msg.sender,
            address(stakedToken),
            address(treasury),
            config,
            initialCouncil
        );
        governance = address(gov);

        treasury.transferGovernance(governance);
        token.transferOwnership(governance);

        _recordDAO(name, address(stakedToken), address(token), governance, address(treasury));
    }

    function _recordDAO(
        string calldata name,
        address stakedToken,
        address token,
        address governance,
        address treasury
    ) private {
        daoCount++;
        daos[daoCount] = DAOInfo(name, msg.sender, stakedToken, token, governance, treasury, block.timestamp);
        creatorDAOs[msg.sender].push(governance);
        emit DAOCreated(daoCount, msg.sender, governance, treasury, stakedToken);
    }

    function getCreatorDAOs(address creator) external view returns (address[] memory) {
        return creatorDAOs[creator];
    }
}
