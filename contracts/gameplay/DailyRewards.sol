// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IParadiseItems.sol";
import "../core/AccessControl.sol";
import "../economy/Treasury.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DailyRewards
 * @notice Daily login reward system with 7-day cycles
 * @dev Tracks streaks and distributes escalating rewards
 */
contract DailyRewards is ParadiseAccessControl, Pausable {
    /// @notice The Paradise Items contract
    IParadiseItems public immutable itemsContract;

    /// @notice The Treasury contract for MOANI rewards
    Treasury public immutable treasury;

    /// @notice Reward structure for a day
    struct DayReward {
        uint256[] itemIds;
        uint256[] amounts;
        uint256 moaniAmount; // MOANI reward (18 decimals)
    }

    /// @notice Player reward state
    struct PlayerRewardState {
        uint256 lastClaimTimestamp;
        uint256 currentStreakDay; // 1-7, resets to 1 after 7
        uint256 lastStreakResetTimestamp;
    }

    /// @notice Daily rewards (day 1-7)
    mapping(uint256 => DayReward) private _dailyRewards;

    /// @notice Player reward states
    mapping(address => PlayerRewardState) private _playerStates;

    /// @notice Seconds in a day (86400)
    uint256 public constant SECONDS_PER_DAY = 86400;

    /// @notice Emitted when daily reward is claimed
    event DailyRewardClaimed(
        address indexed player,
        uint256 day,
        uint256[] itemIds,
        uint256[] amounts,
        uint256 moaniAmount
    );

    /// @notice Emitted when streak resets
    event StreakReset(address indexed player);

    /**
     * @notice Constructor
     * @param itemsContract_ The Paradise Items contract address
     * @param treasury_ The Treasury contract address
     */
    constructor(address itemsContract_, address treasury_) ParadiseAccessControl() {
        if (itemsContract_ == address(0) || treasury_ == address(0)) {
            revert("Invalid address");
        }
        itemsContract = IParadiseItems(itemsContract_);
        treasury = Treasury(payable(treasury_));
    }

    /**
     * @notice Set rewards for a specific day (1-7)
     * @param day The day number (1-7)
     * @param itemIds Array of reward item IDs
     * @param amounts Array of reward amounts
     * @param moaniAmount MOANI reward amount (18 decimals)
     * @dev Only callable by admin
     */
    function setDayReward(
        uint256 day,
        uint256[] memory itemIds,
        uint256[] memory amounts,
        uint256 moaniAmount
    ) external onlyRole(ADMIN_ROLE) {
        if (day < 1 || day > 7) {
            revert("Invalid day");
        }
        if (itemIds.length != amounts.length) {
            revert("Array length mismatch");
        }

        _dailyRewards[day] = DayReward({
            itemIds: itemIds,
            amounts: amounts,
            moaniAmount: moaniAmount
        });
    }

    /**
     * @notice Claim daily reward
     * @dev Can only claim once per 24-hour period
     */
    function claimDailyReward() external whenNotPaused {
        PlayerRewardState storage state = _playerStates[msg.sender];

        // Check if 24 hours have passed since last claim
        if (block.timestamp < state.lastClaimTimestamp + SECONDS_PER_DAY) {
            revert("Reward not available yet");
        }

        // Check if streak needs reset (more than 48 hours = missed a day)
        if (block.timestamp >= state.lastClaimTimestamp + (SECONDS_PER_DAY * 2)) {
            state.currentStreakDay = 1;
            state.lastStreakResetTimestamp = block.timestamp;
            emit StreakReset(msg.sender);
        } else {
            // Increment streak day
            state.currentStreakDay++;
            if (state.currentStreakDay > 7) {
                state.currentStreakDay = 1;
                state.lastStreakResetTimestamp = block.timestamp;
            }
        }

        // Update last claim timestamp
        state.lastClaimTimestamp = block.timestamp;

        // Get rewards for current day
        DayReward memory reward = _dailyRewards[state.currentStreakDay];

        // Mint item rewards
        if (reward.itemIds.length > 0) {
            itemsContract.mintBatch(msg.sender, reward.itemIds, reward.amounts, "");
        }

        // Distribute MOANI reward
        if (reward.moaniAmount > 0) {
            treasury.distributeRewards(msg.sender, reward.moaniAmount, "DAILY_REWARD");
        }

        emit DailyRewardClaimed(
            msg.sender,
            state.currentStreakDay,
            reward.itemIds,
            reward.amounts,
            reward.moaniAmount
        );
    }

    /**
     * @notice Get player reward state
     * @param player The player address
     * @return lastClaimTimestamp Last claim timestamp
     * @return currentStreakDay Current streak day (1-7)
     * @return lastStreakResetTimestamp Last streak reset timestamp
     */
    function getPlayerState(address player)
        external
        view
        returns (uint256 lastClaimTimestamp, uint256 currentStreakDay, uint256 lastStreakResetTimestamp)
    {
        PlayerRewardState memory state = _playerStates[player];
        return (state.lastClaimTimestamp, state.currentStreakDay, state.lastStreakResetTimestamp);
    }

    /**
     * @notice Get rewards for a specific day
     * @param day The day number (1-7)
     * @return The day reward structure
     */
    function getDayReward(uint256 day) external view returns (DayReward memory) {
        if (day < 1 || day > 7) {
            revert("Invalid day");
        }
        return _dailyRewards[day];
    }

    /**
     * @notice Check if player can claim reward
     * @param player The player address
     * @return True if reward is available
     */
    function canClaimReward(address player) external view returns (bool) {
        PlayerRewardState memory state = _playerStates[player];
        return block.timestamp >= state.lastClaimTimestamp + SECONDS_PER_DAY;
    }

    /**
     * @notice Pause daily rewards (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause daily rewards
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
