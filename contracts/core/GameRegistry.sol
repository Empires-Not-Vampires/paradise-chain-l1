// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AccessControl.sol";
import "../interfaces/IGameRegistry.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title GameRegistry
 * @notice Central registry for game contracts, item metadata, and global parameters
 * @dev Manages the authoritative source of truth for game configuration
 */
contract GameRegistry is IGameRegistry, ParadiseAccessControl, Pausable {
    /// @notice Mapping of contract addresses to their types
    mapping(address => bytes32) private _contractTypes;

    /// @notice Set of registered game contracts
    mapping(address => bool) private _registeredContracts;

    /// @notice Item metadata structure
    struct ItemMetadata {
        uint256 maxStackSize;
        uint256 rarity;
        bool exists;
    }

    /// @notice Mapping of item IDs to their metadata
    mapping(uint256 => ItemMetadata) private _itemMetadata;

    /// @notice Global game parameters
    mapping(bytes32 => uint256) private _parameters;

    /**
     * @notice Constructor
     * @dev Initializes the registry with default admin
     */
    constructor() ParadiseAccessControl() {}

    /**
     * @notice Register a game contract
     * @param contractAddress The address of the contract to register
     * @param contractType The type identifier (e.g., "AUCTION_HOUSE", "CRAFTING_STATION")
     * @dev Only callable by admin
     */
    function registerGameContract(address contractAddress, bytes32 contractType)
        external
        onlyRole(ADMIN_ROLE)
    {
        if (contractAddress == address(0)) {
            revert("Invalid address");
        }
        if (_registeredContracts[contractAddress]) {
            revert("Already registered");
        }

        _registeredContracts[contractAddress] = true;
        _contractTypes[contractAddress] = contractType;

        emit GameContractRegistered(contractAddress, contractType);
    }

    /**
     * @notice Deregister a game contract
     * @param contractAddress The address of the contract to deregister
     * @dev Only callable by admin
     */
    function deregisterGameContract(address contractAddress) external onlyRole(ADMIN_ROLE) {
        if (!_registeredContracts[contractAddress]) {
            revert("Not registered");
        }

        delete _registeredContracts[contractAddress];
        delete _contractTypes[contractAddress];

        emit GameContractDeregistered(contractAddress);
    }

    /**
     * @notice Update item metadata
     * @param itemId The item ID
     * @param maxStackSize Maximum stack size for this item
     * @param rarity Rarity level (0-5)
     * @dev Only callable by admin or operator
     */
    function updateItemMetadata(uint256 itemId, uint256 maxStackSize, uint256 rarity)
        external
        onlyRole(OPERATOR_ROLE)
    {
        if (maxStackSize == 0) {
            revert("Invalid stack size");
        }
        if (rarity > 5) {
            revert("Invalid rarity");
        }

        _itemMetadata[itemId] = ItemMetadata({
            maxStackSize: maxStackSize,
            rarity: rarity,
            exists: true
        });

        emit ItemMetadataUpdated(itemId, maxStackSize, rarity);
    }

    /**
     * @notice Set a global parameter
     * @param parameter The parameter name
     * @param value The parameter value
     * @dev Only callable by admin or operator
     */
    function setParameter(bytes32 parameter, uint256 value) external onlyRole(OPERATOR_ROLE) {
        _parameters[parameter] = value;
        emit ParameterUpdated(parameter, value);
    }

    /**
     * @notice Pause the registry (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the registry
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function isGameContract(address contractAddress) external view override returns (bool) {
        return _registeredContracts[contractAddress];
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getContractType(address contractAddress) external view override returns (bytes32) {
        if (!_registeredContracts[contractAddress]) {
            revert("Not registered");
        }
        return _contractTypes[contractAddress];
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getItemMetadata(uint256 itemId)
        external
        view
        override
        returns (uint256 maxStackSize, uint256 rarity, bool exists)
    {
        ItemMetadata memory metadata = _itemMetadata[itemId];
        return (metadata.maxStackSize, metadata.rarity, metadata.exists);
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getParameter(bytes32 parameter) external view override returns (uint256) {
        return _parameters[parameter];
    }
}
