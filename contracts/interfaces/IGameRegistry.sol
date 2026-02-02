// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGameRegistry
 * @notice Interface for the central game registry contract
 * @dev Manages game contract addresses, item metadata, and global parameters
 */
interface IGameRegistry {
    /**
     * @notice Emitted when a game contract is registered
     * @param contractAddress The address of the registered contract
     * @param contractType The type identifier of the contract
     */
    event GameContractRegistered(address indexed contractAddress, bytes32 indexed contractType);

    /**
     * @notice Emitted when a game contract is deregistered
     * @param contractAddress The address of the deregistered contract
     */
    event GameContractDeregistered(address indexed contractAddress);

    /**
     * @notice Emitted when item metadata is updated
     * @param itemId The item ID
     * @param maxStackSize The maximum stack size for this item
     * @param rarity The rarity level (0-5)
     */
    event ItemMetadataUpdated(uint256 indexed itemId, uint256 maxStackSize, uint256 rarity);

    /**
     * @notice Emitted when a global parameter is updated
     * @param parameter The parameter name
     * @param value The new value
     */
    event ParameterUpdated(bytes32 indexed parameter, uint256 value);

    /**
     * @notice Check if an address is a registered game contract
     * @param contractAddress The address to check
     * @return True if registered
     */
    function isGameContract(address contractAddress) external view returns (bool);

    /**
     * @notice Get the contract type for a registered address
     * @param contractAddress The contract address
     * @return The contract type identifier
     */
    function getContractType(address contractAddress) external view returns (bytes32);

    /**
     * @notice Get item metadata
     * @param itemId The item ID
     * @return maxStackSize Maximum stack size
     * @return rarity Rarity level (0-5)
     * @return exists Whether the item exists
     */
    function getItemMetadata(uint256 itemId)
        external
        view
        returns (uint256 maxStackSize, uint256 rarity, bool exists);

    /**
     * @notice Get a global parameter value
     * @param parameter The parameter name
     * @return The parameter value
     */
    function getParameter(bytes32 parameter) external view returns (uint256);
}
