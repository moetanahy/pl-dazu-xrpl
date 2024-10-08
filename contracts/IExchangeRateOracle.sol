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

    // Implementation of the interface function to fetch the exchange rate
    function getExchangeRate(string memory fromIsoCode, string memory toIsoCode) public view override returns (uint256) {
        return exchangeRates[fromIsoCode][toIsoCode];
    }
}
