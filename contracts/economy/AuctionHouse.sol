// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IAuctionHouse.sol";
import "../interfaces/IParadiseItems.sol";
import "../core/AccessControl.sol";
import "../economy/Treasury.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title AuctionHouse
 * @notice Player-to-player marketplace with real economy
 * @dev Handles item listings, purchases, and fee collection
 */
contract AuctionHouse is IAuctionHouse, ParadiseAccessControl, ReentrancyGuard, Pausable {
    /// @notice The Paradise Items contract
    IParadiseItems public immutable itemsContract;

    /// @notice The Treasury contract for fee collection
    Treasury public immutable treasury;

    /// @notice Marketplace fee divisor (e.g., 20 = 5% fee)
    uint256 public feeDivisor;

    /// @notice Minimum marketplace fee (in wei)
    uint256 public minFee;

    /// @notice Maximum listings per seller
    uint256 public maxListingsPerSeller;

    /// @notice Counter for listing IDs
    uint256 private _listingCounter;

    /// @notice Mapping of listing IDs to listings
    mapping(uint256 => Listing) private _listings;

    /// @notice Mapping of seller to their active listing count
    mapping(address => uint256) private _sellerListingCounts;

    /// @notice Parameter names for registry
    bytes32 public constant PARAM_FEE_DIVISOR = keccak256("AUCTION_FEE_DIVISOR");
    bytes32 public constant PARAM_MIN_FEE = keccak256("AUCTION_MIN_FEE");
    bytes32 public constant PARAM_MAX_LISTINGS = keccak256("AUCTION_MAX_LISTINGS");

    /**
     * @notice Constructor
     * @param itemsContract_ The Paradise Items contract address
     * @param treasury_ The Treasury contract address
     * @param feeDivisor_ The fee divisor (e.g., 20 = 5%)
     * @param minFee_ The minimum fee in wei
     * @param maxListingsPerSeller_ Maximum listings per seller
     */
    constructor(
        address itemsContract_,
        address treasury_,
        uint256 feeDivisor_,
        uint256 minFee_,
        uint256 maxListingsPerSeller_
    ) ParadiseAccessControl() {
        if (itemsContract_ == address(0) || treasury_ == address(0)) {
            revert("Invalid address");
        }
        if (feeDivisor_ == 0) {
            revert("Invalid fee divisor");
        }

        itemsContract = IParadiseItems(itemsContract_);
        treasury = Treasury(payable(treasury_));
        feeDivisor = feeDivisor_;
        minFee = minFee_;
        maxListingsPerSeller = maxListingsPerSeller_;
    }

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
    ) external override nonReentrant whenNotPaused returns (uint256 listingId) {
        if (amount == 0) {
            revert("Invalid amount");
        }
        if (unitPrice == 0) {
            revert("Invalid price");
        }
        if (durationSeconds == 0 || durationSeconds > 30 days) {
            revert("Invalid duration");
        }

        // Check listing limit
        if (_sellerListingCounts[msg.sender] >= maxListingsPerSeller) {
            revert("Max listings reached");
        }

        // Transfer items from seller to contract
        itemsContract.safeTransferFrom(msg.sender, address(this), itemId, amount, "");

        // Create listing
        listingId = ++_listingCounter;
        _listings[listingId] = Listing({
            seller: msg.sender,
            itemId: itemId,
            amount: amount,
            unitPrice: unitPrice,
            expiresAt: block.timestamp + durationSeconds,
            active: true
        });

        _sellerListingCounts[msg.sender]++;

        emit ListingCreated(listingId, msg.sender, itemId, amount, unitPrice, _listings[listingId].expiresAt);
    }

    /**
     * @notice Purchase items from a listing
     * @param listingId The listing ID to purchase from
     * @param amount The amount to purchase (must be <= listing amount)
     */
    function purchase(uint256 listingId, uint256 amount)
        external
        payable
        override
        nonReentrant
        whenNotPaused
    {
        Listing storage listing = _listings[listingId];

        if (!listing.active) {
            revert("Listing not active");
        }
        if (block.timestamp > listing.expiresAt) {
            revert("Listing expired");
        }
        if (amount == 0 || amount > listing.amount) {
            revert("Invalid amount");
        }
        if (msg.sender == listing.seller) {
            revert("Cannot buy own listing");
        }

        uint256 totalPrice = listing.unitPrice * amount;
        if (msg.value < totalPrice) {
            revert("Insufficient payment");
        }

        // Calculate fee
        uint256 fee = (totalPrice / feeDivisor);
        if (fee < minFee) {
            fee = minFee;
        }
        uint256 sellerAmount = totalPrice - fee;

        // Transfer items to buyer
        itemsContract.safeTransferFrom(address(this), msg.sender, listing.itemId, amount, "");

        // Send payment to seller
        (bool sellerSuccess, ) = listing.seller.call{value: sellerAmount}("");
        if (!sellerSuccess) {
            revert("Seller payment failed");
        }

        // Send fee to treasury
        treasury.collectFees{value: fee}("AUCTION_HOUSE");

        // Refund excess payment
        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - totalPrice}("");
            if (!refundSuccess) {
                revert("Refund failed");
            }
        }

        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
            _sellerListingCounts[listing.seller]--;
        }

        emit ItemSold(listingId, msg.sender, listing.seller, listing.itemId, amount, totalPrice, fee);
    }

    /**
     * @notice Cancel an active listing
     * @param listingId The listing ID to cancel
     */
    function cancelListing(uint256 listingId) external override nonReentrant whenNotPaused {
        Listing storage listing = _listings[listingId];

        if (!listing.active) {
            revert("Listing not active");
        }
        if (msg.sender != listing.seller) {
            revert("Not seller");
        }

        // Return items to seller
        itemsContract.safeTransferFrom(
            address(this),
            listing.seller,
            listing.itemId,
            listing.amount,
            ""
        );

        listing.active = false;
        _sellerListingCounts[listing.seller]--;

        emit ListingCancelled(listingId, listing.seller);
    }

    /**
     * @notice Update marketplace fee divisor
     * @param newFeeDivisor The new fee divisor
     * @dev Only callable by admin
     */
    function setFeeDivisor(uint256 newFeeDivisor) external onlyRole(ADMIN_ROLE) {
        if (newFeeDivisor == 0) {
            revert("Invalid fee divisor");
        }
        feeDivisor = newFeeDivisor;
    }

    /**
     * @notice Update minimum fee
     * @param newMinFee The new minimum fee
     * @dev Only callable by admin
     */
    function setMinFee(uint256 newMinFee) external onlyRole(ADMIN_ROLE) {
        minFee = newMinFee;
    }

    /**
     * @notice Update maximum listings per seller
     * @param newMax The new maximum
     * @dev Only callable by admin
     */
    function setMaxListingsPerSeller(uint256 newMax) external onlyRole(ADMIN_ROLE) {
        maxListingsPerSeller = newMax;
    }

    /**
     * @inheritdoc IAuctionHouse
     */
    function getListing(uint256 listingId) external view override returns (Listing memory) {
        return _listings[listingId];
    }

    /**
     * @inheritdoc IAuctionHouse
     */
    function getSellerListingCount(address seller) external view override returns (uint256) {
        return _sellerListingCounts[seller];
    }

    /**
     * @notice Pause the auction house (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the auction house
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Handle ERC1155 token received (required for safeTransferFrom)
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @notice Handle ERC1155 batch token received
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
