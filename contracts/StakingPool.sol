// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPool is Ownable {
    using SafeERC20 for IERC20;

    // Struct to store the stake info for a user
    struct StakeInfo {
        uint256 amount;    // Amount of tokens staked
        uint256 timestamp; // Timestamp of when the tokens were staked
        IERC20 token;      // Token being staked
    }

    // Total staked amounts per token
    mapping(IERC20 => uint256) public totalStakedPerToken;

    // Mapping of user address to their stakes (they can stake multiple tokens)
    mapping(address => mapping(IERC20 => StakeInfo)) public userStakes;

    // Array to store all supported tokens (like USDz, EGPz)
    IERC20[] public supportedTokens;

    // Event declarations
    event TokensStaked(address indexed user, uint256 amount, address tokenAddress);
    event TokensUnstaked(address indexed user, uint256 amount, address tokenAddress);

    // Modifier to check if a token is supported
    modifier isSupportedToken(IERC20 token) {
        require(isTokenSupported(token), "Token is not supported");
        _;
    }

    // Check if a token is supported
    function isTokenSupported(IERC20 token) public view returns (bool) {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    // Admin function to add a supported token
    function addSupportedToken(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(!isTokenSupported(token), "Token already supported");
        supportedTokens.push(token);
    }

    // Stake "z" tokens
    function stakeTokens(uint256 amount, address tokenAddress) external isSupportedToken(IERC20(tokenAddress)) {
        require(amount > 0, "Amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);

        // Transfer tokens from the user to the contract
        token.safeTransferFrom(msg.sender, address(this), amount);

        // Update the user's stake
        userStakes[msg.sender][token] = StakeInfo({
            amount: userStakes[msg.sender][token].amount + amount,
            timestamp: block.timestamp,
            token: token
        });

        // Update total staked for that token
        totalStakedPerToken[token] += amount;

        emit TokensStaked(msg.sender, amount, tokenAddress);
    }

    // View function to check total staked for a specific token
    function getTotalStaked(address tokenAddress) external view returns (uint256) {
        return totalStakedPerToken[IERC20(tokenAddress)];
    }

    // View function to check the user's stake
    function getUserStake(address user, address tokenAddress) external view returns (uint256) {
        return userStakes[user][IERC20(tokenAddress)].amount;
    }

}