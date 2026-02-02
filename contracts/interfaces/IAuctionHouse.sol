// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAuctionHouse
 * @notice Interface for the Auction House marketplace contract
 * @dev Handles player-to-player item trading with fees
 */
interface IAuctionHouse {
    /**
     * @notice Listing structure
     * @param seller The address selling the item
     * @param itemId The item ID being sold
     * @param amount The amount of items
     * @param unitPrice The price per item (in MOANI, 18 decimals)
     * @param expiresAt The timestamp when the listing expires
     * @param active Whether the listing is still active
     */
    struct Listing {
        address seller;
        uint256 itemId;
        uint256 amount;
        uint256 unitPrice;
        uint256 expiresAt;
        bool active;
    }

    /**
     * @notice Emitted when a new listing is created
     * @param listingId The unique listing ID
     * @param seller The seller address
     * @param itemId The item ID
     * @param amount The amount listed
     * @param unitPrice The price per item
     * @param expiresAt Expiration timestamp
     */
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed itemId,
        uint256 amount,
        uint256 unitPrice,
        uint256 expiresAt
    );

    /**
     * @notice Emitted when an item is purchased
     * @param listingId The listing ID
     * @param buyer The buyer address
     * @param seller The seller address
     * @param itemId The item ID
     * @param amount The amount purchased
     * @param totalPrice The total price paid
     * @param fee The marketplace fee deducted
     */
    event ItemSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 itemId,
        uint256 amount,
        uint256 totalPrice,
        uint256 fee
    );

    /**
     * @notice Emitted when a listing is cancelled
     * @param listingId The listing ID
     * @param seller The seller address
     */
    event ListingCancelled(uint256 indexed listingId, address indexed seller);

    /**
     * @notice Create a new listing
     * @param itemId The item ID to sell
     * @param amount The amount to sell
     * @param unitPrice The price per item (in MOANI, 18 decimals)
     * @param durationSeconds How long the listing should be active
     * @return listingId The ID of the created listing
     */
    function listItem(
        uint256 itemId,
        uint256 amount,
        uint256 unitPrice,
        uint256 durationSeconds
    ) external returns (uint256 listingId);

    /**
     * @notice Purchase items from a listing
     * @param listingId The listing ID to purchase from
     * @param amount The amount to purchase (must be <= listing amount)
     */
    function purchase(uint256 listingId, uint256 amount) external payable;

    /**
     * @notice Cancel an active listing
     * @param listingId The listing ID to cancel
     */
    function cancelListing(uint256 listingId) external;

    /**
     * @notice Get listing details
     * @param listingId The listing ID
     * @return The listing structure
     */
    function getListing(uint256 listingId) external view returns (Listing memory);

    /**
     * @notice Get the number of active listings for a seller
     * @param seller The seller address
     * @return The number of active listings
     */
    function getSellerListingCount(address seller) external view returns (uint256);
}
