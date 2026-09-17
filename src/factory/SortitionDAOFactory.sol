// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/sortition/SortitionGovernance.sol";
import "../treasury/Treasury.sol";
import "../token/GovernanceToken.sol";
import "../token/StakedGovernanceToken.sol";
import "../governance/Types.sol";
import "./DAOFactoryLib.sol";

/// @title SortitionDAOFactory
/// @notice Deploys and wires together a governance token, staking
///         wrapper, treasury, and SortitionGovernance contract for a new
///         DAO. Unlike every other factory in this system, this one
///         cannot self-contain everything it needs: SortitionGovernance
///         requires a real, already-deployed randomness source (a
///         SwitchboardRandomnessAdapter, a ChainlinkRandomnessAdapter, or
///         any other IRandomnessSource implementation configured for
///         this chain), which the caller must supply. This factory has
///         no business deploying that itself - which provider to trust,
///         and its real network-specific configuration (queue IDs,
///         wrapper addresses), is a deliberate, per-deployment choice
///         that belongs to whoever is creating the DAO, not something
///         this factory should default or guess at.
contract SortitionDAOFactory {
    uint256 public daoCount;
    mapping(uint256 => DAOInfo) public daos;
    mapping(address => address[]) public creatorDAOs;

    event DAOCreated(uint256 indexed daoId, address indexed creator, address governance, address treasury, address token);

    function createDAO(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address randomnessSource,
        SortitionGovernance.SortitionGovernanceConfig calldata config,
        address[] calldata initialCouncil
    ) external returns (address governance) {
        (GovernanceToken token, StakedGovernanceToken stakedToken, Treasury treasury) =
            DAOFactoryLib.deployCore(name, symbol, initialSupply, maxSupply, msg.sender);

        SortitionGovernance gov = new SortitionGovernance(
            name,
            msg.sender,
            address(stakedToken),
            address(treasury),
            randomnessSource,
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
