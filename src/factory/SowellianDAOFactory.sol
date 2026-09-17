// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/sowellian/SowellianGovernance.sol";
import "../treasury/Treasury.sol";
import "../token/GovernanceToken.sol";
import "../token/StakedGovernanceToken.sol";
import "../governance/Types.sol";
import "./DAOFactoryLib.sol";

/// @title SowellianDAOFactory
/// @notice Deploys and wires together a governance token, staking
///         wrapper, treasury, and SowellianGovernance contract for a new
///         DAO - the same deployment shape as the original DAOFactory.
///         Which oracle a proposal resolves against is chosen per-
///         proposal (SowellianGovernance's own propose() call), not at
///         factory time, so nothing oracle-specific is wired here.
contract SowellianDAOFactory {
    uint256 public daoCount;
    mapping(uint256 => DAOInfo) public daos;
    mapping(address => address[]) public creatorDAOs;

    event DAOCreated(uint256 indexed daoId, address indexed creator, address governance, address treasury, address token);

    function createDAO(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        SowellianGovernance.SowellianConfig calldata config
    ) external returns (address governance) {
        (GovernanceToken token, StakedGovernanceToken stakedToken, Treasury treasury) =
            DAOFactoryLib.deployCore(name, symbol, initialSupply, maxSupply, msg.sender);

        SowellianGovernance gov = new SowellianGovernance(name, msg.sender, address(stakedToken), address(treasury), config);
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
