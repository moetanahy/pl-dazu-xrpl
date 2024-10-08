// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; // For token metadata
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";           // For safe token transfers
import "@openzeppelin/contracts/access/Ownable.sol";                         // For access control
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; // For oracle integration

contract MultiCurrencyStakingProtocol is Ownable {
    using SafeERC20 for IERC20;

    struct Currency {
        string isoCode;                   // ISO currency code (e.g., "USD", "EUR")
        string tokenSymbol;               // Token symbol (e.g., "USDz")
        uint256 totalStaked;              // Total staked in the protocol for this currency
        uint256 transactionFee;           // Transaction fee in basis points (e.g., 100 = 1%)
        uint256 rewardsPool;              // Total rewards pool for the currency
        AggregatorV3Interface priceFeed;  // Chainlink Price Feed for the currency
    }

    mapping(IERC20 => Currency) public currencies;
    mapping(address => mapping(IERC20 => uint256)) public userStakes;
    mapping(IERC20 => bool) public supportedTokens;
    mapping(string => IERC20) public isoCodeToToken;
    mapping(address => string) public userCountries;

    event CurrencyAdded(IERC20 token, string isoCode, string tokenSymbol);
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

    constructor() {}

    // Function to check if a token is supported
    function isTokenSupported(IERC20 token) public view returns (bool) {
        return supportedTokens[token];
    }

    // Modifier to check if a token is supported
    modifier isSupportedToken(IERC20 token) {
        require(isTokenSupported(token), "Token is not supported");
        _;
    }

    // Add a new currency to the protocol
    function addCurrency(
        IERC20 token,
        string memory _isoCode,
        uint256 _transactionFee,
        address _priceFeed
    ) external onlyOwner {
        require(!supportedTokens[token], "Token already supported");
        require(bytes(_isoCode).length == 3, "ISO code must be 3 characters");
        require(isoCodeToToken[_isoCode] == IERC20(address(0)), "ISO code already used");
        require(_priceFeed != address(0), "Invalid price feed address");

        string memory tokenSymbol = IERC20Metadata(address(token)).symbol();
        require(bytes(tokenSymbol).length > 0, "Token symbol cannot be empty");

        supportedTokens[token] = true;
        currencies[token] = Currency({
            isoCode: _isoCode,
            tokenSymbol: tokenSymbol,
            totalStaked: 0,
            transactionFee: _transactionFee,
            rewardsPool: 0,
            priceFeed: AggregatorV3Interface(_priceFeed)
        });

        isoCodeToToken[_isoCode] = token;

        emit CurrencyAdded(token, _isoCode, tokenSymbol);
    }

    // Function to set the user's country code (only callable by owner or authorized KYC officer)
    function setUserCountry(address user, string memory countryCode) external onlyOwner {
        require(bytes(countryCode).length == 2, "Country code must be 2 characters");
        userCountries[user] = countryCode;

        emit UserCountrySet(user, countryCode);
    }

    // Stake tokens into the protocol (stakers can stake any currency)
    function stake(IERC20 token, uint256 _amount) external isSupportedToken(token) {
        require(_amount > 0, "Stake amount must be greater than zero");

        // Transfer tokens from the user to the contract
        token.safeTransferFrom(msg.sender, address(this), _amount);

        userStakes[msg.sender][token] += _amount;
        currencies[token].totalStaked += _amount;

        emit Stake(msg.sender, token, _amount);
    }

    // Unstake tokens and claim rewards from the protocol
    function unstake(IERC20 token, uint256 _amount) external isSupportedToken(token) {
        require(userStakes[msg.sender][token] >= _amount, "Insufficient staked balance");

        uint256 rewards = calculateRewards(msg.sender, token);

        userStakes[msg.sender][token] -= _amount;
        currencies[token].totalStaked -= _amount;
        currencies[token].rewardsPool -= rewards;

        // Transfer tokens back to the user
        token.safeTransfer(msg.sender, _amount + rewards);

        emit Unstake(msg.sender, token, _amount, rewards);
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

        uint256 transactionFeeAmount = (_amount * currencies[fromToken].transactionFee) / 10000;
        uint256 amountAfterFee = _amount - transactionFeeAmount;
        require(amountAfterFee > 0, "Amount after fee must be greater than zero");

        uint256 liquidityProviderFeeAmount = 0;
        uint256 amountReceived = amountAfterFee;

        if (fromToken == toToken) {
            // Same-currency transfer
            // Transfer amount after fee from sender to recipient
            fromToken.safeTransferFrom(msg.sender, recipient, amountAfterFee);

            // Add transaction fee to rewards pool
            currencies[fromToken].rewardsPool += transactionFeeAmount;

            emit TransactionFeeCollected(fromToken, transactionFeeAmount);
        } else {
            // Cross-currency transfer
            // Fetch exchange rates
            uint256 fromTokenRate = getLatestPrice(currencies[fromToken].priceFeed);
            uint256 toTokenRate = getLatestPrice(currencies[toToken].priceFeed);

            // Adjust for decimals
            uint8 fromTokenDecimals = IERC20Metadata(address(fromToken)).decimals();
            uint8 toTokenDecimals = IERC20Metadata(address(toToken)).decimals();

            // Calculate amount in recipient's currency
            amountReceived = (amountAfterFee * fromTokenRate * (10 ** toTokenDecimals)) / (toTokenRate * (10 ** fromTokenDecimals));

            // Liquidity provider fee calculation based on liquidity available
            liquidityProviderFeeAmount = calculateLiquidityProviderFee(amountReceived, toToken);
            amountReceived -= liquidityProviderFeeAmount;

            require(amountReceived > 0, "Amount after liquidity fee must be greater than zero");

            // Transfer amount from sender to protocol
            fromToken.safeTransferFrom(msg.sender, address(this), _amount);

            // Add transaction fee to sender's rewards pool
            currencies[fromToken].rewardsPool += transactionFeeAmount;

            // Add liquidity provider fee to recipient's rewards pool
            currencies[toToken].rewardsPool += liquidityProviderFeeAmount;

            // Transfer converted amount to recipient
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

    // Function to get transfer details without executing the transfer
    function getTransferDetails(address sender, string memory recipientIsoCode, uint256 _amount)
        external
        view
        returns (
            bool success,
            string memory errorMessage,
            uint256 transactionFeeAmount,
            uint256 exchangeRate,
            uint256 liquidityProviderFeeAmount,
            uint256 amountReceived
        )
    {
        if (_amount == 0) {
            return (false, "Amount must be greater than zero", 0, 0, 0, 0);
        }

        // Get sender's country code
        string memory senderCountry = userCountries[sender];
        if (bytes(senderCountry).length == 0) {
            return (false, "Sender country not set", 0, 0, 0, 0);
        }

        // Get tokens corresponding to sender's and recipient's countries
        IERC20 fromToken = isoCodeToToken[senderCountry];
        IERC20 toToken = isoCodeToToken[recipientIsoCode];

        if (!isTokenSupported(fromToken)) {
            return (false, "Sender's currency not supported", 0, 0, 0, 0);
        }
        if (!isTokenSupported(toToken)) {
            return (false, "Recipient's currency not supported", 0, 0, 0, 0);
        }

        transactionFeeAmount = (_amount * currencies[fromToken].transactionFee) / 10000;
        uint256 amountAfterFee = _amount - transactionFeeAmount;
        if (amountAfterFee == 0) {
            return (false, "Amount after transaction fee is zero", 0, 0, 0, 0);
        }

        liquidityProviderFeeAmount = 0;
        amountReceived = amountAfterFee;
        exchangeRate = 0; // Initialize exchange rate

        if (fromToken == toToken) {
            // Same-currency transfer
            // No liquidity provider fee
            exchangeRate = 1 * (10 ** 18); // 1:1 exchange rate represented with 18 decimals
        } else {
            // Cross-currency transfer
            // Fetch exchange rates
            uint256 fromTokenRate = getLatestPrice(currencies[fromToken].priceFeed);
            uint256 toTokenRate = getLatestPrice(currencies[toToken].priceFeed);

            // Adjust for decimals
            uint8 fromTokenDecimals = IERC20Metadata(address(fromToken)).decimals();
            uint8 toTokenDecimals = IERC20Metadata(address(toToken)).decimals();

            // Calculate exchange rate (scaled to 18 decimals)
            exchangeRate = (fromTokenRate * (10 ** (18 + toTokenDecimals - fromTokenDecimals))) / toTokenRate;

            // Calculate amount in recipient's currency
            amountReceived = (amountAfterFee * exchangeRate) / (10 ** 18);

            // Liquidity provider fee calculation
            liquidityProviderFeeAmount = calculateLiquidityProviderFee(amountReceived, toToken);
            amountReceived -= liquidityProviderFeeAmount;

            if (amountReceived == 0) {
                return (
                    false,
                    "Amount after liquidity provider fee is zero",
                    transactionFeeAmount,
                    exchangeRate,
                    liquidityProviderFeeAmount,
                    amountReceived
                );
            }
        }

        return (
            true,
            "",
            transactionFeeAmount,
            exchangeRate,
            liquidityProviderFeeAmount,
            amountReceived
        );
    }

    // Helper function to calculate liquidity provider fee
    function calculateLiquidityProviderFee(uint256 amount, IERC20 toToken) internal view returns (uint256) {
        uint256 liquidityProviderFeeRate = getLiquidityProviderFeeRate(toToken);
        return (amount * liquidityProviderFeeRate) / 10000;
    }

    // Helper function to get liquidity provider fee rate
    function getLiquidityProviderFeeRate(IERC20 toToken) internal view returns (uint256) {
        // For simplicity, returning a fixed rate
        return 50; // 0.5%
    }

    // Function to get the latest price from Chainlink oracle
    function getLatestPrice(AggregatorV3Interface priceFeed) public view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt <= 3600, "Stale price data"); // 1 hour
        return uint256(price);
    }

    // Claim accumulated rewards without unstaking
    function claimRewards(IERC20 token) external isSupportedToken(token) {
        uint256 rewards = calculateRewards(msg.sender, token);
        require(rewards > 0, "No rewards to claim");

        currencies[token].rewardsPool -= rewards;
        token.safeTransfer(msg.sender, rewards);

        emit RewardsClaimed(msg.sender, token, rewards);
    }

    // Calculate rewards for a user
    function calculateRewards(address _user, IERC20 token) public view isSupportedToken(token) returns (uint256) {
        uint256 userStake = userStakes[_user][token];
        uint256 totalStaked = currencies[token].totalStaked;

        if (totalStaked == 0) return 0;

        uint256 totalRewardsPool = currencies[token].rewardsPool;

        return (userStake * totalRewardsPool) / totalStaked;
    }
}
