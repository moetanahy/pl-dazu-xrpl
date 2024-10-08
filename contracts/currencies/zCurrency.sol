// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract zCurrency is ERC20 {

    // Hardcoded minter address
    address public constant MINTER = 0x28E1CbD9d3a90Dc11492a93ceb87F5bE3DD4FE6a;

    // Constructor that initializes the name and symbol
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // No need to initialize the minter, as it's hardcoded
    }

    // Function to mint tokens, only callable by the hardcoded MINTER
    function mint(address to, uint256 amount) external {
        require(msg.sender == MINTER, "zCurrency: Only the designated minter can mint tokens");
        _mint(to, amount);
    }

    // Optional: Function to return the minter address (could be removed since MINTER is public)
    function getMinter() external pure returns (address) {
        return MINTER;
    }
}
