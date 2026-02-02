// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Treasury
 * @notice Central treasury for fee collection and distribution
 * @dev Manages marketplace fees, game rewards, and admin withdrawals
 */
contract Treasury is ParadiseAccessControl, ReentrancyGuard, Pausable {
    /// @notice Emitted when fees are collected
    event FeesCollected(address indexed source, uint256 amount, string sourceType);

    /// @notice Emitted when funds are withdrawn
    event FundsWithdrawn(address indexed to, uint256 amount, string reason);

    /// @notice Emitted when funds are distributed for rewards
    event RewardsDistributed(address indexed recipient, uint256 amount, string rewardType);

    /// @notice Total fees collected (for tracking)
    uint256 public totalFeesCollected;

    /**
     * @notice Constructor
     * @dev Initializes treasury with admin role
     */
    constructor() ParadiseAccessControl() {}

    /**
     * @notice Receive native tokens (MOANI)
     * @dev Allows contract to receive native tokens
     */
    receive() external payable {
        // Accept native token deposits
    }

    /**
     * @notice Collect fees from a source
     * @param sourceType The type of source (e.g., "AUCTION_HOUSE", "VENDOR_SHOP")
     * @dev Only callable by registered game contracts
     */
    function collectFees(string memory sourceType) external payable onlyRole(GAME_CONTRACT_ROLE) {
        if (msg.value == 0) {
            revert("No funds sent");
        }

        totalFeesCollected += msg.value;
        emit FeesCollected(msg.sender, msg.value, sourceType);
    }

    /**
     * @notice Distribute rewards to a recipient
     * @param recipient The address to receive rewards
     * @param amount The amount to distribute
     * @param rewardType The type of reward (e.g., "QUEST_REWARD", "DAILY_REWARD")
     * @dev Only callable by registered game contracts
     */
    function distributeRewards(
        address recipient,
        uint256 amount,
        string memory rewardType
    ) external nonReentrant onlyRole(GAME_CONTRACT_ROLE) whenNotPaused {
        if (recipient == address(0)) {
            revert("Invalid recipient");
        }
        if (amount == 0) {
            revert("Invalid amount");
        }
        if (address(this).balance < amount) {
            revert("Insufficient balance");
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        emit RewardsDistributed(recipient, amount, rewardType);
    }

    /**
     * @notice Withdraw funds (admin only)
     * @param to The address to withdraw to
     * @param amount The amount to withdraw
     * @param reason The reason for withdrawal
     * @dev Only callable by admin
     */
    function withdrawFunds(address to, uint256 amount, string memory reason)
        external
        nonReentrant
        onlyRole(ADMIN_ROLE)
    {
        if (to == address(0)) {
            revert("Invalid recipient");
        }
        if (amount == 0) {
            revert("Invalid amount");
        }
        if (address(this).balance < amount) {
            revert("Insufficient balance");
        }

        (bool success, ) = to.call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        emit FundsWithdrawn(to, amount, reason);
    }

    /**
     * @notice Get the current balance of the treasury
     * @return The balance in wei
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Pause the treasury (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the treasury
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
