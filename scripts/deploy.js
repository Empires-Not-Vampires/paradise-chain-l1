const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Deployment script for Paradise Chain L1 contracts
 * Deploys all contracts in the correct order with proper initialization
 */
async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

    const network = await ethers.provider.getNetwork();
    console.log("Network:", network.name, "Chain ID:", network.chainId);

    const deploymentInfo = {
        network: network.name,
        chainId: network.chainId.toString(),
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: {}
    };

    // 1. Deploy AccessControl (via GameRegistry which extends it)
    console.log("\n=== Deploying Core Contracts ===");
    
    const GameRegistry = await ethers.getContractFactory("GameRegistry");
    const gameRegistry = await GameRegistry.deploy();
    await gameRegistry.waitForDeployment();
    const gameRegistryAddress = await gameRegistry.getAddress();
    console.log("GameRegistry deployed to:", gameRegistryAddress);
    deploymentInfo.contracts.GameRegistry = gameRegistryAddress;

    // 2. Deploy ParadiseItems
    const baseURI = process.env.BASE_URI || "https://api.paradise.cloud/items/";
    const ParadiseItems = await ethers.getContractFactory("ParadiseItems");
    const paradiseItems = await ParadiseItems.deploy(baseURI);
    await paradiseItems.waitForDeployment();
    const paradiseItemsAddress = await paradiseItems.getAddress();
    console.log("ParadiseItems deployed to:", paradiseItemsAddress);
    deploymentInfo.contracts.ParadiseItems = paradiseItemsAddress;

    // Grant GAME_CONTRACT_ROLE to GameRegistry for future contracts
    const GAME_CONTRACT_ROLE = await paradiseItems.GAME_CONTRACT_ROLE();
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, gameRegistryAddress);
    console.log("Granted GAME_CONTRACT_ROLE to GameRegistry");

    // 3. Deploy Treasury
    console.log("\n=== Deploying Economy Contracts ===");
    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy();
    await treasury.waitForDeployment();
    const treasuryAddress = await treasury.getAddress();
    console.log("Treasury deployed to:", treasuryAddress);
    deploymentInfo.contracts.Treasury = treasuryAddress;

    // Grant GAME_CONTRACT_ROLE to Treasury
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, treasuryAddress);
    console.log("Granted GAME_CONTRACT_ROLE to Treasury");

    // 4. Deploy AuctionHouse
    const feeDivisor = process.env.AUCTION_FEE_DIVISOR || "20"; // 5% fee
    const minFee = process.env.AUCTION_MIN_FEE || ethers.parseEther("0.001");
    const maxListings = process.env.AUCTION_MAX_LISTINGS || "10";
    
    const AuctionHouse = await ethers.getContractFactory("AuctionHouse");
    const auctionHouse = await AuctionHouse.deploy(
        paradiseItemsAddress,
        treasuryAddress,
        feeDivisor,
        minFee,
        maxListings
    );
    await auctionHouse.waitForDeployment();
    const auctionHouseAddress = await auctionHouse.getAddress();
    console.log("AuctionHouse deployed to:", auctionHouseAddress);
    deploymentInfo.contracts.AuctionHouse = auctionHouseAddress;

    // Grant GAME_CONTRACT_ROLE to AuctionHouse
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, auctionHouseAddress);
    await treasury.grantRole(GAME_CONTRACT_ROLE, auctionHouseAddress);
    console.log("Granted roles to AuctionHouse");

    // Register AuctionHouse in GameRegistry
    const AUCTION_HOUSE_TYPE = ethers.id("AUCTION_HOUSE");
    await gameRegistry.registerGameContract(auctionHouseAddress, AUCTION_HOUSE_TYPE);
    console.log("Registered AuctionHouse in GameRegistry");

    // 5. Deploy VendorShop
    const VendorShop = await ethers.getContractFactory("VendorShop");
    const vendorShop = await VendorShop.deploy(paradiseItemsAddress, treasuryAddress);
    await vendorShop.waitForDeployment();
    const vendorShopAddress = await vendorShop.getAddress();
    console.log("VendorShop deployed to:", vendorShopAddress);
    deploymentInfo.contracts.VendorShop = vendorShopAddress;

    // Grant GAME_CONTRACT_ROLE to VendorShop
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, vendorShopAddress);
    await treasury.grantRole(GAME_CONTRACT_ROLE, vendorShopAddress);
    console.log("Granted roles to VendorShop");

    // Register VendorShop in GameRegistry
    const VENDOR_SHOP_TYPE = ethers.id("VENDOR_SHOP");
    await gameRegistry.registerGameContract(vendorShopAddress, VENDOR_SHOP_TYPE);
    console.log("Registered VendorShop in GameRegistry");

    // 6. Deploy ResourceCollection
    console.log("\n=== Deploying Gameplay Contracts ===");
    const ResourceCollection = await ethers.getContractFactory("ResourceCollection");
    const resourceCollection = await ResourceCollection.deploy(paradiseItemsAddress);
    await resourceCollection.waitForDeployment();
    const resourceCollectionAddress = await resourceCollection.getAddress();
    console.log("ResourceCollection deployed to:", resourceCollectionAddress);
    deploymentInfo.contracts.ResourceCollection = resourceCollectionAddress;

    // Grant GAME_CONTRACT_ROLE to ResourceCollection
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, resourceCollectionAddress);
    console.log("Granted GAME_CONTRACT_ROLE to ResourceCollection");

    // Register ResourceCollection in GameRegistry
    const RESOURCE_COLLECTION_TYPE = ethers.id("RESOURCE_COLLECTION");
    await gameRegistry.registerGameContract(resourceCollectionAddress, RESOURCE_COLLECTION_TYPE);
    console.log("Registered ResourceCollection in GameRegistry");

    // 7. Deploy CraftingStation
    const CraftingStation = await ethers.getContractFactory("CraftingStation");
    const craftingStation = await CraftingStation.deploy(paradiseItemsAddress);
    await craftingStation.waitForDeployment();
    const craftingStationAddress = await craftingStation.getAddress();
    console.log("CraftingStation deployed to:", craftingStationAddress);
    deploymentInfo.contracts.CraftingStation = craftingStationAddress;

    // Grant GAME_CONTRACT_ROLE to CraftingStation
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, craftingStationAddress);
    console.log("Granted GAME_CONTRACT_ROLE to CraftingStation");

    // Register CraftingStation in GameRegistry
    const CRAFTING_STATION_TYPE = ethers.id("CRAFTING_STATION");
    await gameRegistry.registerGameContract(craftingStationAddress, CRAFTING_STATION_TYPE);
    console.log("Registered CraftingStation in GameRegistry");

    // 8. Deploy QuestManager
    const QuestManager = await ethers.getContractFactory("QuestManager");
    const questManager = await QuestManager.deploy(paradiseItemsAddress, treasuryAddress);
    await questManager.waitForDeployment();
    const questManagerAddress = await questManager.getAddress();
    console.log("QuestManager deployed to:", questManagerAddress);
    deploymentInfo.contracts.QuestManager = questManagerAddress;

    // Grant GAME_CONTRACT_ROLE to QuestManager
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, questManagerAddress);
    await treasury.grantRole(GAME_CONTRACT_ROLE, questManagerAddress);
    console.log("Granted roles to QuestManager");

    // Register QuestManager in GameRegistry
    const QUEST_MANAGER_TYPE = ethers.id("QUEST_MANAGER");
    await gameRegistry.registerGameContract(questManagerAddress, QUEST_MANAGER_TYPE);
    console.log("Registered QuestManager in GameRegistry");

    // 9. Deploy DailyRewards
    const DailyRewards = await ethers.getContractFactory("DailyRewards");
    const dailyRewards = await DailyRewards.deploy(paradiseItemsAddress, treasuryAddress);
    await dailyRewards.waitForDeployment();
    const dailyRewardsAddress = await dailyRewards.getAddress();
    console.log("DailyRewards deployed to:", dailyRewardsAddress);
    deploymentInfo.contracts.DailyRewards = dailyRewardsAddress;

    // Grant GAME_CONTRACT_ROLE to DailyRewards
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, dailyRewardsAddress);
    await treasury.grantRole(GAME_CONTRACT_ROLE, dailyRewardsAddress);
    console.log("Granted roles to DailyRewards");

    // Register DailyRewards in GameRegistry
    const DAILY_REWARDS_TYPE = ethers.id("DAILY_REWARDS");
    await gameRegistry.registerGameContract(dailyRewardsAddress, DAILY_REWARDS_TYPE);
    console.log("Registered DailyRewards in GameRegistry");

    // 10. Deploy BuffRegistry
    console.log("\n=== Deploying Powerup Contracts ===");
    const BuffRegistry = await ethers.getContractFactory("BuffRegistry");
    const buffRegistry = await BuffRegistry.deploy();
    await buffRegistry.waitForDeployment();
    const buffRegistryAddress = await buffRegistry.getAddress();
    console.log("BuffRegistry deployed to:", buffRegistryAddress);
    deploymentInfo.contracts.BuffRegistry = buffRegistryAddress;

    // 11. Deploy PowerupManager
    const PowerupManager = await ethers.getContractFactory("PowerupManager");
    const powerupManager = await PowerupManager.deploy(paradiseItemsAddress, buffRegistryAddress);
    await powerupManager.waitForDeployment();
    const powerupManagerAddress = await powerupManager.getAddress();
    console.log("PowerupManager deployed to:", powerupManagerAddress);
    deploymentInfo.contracts.PowerupManager = powerupManagerAddress;

    // Grant GAME_CONTRACT_ROLE to PowerupManager
    await paradiseItems.grantRole(GAME_CONTRACT_ROLE, powerupManagerAddress);
    console.log("Granted GAME_CONTRACT_ROLE to PowerupManager");

    // Register PowerupManager in GameRegistry
    const POWERUP_MANAGER_TYPE = ethers.id("POWERUP_MANAGER");
    await gameRegistry.registerGameContract(powerupManagerAddress, POWERUP_MANAGER_TYPE);
    console.log("Registered PowerupManager in GameRegistry");

    // Save deployment info
    const deploymentDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentDir)) {
        fs.mkdirSync(deploymentDir, { recursive: true });
    }

    const deploymentFile = path.join(deploymentDir, `${network.name}-${Date.now()}.json`);
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
    console.log("\n=== Deployment Complete ===");
    console.log("Deployment info saved to:", deploymentFile);
    console.log("\nContract Addresses:");
    Object.entries(deploymentInfo.contracts).forEach(([name, address]) => {
        console.log(`  ${name}: ${address}`);
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
