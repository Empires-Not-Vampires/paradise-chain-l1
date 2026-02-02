// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IParadiseItems.sol";
import "../core/AccessControl.sol";
import "./BuffRegistry.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PowerupManager
 * @notice Manages temporary buffs and consumable powerups
 * @dev Handles buff activation, duration tracking, and stacking rules
 */
contract PowerupManager is ParadiseAccessControl, Pausable, ReentrancyGuard {
    /// @notice The Paradise Items contract
    IParadiseItems public immutable itemsContract;

    /// @notice The Buff Registry contract
    BuffRegistry public immutable buffRegistry;

    /// @notice Active buff structure
    struct ActiveBuff {
        uint256 buffId;
        uint256 expiresAt;
        uint256 stacks; // Current stack count
    }

    /// @notice Player active buffs (player => buffId => ActiveBuff)
    mapping(address => mapping(uint256 => ActiveBuff)) private _playerBuffs;

    /// @notice Mapping of powerup item IDs to buff IDs (itemId => buffId)
    mapping(uint256 => uint256) private _powerupItemToBuff;

    /// @notice Emitted when a powerup is activated
    event PowerupActivated(
        address indexed player,
        uint256 indexed buffId,
        uint256 itemId,
        uint256 expiresAt,
        uint256 stacks
    );

    /// @notice Emitted when a buff expires
    event PowerupExpired(address indexed player, uint256 indexed buffId);

    /**
     * @notice Constructor
     * @param itemsContract_ The Paradise Items contract address
     * @param buffRegistry_ The Buff Registry contract address
     */
    constructor(address itemsContract_, address buffRegistry_) ParadiseAccessControl() {
        if (itemsContract_ == address(0) || buffRegistry_ == address(0)) {
            revert("Invalid address");
        }
        itemsContract = IParadiseItems(itemsContract_);
        buffRegistry = BuffRegistry(buffRegistry_);
    }

    /**
     * @notice Register a powerup item (maps item ID to buff ID)
     * @param itemId The powerup item ID
     * @param buffId The buff ID it activates
     * @dev Only callable by admin
     */
    function registerPowerupItem(uint256 itemId, uint256 buffId) external onlyRole(ADMIN_ROLE) {
        if (!buffRegistry.buffExists(buffId)) {
            revert("Buff does not exist");
        }
        _powerupItemToBuff[itemId] = buffId;
    }

    /**
     * @notice Activate a powerup by consuming an item
     * @param itemId The powerup item ID to consume
     * @param amount The amount to consume (usually 1)
     */
    function activatePowerup(uint256 itemId, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) {
            revert("Invalid amount");
        }

        uint256 buffId = _powerupItemToBuff[itemId];
        if (buffId == 0) {
            revert("Not a powerup item");
        }

        // Get buff definition
        BuffRegistry.BuffDefinition memory buffDef = buffRegistry.getBuffDefinition(buffId);

        // Burn the powerup item
        itemsContract.burn(msg.sender, itemId, amount);

        // Get current active buff
        ActiveBuff storage activeBuff = _playerBuffs[msg.sender][buffId];

        // Check if buff is expired
        if (block.timestamp >= activeBuff.expiresAt) {
            // Reset stacks if expired
            activeBuff.stacks = 0;
        }

        // Check stacking rules
        if (!buffDef.stackable) {
            // Non-stackable: reset to 1 stack, extend duration
            activeBuff.stacks = 1;
            activeBuff.expiresAt = block.timestamp + buffDef.durationSeconds;
        } else {
            // Stackable: increment stacks (up to max)
            if (activeBuff.stacks < buffDef.maxStacks) {
                activeBuff.stacks++;
            }
            // Extend duration
            activeBuff.expiresAt = block.timestamp + buffDef.durationSeconds;
        }

        activeBuff.buffId = buffId;

        emit PowerupActivated(
            msg.sender,
            buffId,
            itemId,
            activeBuff.expiresAt,
            activeBuff.stacks
        );
    }

    /**
     * @notice Check and expire buffs (can be called by anyone)
     * @param player The player address
     * @param buffId The buff ID to check
     * @dev Removes expired buffs
     */
    function expireBuff(address player, uint256 buffId) external {
        ActiveBuff storage activeBuff = _playerBuffs[player][buffId];
        if (activeBuff.buffId == 0) {
            return; // No active buff
        }

        if (block.timestamp >= activeBuff.expiresAt) {
            delete _playerBuffs[player][buffId];
            emit PowerupExpired(player, buffId);
        }
    }

    /**
     * @notice Get active buff for a player
     * @param player The player address
     * @param buffId The buff ID
     * @return buffId The buff ID
     * @return expiresAt Expiration timestamp
     * @return stacks Current stack count
     * @return isActive True if buff is currently active
     */
    function getActiveBuff(address player, uint256 buffId)
        external
        view
        returns (uint256, uint256, uint256, bool)
    {
        ActiveBuff memory activeBuff = _playerBuffs[player][buffId];
        bool isActive = activeBuff.buffId != 0 && block.timestamp < activeBuff.expiresAt;
        return (activeBuff.buffId, activeBuff.expiresAt, activeBuff.stacks, isActive);
    }

    /**
     * @notice Get powerup item to buff mapping
     * @param itemId The powerup item ID
     * @return The buff ID (0 if not a powerup)
     */
    function getPowerupBuffId(uint256 itemId) external view returns (uint256) {
        return _powerupItemToBuff[itemId];
    }

    /**
     * @notice Check if a player has an active buff
     * @param player The player address
     * @param buffId The buff ID
     * @return True if buff is active
     */
    function hasActiveBuff(address player, uint256 buffId) external view returns (bool) {
        ActiveBuff memory activeBuff = _playerBuffs[player][buffId];
        return activeBuff.buffId != 0 && block.timestamp < activeBuff.expiresAt;
    }

    /**
     * @notice Pause powerup system (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause powerup system
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
