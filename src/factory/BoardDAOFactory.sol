// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/board/BoardGovernance.sol";
import "../treasury/Treasury.sol";
import "../governance/Types.sol";

/// @title BoardDAOFactory
/// @notice Deploys and wires together a treasury and BoardGovernance
///         contract for a new DAO. BoardGovernance is the one model in
///         this system that needs no token at all - a fixed set of
///         signers governs directly - so this factory, unlike every
///         other one, never deploys GovernanceToken or
///         StakedGovernanceToken. DAOInfo's token fields are recorded as
///         address(0) accordingly.
contract BoardDAOFactory {
    uint256 public daoCount;
    mapping(uint256 => DAOInfo) public daos;
    mapping(address => address[]) public creatorDAOs;

    event DAOCreated(uint256 indexed daoId, address indexed creator, address governance, address treasury);

    function createDAO(
        string calldata name,
        BoardGovernance.BoardGovernanceConfig calldata config,
        address[] calldata initialSigners
    ) external returns (address governance) {
        Treasury treasury = new Treasury(address(this));

        BoardGovernance gov = new BoardGovernance(name, msg.sender, address(treasury), config, initialSigners);
        governance = address(gov);

        treasury.transferGovernance(governance);

        _recordDAO(name, governance, address(treasury));
    }

    function _recordDAO(string calldata name, address governance, address treasury) private {
        daoCount++;
        daos[daoCount] = DAOInfo(name, msg.sender, address(0), address(0), governance, treasury, block.timestamp);
        creatorDAOs[msg.sender].push(governance);
        emit DAOCreated(daoCount, msg.sender, governance, treasury);
    }

    function getCreatorDAOs(address creator) external view returns (address[] memory) {
        return creatorDAOs[creator];
    }
}
