// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/Governance.sol";
import "../treasury/Treasury.sol";
import "../token/GovernanceToken.sol";
import "../token/StakedGovernanceToken.sol";
import "../governance/Types.sol";
import "./IDAOFactory.sol";

/// @title DAOFactory
/// @notice Deploys and wires together a governance token, staking wrapper,
///         treasury and governance contract for a new DAO.
/// @dev Deployment order matters here because of a circular dependency:
///      Treasury and StakedGovernanceToken must exist before Governance can
///      be constructed (Governance's constructor takes their addresses),
///      but Treasury and GovernanceToken each need to recognize Governance
///      as their controller once it exists. The factory itself is
///      temporarily installed as the controller of both (as the initial
///      Ownable owner of the token, and as the initial `governance` of the
///      Treasury), and hands control off to the real Governance contract
///      immediately after it is deployed, within the same transaction.
///
///      Voting power is not derived from raw token balance. Holders must
///      stake their GovernanceToken into the StakedGovernanceToken wrapper
///      to receive voting power - see StakedGovernanceToken for why.
///      Governance is pointed at the staking wrapper, not the raw token,
///      so every quorum/approval/proposal-threshold check in Governance.sol
///      is already scoped to staked (committed) supply with zero changes
///      needed there.
contract DAOFactory is IDAOFactory {
    uint256 public daoCount;
    mapping(uint256 => DAOInfo) public daos;
    mapping(address => address[]) public creatorDAOs;

    function createDAO(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        GovernanceConfig calldata config
    ) external returns (address governance) {
        // Initial supply goes to the DAO creator; the factory is only the
        // temporary Ownable owner so it can hand off minting rights to
        // Governance once Governance exists.
        GovernanceToken token = new GovernanceToken(
            name,
            symbol,
            initialSupply,
            maxSupply,
            msg.sender,
            address(this)
        );

        StakedGovernanceToken stakedToken = new StakedGovernanceToken(
            address(token),
            string.concat("Staked ", name),
            string.concat("s", symbol)
        );

        Treasury treasury = new Treasury(address(this));

        Governance gov = new Governance(
            name,
            msg.sender,
            address(stakedToken),
            address(treasury),
            config
        );
        governance = address(gov);

        treasury.transferGovernance(governance);
        token.transferOwnership(governance);

        daoCount++;
        daos[daoCount] = DAOInfo(
            name,
            msg.sender,
            address(stakedToken),
            address(token),
            governance,
            address(treasury),
            block.timestamp
        );
        creatorDAOs[msg.sender].push(governance);

        emit DAOCreated(daoCount, msg.sender, governance, address(treasury), address(stakedToken));
    }

    function getCreatorDAOs(address creator) external view returns (address[] memory) {
        return creatorDAOs[creator];
    }
}
