// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IExchangeRateOracle.sol"; // Import the interface

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiCurrencyStakingProtocol is Ownable {
    using SafeERC20 for IERC20;

    // Enum for fee tiers
    enum FeeTier { Tier1, Tier2, Tier3 }

    struct Currency {
        string isoCode;                   // ISO currency code (e.g., "USD", "EUR")
        string tokenSymbol;               // Token symbol (e.g., "USDz")
        uint256 totalStaked;              // Total staked in the protocol for this currency
        uint256 transactionFee;           // Transaction fee in basis points (e.g., 100 = 1%)
        uint256 rewardsPool;              // Total rewards pool for the currency
        FeeTier feeTier;                  // The liquidity provider fee tier for this currency
    }

    mapping(IERC20 => Currency) public currencies;
    mapping(address => mapping(IERC20 => uint256)) public userStakes;
    mapping(IERC20 => bool) public supportedTokens;
    mapping(string => IERC20) public isoCodeToToken;
    mapping(address => string) public userCountries;

    IExchangeRateOracle public exchangeRateOracle;

    // Events
    event CurrencyAdded(IERC20 token, string isoCode, string tokenSymbol, FeeTier feeTier);
    event UserCountrySet(address indexed user, string countryCode);
    event Stake(address indexed user, IERC20 token, uint256 amount);
    event Unstake(address indexed user, IERC20 token, uint256 amount, uint256 rewards);
    event Transfer(
        address indexed from,
        address indexed to,
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amountSent,
        uint256 amountReceived,
        uint256 transactionFee,
        uint256 liquidityProviderFee
    );
    event TransactionFeeCollected(IERC20 token, uint256 amount);
    event RewardsClaimed(address indexed user, IERC20 token, uint256 rewards);

    constructor(address _exchangeRateOracle) Ownable(msg.sender) {
        exchangeRateOracle = IExchangeRateOracle(_exchangeRateOracle);
    }

    // Function to check if a token is supported
    function isTokenSupported(IERC20 token) public view returns (bool) {
        return supportedTokens[token];
    }

    // Modifier to check if a token is supported
    modifier isSupportedToken(IERC20 token) {
        require(isTokenSupported(token), "Token is not supported");
        _;
    }

    // Add a new currency with its fee tier
    function addCurrency(IERC20 token, string memory _isoCode, uint256 _transactionFee, FeeTier _feeTier) external onlyOwner {
        require(!supportedTokens[token], "Token already supported");
        require(bytes(_isoCode).length == 3, "ISO code must be 3 characters");
        require(isoCodeToToken[_isoCode] == IERC20(address(0)), "ISO code already used");

        string memory tokenSymbol = IERC20Metadata(address(token)).symbol();
        require(bytes(tokenSymbol).length > 0, "Token symbol cannot be empty");

        supportedTokens[token] = true;
        currencies[token] = Currency({
            isoCode: _isoCode,
            tokenSymbol: tokenSymbol,
            totalStaked: 0,
            transactionFee: _transactionFee,
            rewardsPool: 0,
            feeTier: _feeTier
        });

        isoCodeToToken[_isoCode] = token;

        emit CurrencyAdded(token, _isoCode, tokenSymbol, _feeTier);
    }

    // Function to get exchange rate between two currencies
    function getExchangeRate(string memory fromIsoCode, string memory toIsoCode) public view returns (uint256) {
        return exchangeRateOracle.getExchangeRate(fromIsoCode, toIsoCode);
    }

    // Transfer function handling both same-currency and cross-currency transfers
    function transfer(address recipient, uint256 _amount) external {
        require(recipient != address(0), "Recipient cannot be zero address");
        require(_amount > 0, "Transfer amount must be greater than zero");

        // Get sender's and recipient's country codes
        string memory senderCountry = userCountries[msg.sender];
        string memory recipientCountry = userCountries[recipient];
        require(bytes(senderCountry).length > 0, "Sender country not set");
        require(bytes(recipientCountry).length > 0, "Recipient country not set");

        // Get tokens corresponding to sender's and recipient's countries
        IERC20 fromToken = isoCodeToToken[senderCountry];
        IERC20 toToken = isoCodeToToken[recipientCountry];

        require(isTokenSupported(fromToken), "Sender's currency not supported");
        require(isTokenSupported(toToken), "Recipient's currency not supported");

        uint256 transactionFeeAmount = (_amount * currencies[fromToken].transactionFee) / 100; // TODO not sure this is correct
        uint256 amountAfterFee = _amount - transactionFeeAmount;
        require(amountAfterFee > 0, "Amount after fee must be greater than zero");

        uint256 liquidityProviderFeeAmount = 0;
        uint256 amountReceived = amountAfterFee;

        if (fromToken == toToken) {
            // Same-currency transfer
            fromToken.safeTransferFrom(msg.sender, recipient, amountAfterFee);
            currencies[fromToken].rewardsPool += transactionFeeAmount;

            emit TransactionFeeCollected(fromToken, transactionFeeAmount);
        } else {
            // Cross-currency transfer
            uint256 exchangeRate = getExchangeRate(senderCountry, recipientCountry);

            // Adjust for decimals (assuming both tokens have 2 decimals for simplicity)
            amountReceived = (amountAfterFee * exchangeRate) / (10 ** 2);

            liquidityProviderFeeAmount = calculateLiquidityProviderFee(amountReceived, toToken);
            amountReceived -= liquidityProviderFeeAmount;

            require(amountReceived > 0, "Amount after liquidity fee must be greater than zero");

            // Transfer the original amount from the sender
            fromToken.safeTransferFrom(msg.sender, address(this), _amount);

            // Add fees to the appropriate rewards pool
            currencies[fromToken].rewardsPool += transactionFeeAmount;
            currencies[toToken].rewardsPool += liquidityProviderFeeAmount;

            // Transfer the converted amount to the recipient
            toToken.safeTransfer(recipient, amountReceived);

            emit TransactionFeeCollected(fromToken, transactionFeeAmount);
        }

        emit Transfer(
            msg.sender,
            recipient,
            fromToken,
            toToken,
            _amount,
            amountReceived,
            transactionFeeAmount,
            liquidityProviderFeeAmount
        );
    }

    // Calculate liquidity provider fee based on the currency's tier using a helper function
    function calculateLiquidityProviderFee(uint256 amount, IERC20 toToken) internal view returns (uint256) {
        uint256 feeRate = getLiquidityProviderFeeRate(toToken);
        return (amount * feeRate) / 100;
    }

    // Public function to calculate liquidity provider fee using currency ISO codes
    function calculateLiquidityProviderFeePublic(uint256 amount, string memory toCurrencyISO) public view returns (uint256) {
        IERC20 toToken = getTokenFromISO(toCurrencyISO);
        return calculateLiquidityProviderFee(amount, toToken);
    }

    // Helper function to get token from ISO code
    function getTokenFromISO(string memory currencyISO) internal view returns (IERC20) {
        IERC20 token = isoCodeToToken[currencyISO];
        require(address(token) != address(0), "Currency not supported");
        return token;
    }

    // Get liquidity provider fee rate based on the currency's fee tier
    function getLiquidityProviderFeeRate(IERC20 toToken) internal view returns (uint256) {
        FeeTier tier = currencies[toToken].feeTier;

        if (tier == FeeTier.Tier1) {
            return 25; // 0.25%
        } else if (tier == FeeTier.Tier2) {
            return 50; // 0.5%
        } else {
            return 100; // 1%
        }
    }

    // Claim rewards without unstaking
    function claimRewards(IERC20 token) external isSupportedToken(token) {
        uint256 rewards = calculateRewards(msg.sender, token);
        require(rewards > 0, "No rewards to claim");

        currencies[token].rewardsPool -= rewards;
        token.safeTransfer(msg.sender, rewards);

        emit RewardsClaimed(msg.sender, token, rewards);
    }

    // Calculate rewards for a user (proportional to their stake)
    function calculateRewards(address _user, IERC20 token) public view isSupportedToken(token) returns (uint256) {
        uint256 userStake = userStakes[_user][token];
        uint256 totalStaked = currencies[token].totalStaked;

        if (totalStaked == 0) return 0;

        uint256 totalRewardsPool = currencies[token].rewardsPool;

        return (userStake * totalRewardsPool) / totalStaked;
    }
}
