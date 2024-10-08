// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./zCurrency.sol"; // Import the base contract

contract EGPz is zCurrency {

    // Pass the name and symbol to the base contract
    constructor() zCurrency("EGPz", "EGPz") {
        // No additional logic needed for USDz
    }
}
