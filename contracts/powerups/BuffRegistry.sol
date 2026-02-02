// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/AccessControl.sol";

/**
 * @title BuffRegistry
 * @notice Registry for buff definitions and configurations
 * @dev Manages buff types, multipliers, durations, and stacking rules
 */
contract BuffRegistry is ParadiseAccessControl {
    /// @notice Buff type enum
    enum BuffType {
        HEALTH_BOOST, // Increase max health
        DOUBLE_SPEED, // 2x movement speed
        LUCK_INCREASE, // Better drop rates
        XP_MULTIPLIER, // 2x experience
        HARVEST_BONUS // More crops per harvest
    }

    /// @notice Buff definition structure
    struct BuffDefinition {
        bool exists;
        BuffType buffType;
        uint256 multiplier; // Multiplier in basis points (10000 = 1x, 20000 = 2x)
        uint256 durationSeconds; // Duration of the buff
        bool stackable; // Can multiple instances stack
        uint256 maxStacks; // Maximum stack count (1 = no stacking)
    }

    /// @notice Mapping of buff IDs to definitions
    mapping(uint256 => BuffDefinition) private _buffDefinitions;

    /// @notice Emitted when a buff definition is registered
    event BuffDefinitionRegistered(
        uint256 indexed buffId,
        BuffType buffType,
        uint256 multiplier,
        uint256 durationSeconds,
        bool stackable,
        uint256 maxStacks
    );

    /// @notice Emitted when a buff definition is updated
    event BuffDefinitionUpdated(uint256 indexed buffId);

    /**
     * @notice Constructor
     * @dev Initializes the registry
     */
    constructor() ParadiseAccessControl() {}

    /**
     * @notice Register a buff definition
     * @param buffId The buff ID
     * @param buffType The buff type
     * @param multiplier Multiplier in basis points (10000 = 1x, 20000 = 2x)
     * @param durationSeconds Duration in seconds
     * @param stackable Whether buffs can stack
     * @param maxStacks Maximum stack count
     * @dev Only callable by admin
     */
    function registerBuff(
        uint256 buffId,
        BuffType buffType,
        uint256 multiplier,
        uint256 durationSeconds,
        bool stackable,
        uint256 maxStacks
    ) external onlyRole(ADMIN_ROLE) {
        if (_buffDefinitions[buffId].exists) {
            revert("Buff already exists");
        }
        if (multiplier == 0) {
            revert("Invalid multiplier");
        }
        if (durationSeconds == 0) {
            revert("Invalid duration");
        }
        if (maxStacks == 0) {
            revert("Invalid max stacks");
        }

        _buffDefinitions[buffId] = BuffDefinition({
            exists: true,
            buffType: buffType,
            multiplier: multiplier,
            durationSeconds: durationSeconds,
            stackable: stackable,
            maxStacks: maxStacks
        });

        emit BuffDefinitionRegistered(buffId, buffType, multiplier, durationSeconds, stackable, maxStacks);
    }

    /**
     * @notice Update a buff definition
     * @param buffId The buff ID
     * @param multiplier New multiplier
     * @param durationSeconds New duration
     * @param stackable New stackable flag
     * @param maxStacks New max stacks
     * @dev Only callable by admin
     */
    function updateBuff(
        uint256 buffId,
        uint256 multiplier,
        uint256 durationSeconds,
        bool stackable,
        uint256 maxStacks
    ) external onlyRole(ADMIN_ROLE) {
        if (!_buffDefinitions[buffId].exists) {
            revert("Buff does not exist");
        }
        if (multiplier == 0) {
            revert("Invalid multiplier");
        }
        if (durationSeconds == 0) {
            revert("Invalid duration");
        }
        if (maxStacks == 0) {
            revert("Invalid max stacks");
        }

        _buffDefinitions[buffId].multiplier = multiplier;
        _buffDefinitions[buffId].durationSeconds = durationSeconds;
        _buffDefinitions[buffId].stackable = stackable;
        _buffDefinitions[buffId].maxStacks = maxStacks;

        emit BuffDefinitionUpdated(buffId);
    }

    /**
     * @notice Get buff definition
     * @param buffId The buff ID
     * @return The buff definition
     */
    function getBuffDefinition(uint256 buffId) external view returns (BuffDefinition memory) {
        if (!_buffDefinitions[buffId].exists) {
            revert("Buff does not exist");
        }
        return _buffDefinitions[buffId];
    }

    /**
     * @notice Check if a buff exists
     * @param buffId The buff ID
     * @return True if buff exists
     */
    function buffExists(uint256 buffId) external view returns (bool) {
        return _buffDefinitions[buffId].exists;
    }
}
