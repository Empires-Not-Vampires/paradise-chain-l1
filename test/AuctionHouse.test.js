const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AuctionHouse", function () {
    let auctionHouse;
    let paradiseItems;
    let treasury;
    let gameRegistry;
    let owner;
    let seller;
    let buyer;
    let admin;

    const ITEM_ID = 1;
    const AMOUNT = 100;
    const UNIT_PRICE = ethers.parseEther("1.0");
    const DURATION = 7 * 24 * 60 * 60; // 7 days

    beforeEach(async function () {
        [owner, admin, seller, buyer] = await ethers.getSigners();

        // Deploy GameRegistry
        const GameRegistry = await ethers.getContractFactory("GameRegistry");
        gameRegistry = await GameRegistry.deploy();

        // Deploy ParadiseItems
        const ParadiseItems = await ethers.getContractFactory("ParadiseItems");
        paradiseItems = await ParadiseItems.deploy("https://api.paradise.cloud/items/");

        // Deploy Treasury
        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy();

        // Grant roles
        const GAME_CONTRACT_ROLE = await paradiseItems.GAME_CONTRACT_ROLE();
        await paradiseItems.grantRole(GAME_CONTRACT_ROLE, await treasury.getAddress());

        // Deploy AuctionHouse
        const AuctionHouse = await ethers.getContractFactory("AuctionHouse");
        auctionHouse = await AuctionHouse.deploy(
            await paradiseItems.getAddress(),
            await treasury.getAddress(),
            20, // 5% fee
            ethers.parseEther("0.001"), // min fee
            10 // max listings
        );

        // Grant roles to AuctionHouse
        await paradiseItems.grantRole(GAME_CONTRACT_ROLE, await auctionHouse.getAddress());
        await treasury.grantRole(GAME_CONTRACT_ROLE, await auctionHouse.getAddress());

        // Mint items to seller
        await paradiseItems.mint(await seller.getAddress(), ITEM_ID, AMOUNT, "0x");
    });

    describe("Deployment", function () {
        it("Should set correct initial values", async function () {
            expect(await auctionHouse.feeDivisor()).to.equal(20);
            expect(await auctionHouse.maxListingsPerSeller()).to.equal(10);
        });
    });

    describe("Listing", function () {
        it("Should create a listing", async function () {
            await paradiseItems
                .connect(seller)
                .setApprovalForAll(await auctionHouse.getAddress(), true);

            const tx = await auctionHouse
                .connect(seller)
                .listItem(ITEM_ID, AMOUNT, UNIT_PRICE, DURATION);

            await expect(tx).to.emit(auctionHouse, "ListingCreated");

            const listing = await auctionHouse.getListing(1);
            expect(listing.seller).to.equal(await seller.getAddress());
            expect(listing.itemId).to.equal(ITEM_ID);
            expect(listing.amount).to.equal(AMOUNT);
            expect(listing.unitPrice).to.equal(UNIT_PRICE);
            expect(listing.active).to.be.true;
        });

        it("Should revert if amount is zero", async function () {
            await paradiseItems
                .connect(seller)
                .setApprovalForAll(await auctionHouse.getAddress(), true);

            await expect(
                auctionHouse.connect(seller).listItem(ITEM_ID, 0, UNIT_PRICE, DURATION)
            ).to.be.revertedWith("Invalid amount");
        });

        it("Should revert if price is zero", async function () {
            await paradiseItems
                .connect(seller)
                .setApprovalForAll(await auctionHouse.getAddress(), true);

            await expect(
                auctionHouse.connect(seller).listItem(ITEM_ID, AMOUNT, 0, DURATION)
            ).to.be.revertedWith("Invalid price");
        });
    });

    describe("Purchase", function () {
        beforeEach(async function () {
            await paradiseItems
                .connect(seller)
                .setApprovalForAll(await auctionHouse.getAddress(), true);
            await auctionHouse.connect(seller).listItem(ITEM_ID, AMOUNT, UNIT_PRICE, DURATION);
        });

        it("Should allow purchase", async function () {
            const purchaseAmount = 50;
            const totalPrice = UNIT_PRICE * BigInt(purchaseAmount);
            const fee = totalPrice / BigInt(20); // 5%

            await expect(
                auctionHouse.connect(buyer).purchase(1, purchaseAmount, { value: totalPrice })
            )
                .to.emit(auctionHouse, "ItemSold")
                .withArgs(1, await buyer.getAddress(), await seller.getAddress(), ITEM_ID, purchaseAmount, totalPrice, fee);

            // Check buyer received items
            expect(await paradiseItems.balanceOf(await buyer.getAddress(), ITEM_ID)).to.equal(
                purchaseAmount
            );

            // Check listing updated
            const listing = await auctionHouse.getListing(1);
            expect(listing.amount).to.equal(AMOUNT - purchaseAmount);
        });

        it("Should revert if buyer is seller", async function () {
            const totalPrice = UNIT_PRICE * BigInt(AMOUNT);
            await expect(
                auctionHouse.connect(seller).purchase(1, AMOUNT, { value: totalPrice })
            ).to.be.revertedWith("Cannot buy own listing");
        });

        it("Should revert if insufficient payment", async function () {
            const totalPrice = UNIT_PRICE * BigInt(AMOUNT);
            await expect(
                auctionHouse.connect(buyer).purchase(1, AMOUNT, { value: totalPrice - BigInt(1) })
            ).to.be.revertedWith("Insufficient payment");
        });
    });

    describe("Cancel Listing", function () {
        beforeEach(async function () {
            await paradiseItems
                .connect(seller)
                .setApprovalForAll(await auctionHouse.getAddress(), true);
            await auctionHouse.connect(seller).listItem(ITEM_ID, AMOUNT, UNIT_PRICE, DURATION);
        });

        it("Should allow seller to cancel", async function () {
            await expect(auctionHouse.connect(seller).cancelListing(1))
                .to.emit(auctionHouse, "ListingCancelled")
                .withArgs(1, await seller.getAddress());

            // Check items returned
            expect(await paradiseItems.balanceOf(await seller.getAddress(), ITEM_ID)).to.equal(
                AMOUNT
            );

            // Check listing inactive
            const listing = await auctionHouse.getListing(1);
            expect(listing.active).to.be.false;
        });

        it("Should revert if not seller", async function () {
            await expect(auctionHouse.connect(buyer).cancelListing(1)).to.be.revertedWith(
                "Not seller"
            );
        });
    });
});
