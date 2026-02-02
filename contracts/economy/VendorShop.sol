// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IParadiseItems.sol";
import "../core/AccessControl.sol";
import "../economy/Treasury.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title VendorShop
 * @notice NPC vendor purchases with stock management
 * @dev Handles fixed-price vendor purchases with daily restock cycles
 */
contract VendorShop is ParadiseAccessControl, ReentrancyGuard, Pausable {
    /// @notice The Paradise Items contract
    IParadiseItems public immutable itemsContract;

    /// @notice The Treasury contract
    Treasury public immutable treasury;

    /// @notice Vendor structure
    struct Vendor {
        bool exists;
        uint256 restockCycleSeconds; // How often stock restocks
        uint256 lastRestockTimestamp;
    }

    /// @notice Vendor item structure
    struct VendorItem {
        bool exists;
        uint256 itemId;
        uint256 price; // Price in MOANI (18 decimals)
        uint256 stock; // Current stock
        uint256 maxStock; // Maximum stock per restock
    }

    /// @notice Mapping of vendor IDs to vendors
    mapping(uint256 => Vendor) private _vendors;

    /// @notice Mapping of vendor ID => item ID => vendor item
    mapping(uint256 => mapping(uint256 => VendorItem)) private _vendorItems;

    /// @notice Emitted when a purchase is made
    event VendorPurchase(
        address indexed buyer,
        uint256 indexed vendorId,
        uint256 indexed itemId,
        uint256 amount,
        uint256 totalPrice
    );

    /// @notice Emitted when vendor stock is restocked
    event StockRestocked(uint256 indexed vendorId, uint256 indexed itemId, uint256 newStock);

    /**
     * @notice Constructor
     * @param itemsContract_ The Paradise Items contract address
     * @param treasury_ The Treasury contract address
     */
    constructor(address itemsContract_, address treasury_) ParadiseAccessControl() {
        if (itemsContract_ == address(0) || treasury_ == address(0)) {
            revert("Invalid address");
        }

        itemsContract = IParadiseItems(itemsContract_);
        treasury = Treasury(payable(treasury_));
    }

    /**
     * @notice Register a new vendor
     * @param vendorId The vendor ID
     * @param restockCycleSeconds How often stock restocks (in seconds)
     * @dev Only callable by admin
     */
    function registerVendor(uint256 vendorId, uint256 restockCycleSeconds)
        external
        onlyRole(ADMIN_ROLE)
    {
        if (_vendors[vendorId].exists) {
            revert("Vendor already exists");
        }
        if (restockCycleSeconds == 0) {
            revert("Invalid restock cycle");
        }

        _vendors[vendorId] = Vendor({
            exists: true,
            restockCycleSeconds: restockCycleSeconds,
            lastRestockTimestamp: block.timestamp
        });
    }

    /**
     * @notice Add an item to a vendor's inventory
     * @param vendorId The vendor ID
     * @param itemId The item ID
     * @param price The price per item (in MOANI, 18 decimals)
     * @param maxStock Maximum stock per restock cycle
     * @dev Only callable by admin
     */
    function addVendorItem(
        uint256 vendorId,
        uint256 itemId,
        uint256 price,
        uint256 maxStock
    ) external onlyRole(ADMIN_ROLE) {
        if (!_vendors[vendorId].exists) {
            revert("Vendor does not exist");
        }
        if (_vendorItems[vendorId][itemId].exists) {
            revert("Item already exists");
        }
        if (price == 0) {
            revert("Invalid price");
        }
        if (maxStock == 0) {
            revert("Invalid max stock");
        }

        _vendorItems[vendorId][itemId] = VendorItem({
            exists: true,
            itemId: itemId,
            price: price,
            stock: maxStock,
            maxStock: maxStock
        });
    }

    /**
     * @notice Restock vendor items (can be called by anyone, auto-restocks if cycle passed)
     * @param vendorId The vendor ID
     * @param itemIds Array of item IDs to restock (empty array = restock all)
     */
    function restockVendor(uint256 vendorId, uint256[] memory itemIds) external {
        Vendor storage vendor = _vendors[vendorId];
        if (!vendor.exists) {
            revert("Vendor does not exist");
        }

        // Check if restock cycle has passed
        if (block.timestamp < vendor.lastRestockTimestamp + vendor.restockCycleSeconds) {
            revert("Restock cycle not ready");
        }

        // If empty array, we'd need to track all items - for now, require specific items
        if (itemIds.length == 0) {
            revert("Must specify items");
        }

        vendor.lastRestockTimestamp = block.timestamp;

        for (uint256 i = 0; i < itemIds.length; i++) {
            VendorItem storage item = _vendorItems[vendorId][itemIds[i]];
            if (item.exists) {
                item.stock = item.maxStock;
                emit StockRestocked(vendorId, itemIds[i], item.stock);
            }
        }
    }

    /**
     * @notice Purchase items from a vendor
     * @param vendorId The vendor ID
     * @param itemId The item ID to purchase
     * @param amount The amount to purchase
     */
    function purchaseFromVendor(uint256 vendorId, uint256 itemId, uint256 amount)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        Vendor storage vendor = _vendors[vendorId];
        if (!vendor.exists) {
            revert("Vendor does not exist");
        }

        VendorItem storage vendorItem = _vendorItems[vendorId][itemId];
        if (!vendorItem.exists) {
            revert("Item not available");
        }

        // Auto-restock if cycle passed
        if (block.timestamp >= vendor.lastRestockTimestamp + vendor.restockCycleSeconds) {
            vendorItem.stock = vendorItem.maxStock;
            vendor.lastRestockTimestamp = block.timestamp;
            emit StockRestocked(vendorId, itemId, vendorItem.stock);
        }

        if (amount == 0 || amount > vendorItem.stock) {
            revert("Invalid amount");
        }

        uint256 totalPrice = vendorItem.price * amount;
        if (msg.value < totalPrice) {
            revert("Insufficient payment");
        }

        // Update stock
        vendorItem.stock -= amount;

        // Send payment to treasury
        treasury.collectFees{value: totalPrice}("VENDOR_SHOP");

        // Refund excess payment
        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - totalPrice}("");
            if (!refundSuccess) {
                revert("Refund failed");
            }
        }

        // Mint items to buyer
        itemsContract.mint(msg.sender, itemId, amount, "");

        emit VendorPurchase(msg.sender, vendorId, itemId, amount, totalPrice);
    }

    /**
     * @notice Get vendor information
     * @param vendorId The vendor ID
     * @return exists Whether vendor exists
     * @return restockCycleSeconds Restock cycle duration
     * @return lastRestockTimestamp Last restock timestamp
     */
    function getVendor(uint256 vendorId)
        external
        view
        returns (bool exists, uint256 restockCycleSeconds, uint256 lastRestockTimestamp)
    {
        Vendor memory vendor = _vendors[vendorId];
        return (vendor.exists, vendor.restockCycleSeconds, vendor.lastRestockTimestamp);
    }

    /**
     * @notice Get vendor item information
     * @param vendorId The vendor ID
     * @param itemId The item ID
     * @return exists Whether item exists
     * @return price Price per item
     * @return stock Current stock
     * @return maxStock Maximum stock
     */
    function getVendorItem(uint256 vendorId, uint256 itemId)
        external
        view
        returns (bool exists, uint256 price, uint256 stock, uint256 maxStock)
    {
        VendorItem memory item = _vendorItems[vendorId][itemId];
        return (item.exists, item.price, item.stock, item.maxStock);
    }

    /**
     * @notice Pause the vendor shop (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the vendor shop
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
