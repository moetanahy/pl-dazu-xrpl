// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDz is ERC20 {
    constructor() ERC20("USDz", "USDz") {
        // Mint 1,000,000 USDz tokens to the contract deployer
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}