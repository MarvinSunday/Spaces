// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./../interfaces/ITreasury.sol";

contract Treasury is ITreasury {
    address public override governance;

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address governance_) {
        if (governance_ == address(0)) revert ZeroAddress();
        governance = governance_;
    }

    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    function ethBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    function tokenBalance(address token) external view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function transferETH(address payable recipient,uint256 amount)
        external
        override
        onlyGovernance
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit ETHTransferred(recipient, amount);
    }

    function transferERC20(address token,address recipient,uint256 amount)
        external
        override
        onlyGovernance
    {
        if (recipient == address(0) || token == address(0)) revert ZeroAddress();
        bool ok = IERC20(token).transfer(recipient, amount);
        if (!ok) revert TransferFailed();

        emit ERC20Transferred(token, recipient, amount);
    }

    function execute(address target,uint256 value,bytes calldata data)
        external
        override
        onlyGovernance
        returns (bytes memory)
    {
        if (target == address(0)) revert ZeroAddress();
        (bool ok, bytes memory result)=target.call{value:value}(data);
        if(!ok) revert TransferFailed();
        return result;
    }

    function transferGovernance(address newGovernance)
        external
        override
        onlyGovernance
    {
        if(newGovernance==address(0)) revert ZeroAddress();
        address old=governance;
        governance=newGovernance;
        emit OwnershipTransferred(old,newGovernance);
    }
}
