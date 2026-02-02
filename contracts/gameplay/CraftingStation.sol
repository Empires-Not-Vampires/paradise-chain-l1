// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IParadiseItems.sol";
import "../core/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CraftingStation
 * @notice Blueprint-based crafting with resource burning
 * @dev Handles recipe validation, resource consumption, and item creation
 */
contract CraftingStation is ParadiseAccessControl, Pausable, ReentrancyGuard {
    /// @notice The Paradise Items contract
    IParadiseItems public immutable itemsContract;

    /// @notice Recipe structure
    struct Recipe {
        bool exists;
        uint256 stationType; // 0 = Workshop, 1 = JuiceBar, 2 = Sawmill, etc.
        uint256[] inputItemIds;
        uint256[] inputAmounts;
        uint256[] outputItemIds;
        uint256[] outputAmounts;
        uint256 craftingDurationSeconds; // 0 = instant
    }

    /// @notice Blueprint ownership (blueprintId => player => owned)
    mapping(uint256 => mapping(address => bool)) private _blueprintOwnership;

    /// @notice Recipe registry (recipeId => Recipe)
    mapping(uint256 => Recipe) private _recipes;

    /// @notice Active crafting jobs (player => recipeId => completion timestamp)
    mapping(address => mapping(uint256 => uint256)) private _activeCrafts;

    /// @notice Emitted when a blueprint is learned
    event BlueprintLearned(address indexed player, uint256 indexed blueprintId);

    /// @notice Emitted when crafting starts
    event CraftingStarted(
        address indexed player,
        uint256 indexed recipeId,
        uint256 completionTimestamp
    );

    /// @notice Emitted when an item is crafted
    event ItemCrafted(
        address indexed player,
        uint256 indexed recipeId,
        uint256[] outputItemIds,
        uint256[] outputAmounts
    );

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
     * @notice Register a recipe
     * @param recipeId The recipe ID
     * @param stationType The station type (0 = Workshop, etc.)
     * @param inputItemIds Array of input item IDs
     * @param inputAmounts Array of input amounts
     * @param outputItemIds Array of output item IDs
     * @param outputAmounts Array of output amounts
     * @param craftingDurationSeconds Crafting duration (0 = instant)
     * @dev Only callable by admin
     */
    function registerRecipe(
        uint256 recipeId,
        uint256 stationType,
        uint256[] memory inputItemIds,
        uint256[] memory inputAmounts,
        uint256[] memory outputItemIds,
        uint256[] memory outputAmounts,
        uint256 craftingDurationSeconds
    ) external onlyRole(ADMIN_ROLE) {
        if (_recipes[recipeId].exists) {
            revert("Recipe already exists");
        }
        if (inputItemIds.length != inputAmounts.length) {
            revert("Input array mismatch");
        }
        if (outputItemIds.length != outputAmounts.length) {
            revert("Output array mismatch");
        }
        if (inputItemIds.length == 0) {
            revert("No inputs");
        }
        if (outputItemIds.length == 0) {
            revert("No outputs");
        }

        _recipes[recipeId] = Recipe({
            exists: true,
            stationType: stationType,
            inputItemIds: inputItemIds,
            inputAmounts: inputAmounts,
            outputItemIds: outputItemIds,
            outputAmounts: outputAmounts,
            craftingDurationSeconds: craftingDurationSeconds
        });
    }

    /**
     * @notice Learn a blueprint
     * @param player The player address
     * @param blueprintId The blueprint ID
     * @dev Only callable by authorized game contracts
     */
    function learnBlueprint(address player, uint256 blueprintId)
        external
        onlyRole(GAME_CONTRACT_ROLE)
    {
        if (player == address(0)) {
            revert("Invalid player");
        }
        if (_blueprintOwnership[blueprintId][player]) {
            revert("Already learned");
        }

        _blueprintOwnership[blueprintId][player] = true;
        emit BlueprintLearned(player, blueprintId);
    }

    /**
     * @notice Craft an item using a recipe
     * @param recipeId The recipe ID
     * @dev Burns inputs and mints outputs
     */
    function craft(uint256 recipeId) external nonReentrant whenNotPaused {
        Recipe memory recipe = _recipes[recipeId];
        if (!recipe.exists) {
            revert("Recipe does not exist");
        }

        // Check if crafting is complete (if duration > 0)
        if (recipe.craftingDurationSeconds > 0) {
            uint256 completionTimestamp = _activeCrafts[msg.sender][recipeId];
            if (completionTimestamp == 0) {
                // Start crafting
                completionTimestamp = block.timestamp + recipe.craftingDurationSeconds;
                _activeCrafts[msg.sender][recipeId] = completionTimestamp;
                emit CraftingStarted(msg.sender, recipeId, completionTimestamp);
                return;
            } else if (block.timestamp < completionTimestamp) {
                revert("Crafting not complete");
            }
            // Clear the active craft
            delete _activeCrafts[msg.sender][recipeId];
        }

        // Burn input items
        for (uint256 i = 0; i < recipe.inputItemIds.length; i++) {
            itemsContract.burn(msg.sender, recipe.inputItemIds[i], recipe.inputAmounts[i]);
        }

        // Mint output items
        itemsContract.mintBatch(
            msg.sender,
            recipe.outputItemIds,
            recipe.outputAmounts,
            ""
        );

        emit ItemCrafted(msg.sender, recipeId, recipe.outputItemIds, recipe.outputAmounts);
    }

    /**
     * @notice Check if a player knows a blueprint
     * @param player The player address
     * @param blueprintId The blueprint ID
     * @return True if the player knows the blueprint
     */
    function knowsBlueprint(address player, uint256 blueprintId) external view returns (bool) {
        return _blueprintOwnership[blueprintId][player];
    }

    /**
     * @notice Get recipe details
     * @param recipeId The recipe ID
     * @return The recipe structure
     */
    function getRecipe(uint256 recipeId) external view returns (Recipe memory) {
        return _recipes[recipeId];
    }

    /**
     * @notice Get active craft completion timestamp
     * @param player The player address
     * @param recipeId The recipe ID
     * @return The completion timestamp (0 = no active craft)
     */
    function getActiveCraft(address player, uint256 recipeId) external view returns (uint256) {
        return _activeCrafts[player][recipeId];
    }

    /**
     * @notice Pause crafting (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause crafting
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
