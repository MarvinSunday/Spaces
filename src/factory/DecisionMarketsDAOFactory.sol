// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/futarchy/DecisionMarketsGovernance.sol";
import "../governance/futarchy/ConditionalToken.sol";
import "../governance/futarchy/ConditionalVault.sol";
import "../governance/futarchy/DecisionMarketPair.sol";
import "../treasury/Treasury.sol";
import "../token/GovernanceToken.sol";
import "../token/StakedGovernanceToken.sol";
import "../governance/Types.sol";
import "./DAOFactoryLib.sol";

/// @title DecisionMarketsDAOFactory
/// @notice Deploys and wires together a governance token, staking
///         wrapper, treasury, and DecisionMarketsGovernance contract for
///         a new DAO. Unlike every other factory here, this one has its
///         own constructor: ConditionalToken, ConditionalVault, and
///         DecisionMarketPair are stateless clone implementations - safe
///         and sensible to deploy exactly once and share across every
///         DAO this factory ever creates, rather than redeploying three
///         fresh implementations (wastefully) for each one. WMON is
///         supplied the same way, since it is meant to be one canonical
///         shared deployment across the whole chain, not something each
///         DAO gets its own copy of.
contract DecisionMarketsDAOFactory {
    address public immutable wmon;
    address public immutable conditionalTokenImplementation;
    address public immutable conditionalVaultImplementation;
    address public immutable decisionMarketPairImplementation;

    uint256 public daoCount;
    mapping(uint256 => DAOInfo) public daos;
    mapping(address => address[]) public creatorDAOs;

    event DAOCreated(uint256 indexed daoId, address indexed creator, address governance, address treasury, address token);

    error ZeroAddress();

    constructor(address wmon_) {
        if (wmon_ == address(0)) revert ZeroAddress();
        wmon = wmon_;

        conditionalTokenImplementation = address(new ConditionalToken());
        conditionalVaultImplementation = address(new ConditionalVault());
        decisionMarketPairImplementation = address(new DecisionMarketPair());
    }

    function createDAO(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        DecisionMarketsGovernance.DecisionMarketsConfig calldata config
    ) external returns (address governance) {
        (GovernanceToken token, StakedGovernanceToken stakedToken, Treasury treasury) =
            DAOFactoryLib.deployCore(name, symbol, initialSupply, maxSupply, msg.sender);

        DecisionMarketsGovernance gov = new DecisionMarketsGovernance(
            name,
            msg.sender,
            address(stakedToken),
            address(treasury),
            wmon,
            conditionalTokenImplementation,
            conditionalVaultImplementation,
            decisionMarketPairImplementation,
            config
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
