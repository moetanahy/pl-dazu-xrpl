// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDz is ERC20 {

    address public minter;

    constructor() ERC20("USDz", "USDz") {
        // Set the minter address to the specified wallet
        // This is the DAZU Treasury who is the only one that can mint this
        minter = 0x28E1CbD9d3a90Dc11492a93ceb87F5bE3DD4FE6a;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "USDz: Only the designated minter can mint tokens");
        _mint(to, amount);
    }
    
}