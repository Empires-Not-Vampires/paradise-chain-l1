// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IParadiseItems.sol";
import "./AccessControl.sol";

/**
 * @title ParadiseItems
 * @notice ERC-1155 multi-token contract for all Paradise Tycoon in-game items
 * @dev Supports fungible items (resources, consumables) and semi-fungible items (tools with durability)
 */
contract ParadiseItems is IParadiseItems, ERC1155, ParadiseAccessControl, Pausable {
    /// @notice Base URI for token metadata
    string private _baseURI;

    /// @notice Mapping of item IDs to their specific URIs (overrides base URI)
    mapping(uint256 => string) private _itemURIs;

    /**
     * @notice Constructor
     * @param baseURI_ The base URI for token metadata
     * @dev Grants GAME_CONTRACT_ROLE to the deployer initially
     */
    constructor(string memory baseURI_) ERC1155(baseURI_) ParadiseAccessControl() {
        _baseURI = baseURI_;
        // Grant game contract role to deployer for initial setup
        _grantRole(GAME_CONTRACT_ROLE, msg.sender);
    }

    /**
     * @notice Set the base URI for all tokens
     * @param baseURI_ The new base URI
     * @dev Only callable by admin
     */
    function setBaseURI(string memory baseURI_) external onlyRole(ADMIN_ROLE) {
        _baseURI = baseURI_;
        _setURI(baseURI_);
    }

    /**
     * @notice Set a specific URI for an item (overrides base URI)
     * @param itemId The item ID
     * @param itemURI The specific URI for this item
     * @dev Only callable by admin
     */
    function setItemURI(uint256 itemId, string memory itemURI) external onlyRole(ADMIN_ROLE) {
        _itemURIs[itemId] = itemURI;
    }

    /**
     * @notice Pause all transfers (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause all transfers
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Mint items to an address
     * @param to The recipient address
     * @param itemId The item ID to mint
     * @param amount The amount to mint
     * @param data Additional data
     * @dev Only callable by authorized game contracts
     */
    function mint(address to, uint256 itemId, uint256 amount, bytes memory data)
        external
        override
        onlyRole(GAME_CONTRACT_ROLE)
        whenNotPaused
    {
        if (to == address(0)) {
            revert("Invalid recipient");
        }
        if (amount == 0) {
            revert("Invalid amount");
        }

        _mint(to, itemId, amount, data);
        emit ItemsMinted(to, itemId, amount, data);
    }

    /**
     * @notice Mint multiple items in a batch
     * @param to The recipient address
     * @param itemIds Array of item IDs
     * @param amounts Array of amounts
     * @param data Additional data
     * @dev Only callable by authorized game contracts
     */
    function mintBatch(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts,
        bytes memory data
    ) external override onlyRole(GAME_CONTRACT_ROLE) whenNotPaused {
        if (to == address(0)) {
            revert("Invalid recipient");
        }
        if (itemIds.length != amounts.length) {
            revert("Array length mismatch");
        }
        if (itemIds.length == 0) {
            revert("Empty arrays");
        }

        _mintBatch(to, itemIds, amounts, data);

        for (uint256 i = 0; i < itemIds.length; i++) {
            emit ItemsMinted(to, itemIds[i], amounts[i], data);
        }
    }

    /**
     * @notice Burn items from an address
     * @param from The address to burn from
     * @param itemId The item ID to burn
     * @param amount The amount to burn
     * @dev Only callable by authorized game contracts
     */
    function burn(address from, uint256 itemId, uint256 amount)
        external
        override
        onlyRole(GAME_CONTRACT_ROLE)
        whenNotPaused
    {
        if (from == address(0)) {
            revert("Invalid address");
        }
        if (amount == 0) {
            revert("Invalid amount");
        }

        _burn(from, itemId, amount);
        emit ItemsBurned(from, itemId, amount);
    }

    /**
     * @notice Burn multiple items in a batch
     * @param from The address to burn from
     * @param itemIds Array of item IDs
     * @param amounts Array of amounts
     * @dev Only callable by authorized game contracts
     */
    function burnBatch(address from, uint256[] memory itemIds, uint256[] memory amounts)
        external
        override
        onlyRole(GAME_CONTRACT_ROLE)
        whenNotPaused
    {
        if (from == address(0)) {
            revert("Invalid address");
        }
        if (itemIds.length != amounts.length) {
            revert("Array length mismatch");
        }
        if (itemIds.length == 0) {
            revert("Empty arrays");
        }

        _burnBatch(from, itemIds, amounts);

        for (uint256 i = 0; i < itemIds.length; i++) {
            emit ItemsBurned(from, itemIds[i], amounts[i]);
        }
    }

    /**
     * @notice Get the URI for an item's metadata
     * @param itemId The item ID
     * @return The metadata URI
     */
    function uri(uint256 itemId) public view override(ERC1155, IParadiseItems) returns (string memory) {
        string memory itemURI = _itemURIs[itemId];
        if (bytes(itemURI).length > 0) {
            return itemURI;
        }
        return super.uri(itemId);
    }

    /**
     * @notice Override supportsInterface to include custom interfaces
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return interfaceId == type(IParadiseItems).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @notice Override _update to add pause check
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override whenNotPaused {
        super._update(from, to, ids, values);
    }
}
