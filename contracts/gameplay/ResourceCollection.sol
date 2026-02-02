// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IParadiseItems.sol";
import "../core/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ResourceCollection
 * @notice Validates and records resource collection with tool mechanics
 * @dev Tracks tool durability and collection cooldowns on-chain
 */
contract ResourceCollection is ParadiseAccessControl, Pausable {
    /// @notice The Paradise Items contract
    IParadiseItems public immutable itemsContract;

    /// @notice Collection record structure
    struct CollectionRecord {
        uint256 itemId;
        uint256 amount;
        uint256 toolItemId; // Tool used (0 = no tool)
        uint256 timestamp;
    }

    /// @notice Tool durability mapping (itemId => owner => durability)
    mapping(uint256 => mapping(address => uint256)) private _toolDurability;

    /// @notice Collection cooldowns (itemId => owner => cooldown timestamp)
    mapping(uint256 => mapping(address => uint256)) private _collectionCooldowns;

    /// @notice Cooldown duration per item type (itemId => seconds)
    mapping(uint256 => uint256) private _cooldownDurations;

    /// @notice Emitted when resources are collected
    event ResourceCollected(
        address indexed player,
        uint256 indexed itemId,
        uint256 amount,
        uint256 toolItemId,
        uint256 timestamp
    );

    /// @notice Emitted when tool durability is reduced
    event ToolDurabilityReduced(
        address indexed owner,
        uint256 indexed toolItemId,
        uint256 newDurability
    );

    /// @notice Emitted when a cooldown duration is set
    event CooldownDurationSet(uint256 indexed itemId, uint256 duration);

    /**
     * @notice Constructor
     * @param itemsContract_ The Paradise Items contract address
     */
    constructor(address itemsContract_) ParadiseAccessControl() {
        if (itemsContract_ == address(0)) {
            revert("Invalid address");
        }
        itemsContract = IParadiseItems(itemsContract_);
    }

    /**
     * @notice Record resource collection (called by server after validation)
     * @param player The player address
     * @param itemId The resource item ID collected
     * @param amount The amount collected
     * @param toolItemId The tool used (0 = no tool)
     * @dev Only callable by authorized game contracts
     */
    function recordCollection(
        address player,
        uint256 itemId,
        uint256 amount,
        uint256 toolItemId
    ) external onlyRole(GAME_CONTRACT_ROLE) whenNotPaused {
        if (player == address(0)) {
            revert("Invalid player");
        }
        if (amount == 0) {
            revert("Invalid amount");
        }

        // Check cooldown
        uint256 cooldownDuration = _cooldownDurations[itemId];
        if (cooldownDuration > 0) {
            uint256 cooldownUntil = _collectionCooldowns[itemId][player];
            if (block.timestamp < cooldownUntil) {
                revert("Cooldown active");
            }
            _collectionCooldowns[itemId][player] = block.timestamp + cooldownDuration;
        }

        // Reduce tool durability if tool was used
        if (toolItemId > 0) {
            uint256 currentDurability = _toolDurability[toolItemId][player];
            if (currentDurability > 0) {
                _toolDurability[toolItemId][player] = currentDurability - 1;
                emit ToolDurabilityReduced(player, toolItemId, currentDurability - 1);
            }
        }

        emit ResourceCollected(player, itemId, amount, toolItemId, block.timestamp);
    }

    /**
     * @notice Set tool durability for a player
     * @param player The player address
     * @param toolItemId The tool item ID
     * @param durability The durability value
     * @dev Only callable by authorized game contracts
     */
    function setToolDurability(address player, uint256 toolItemId, uint256 durability)
        external
        onlyRole(GAME_CONTRACT_ROLE)
    {
        if (player == address(0)) {
            revert("Invalid player");
        }
        _toolDurability[toolItemId][player] = durability;
    }

    /**
     * @notice Set collection cooldown duration for an item type
     * @param itemId The item ID
     * @param durationSeconds The cooldown duration in seconds
     * @dev Only callable by admin or operator
     */
    function setCooldownDuration(uint256 itemId, uint256 durationSeconds)
        external
        onlyRole(OPERATOR_ROLE)
    {
        _cooldownDurations[itemId] = durationSeconds;
        emit CooldownDurationSet(itemId, durationSeconds);
    }

    /**
     * @notice Get tool durability for a player
     * @param player The player address
     * @param toolItemId The tool item ID
     * @return The current durability
     */
    function getToolDurability(address player, uint256 toolItemId)
        external
        view
        returns (uint256)
    {
        return _toolDurability[toolItemId][player];
    }

    /**
     * @notice Get collection cooldown timestamp for a player
     * @param player The player address
     * @param itemId The item ID
     * @return The timestamp when cooldown expires (0 = no cooldown)
     */
    function getCollectionCooldown(address player, uint256 itemId)
        external
        view
        returns (uint256)
    {
        return _collectionCooldowns[itemId][player];
    }

    /**
     * @notice Get cooldown duration for an item type
     * @param itemId The item ID
     * @return The cooldown duration in seconds
     */
    function getCooldownDuration(uint256 itemId) external view returns (uint256) {
        return _cooldownDurations[itemId];
    }

    /**
     * @notice Pause resource collection (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause resource collection
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
