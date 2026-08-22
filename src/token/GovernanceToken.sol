// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    uint256 public immutable maxSupply;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        uint256 maxSupply_,
        address initialSupplyRecipient_,
        address initialOwner_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        Ownable(initialOwner_)
    {
        require(initialSupplyRecipient_ != address(0), "Zero recipient");
        require(initialOwner_ != address(0), "Zero owner");
        require(initialSupply_ <= maxSupply_, "Invalid supply");
        maxSupply = maxSupply_;
        _mint(initialSupplyRecipient_, initialSupply_);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Max supply exceeded");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);  
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns(uint256)
    {
        return super.nonces(owner);
    }
}
