// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface definition
interface IExchangeRateOracle {
    function getExchangeRate(string memory fromIsoCode, string memory toIsoCode) external view returns (uint256);
}

// Concrete contract that implements the interface
contract ExchangeRateOracle is IExchangeRateOracle {
    // Mapping to store exchange rates between currencies (fromIsoCode => toIsoCode => exchange rate)
    mapping(string => mapping(string => uint256)) public exchangeRates;

    // Function to set an exchange rate between two ISO currencies (e.g., USD => EUR)
    function setExchangeRate(string memory fromIsoCode, string memory toIsoCode, uint256 rate) public {
        exchangeRates[fromIsoCode][toIsoCode] = rate;
    }

    // Function to get the exchange rate, returning the scaled value
    function getExchangeRate(string memory fromIsoCode, string memory toIsoCode) public view override returns (uint256) {
        if (keccak256(abi.encodePacked(fromIsoCode)) == keccak256(abi.encodePacked(toIsoCode))) {
            return 1 * 1e6; // Return scaled 1 for same currency
        }
    
        return exchangeRates[fromIsoCode][toIsoCode];
    }
}
