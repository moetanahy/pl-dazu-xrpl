// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiCurrencyStakingProtocol is Ownable {
    using SafeERC20 for IERC20;  // Enable safe handling of ERC20 tokens

    struct Currency {
        uint256 totalStaked;    // Total staked in the protocol for this currency
        uint256 transactionFee; // Transaction fee in basis points (e.g., 100 = 1%)
        uint256 utilizationFee; // Utilization fee in basis points (if applicable)
        uint256 rewardsPool;    // Total rewards pool for the currency
    }

    mapping(IERC20 => Currency) public currencies;
    mapping(address => mapping(IERC20 => uint256)) public userStakes;
    mapping(IERC20 => bool) public supportedTokens; // Track supported tokens

    event Stake(address indexed user, IERC20 token, uint256 amount);
    event Unstake(address indexed user, IERC20 token, uint256 amount, uint256 rewards);
    event TransferWithFee(address indexed from, address indexed to, IERC20 token, uint256 amountSent, uint256 fee);
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
    function addCurrency(IERC20 token, uint256 _transactionFee) external onlyOwner {
        require(!supportedTokens[token], "Token already supported");
        supportedTokens[token] = true;
        currencies[token] = Currency({
            totalStaked: 0,
            transactionFee: _transactionFee,
            utilizationFee: 0,  // Set to zero if not used
            rewardsPool: 0
        });
    }

    // Stake tokens into the protocol
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

        // Deduct the rewards from the rewards pool
        currencies[token].rewardsPool -= rewards;

        // Transfer tokens back to the user
        token.safeTransfer(msg.sender, _amount + rewards);

        emit Unstake(msg.sender, token, _amount, rewards);
    }

    // Users can transfer tokens with a fee
    function transferWithFee(IERC20 token, address recipient, uint256 _amount) external isSupportedToken(token) {
        require(recipient != address(0), "Recipient cannot be zero address");
        require(_amount > 0, "Transfer amount must be greater than zero");

        // Calculate the transaction fee
        uint256 transactionFeeAmount = (_amount * currencies[token].transactionFee) / 10000;
        uint256 amountAfterFee = _amount - transactionFeeAmount;

        require(amountAfterFee > 0, "Amount after fee must be greater than zero");

        // Transfer the amount after fee to the recipient
        token.safeTransferFrom(msg.sender, recipient, amountAfterFee);

        // Transfer the fee to the protocol (rewards pool)
        token.safeTransferFrom(msg.sender, address(this), transactionFeeAmount);
        currencies[token].rewardsPool += transactionFeeAmount;

        emit TransferWithFee(msg.sender, recipient, token, amountAfterFee, transactionFeeAmount);
        emit TransactionFeeCollected(token, transactionFeeAmount);
    }

    // Claim accumulated rewards without unstaking
    function claimRewards(IERC20 token) external isSupportedToken(token) {
        uint256 rewards = calculateRewards(msg.sender, token);
        require(rewards > 0, "No rewards to claim");

        // Update the user's stake (rewards are not added to the stake in this case)
        currencies[token].rewardsPool -= rewards;

        // Transfer rewards to the user
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
