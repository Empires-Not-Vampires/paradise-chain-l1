// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title IParadiseItems
 * @notice Interface for the Paradise Items ERC-1155 token contract
 * @dev Extends ERC-1155 with game-specific minting and burning functions
 */
interface IParadiseItems is IERC1155 {
    /**
     * @notice Emitted when items are minted
     * @param to The recipient address
     * @param itemId The item ID
     * @param amount The amount minted
     * @param data Additional data
     */
    event ItemsMinted(address indexed to, uint256 indexed itemId, uint256 amount, bytes data);

    /**
     * @notice Emitted when items are burned
     * @param from The address items are burned from
     * @param itemId The item ID
     * @param amount The amount burned
     */
    event ItemsBurned(address indexed from, uint256 indexed itemId, uint256 amount);

    /**
     * @notice Mint items to an address
     * @param to The recipient address
     * @param itemId The item ID to mint
     * @param amount The amount to mint
     * @param data Additional data
     * @dev Only callable by authorized game contracts
     */
    function mint(address to, uint256 itemId, uint256 amount, bytes memory data) external;

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
    ) external;

    /**
     * @notice Burn items from an address
     * @param from The address to burn from
     * @param itemId The item ID to burn
     * @param amount The amount to burn
     * @dev Only callable by authorized game contracts
     */
    function burn(address from, uint256 itemId, uint256 amount) external;

    /**
     * @notice Burn multiple items in a batch
     * @param from The address to burn from
     * @param itemIds Array of item IDs
     * @param amounts Array of amounts
     * @dev Only callable by authorized game contracts
     */
    function burnBatch(address from, uint256[] memory itemIds, uint256[] memory amounts) external;

    /**
     * @notice Get the URI for an item's metadata
     * @param itemId The item ID
     * @return The metadata URI
     */
    function uri(uint256 itemId) external view returns (string memory);
}
