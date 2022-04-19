const { ethers } = require("hardhat");

async function main() {
    const ZedxionNFT = await ethers.getContractFactory("ZedxionNFT");

    const zedxionNFT = await ZedxionNFT.deploy();
    await zedxionNFT.deployed();

    console.log('[Contract deployed to address:]', zedxionNFT.address);
}

main().then(() => process.exit(0))
    .catch(err => {
        console.log('[deploy err]', err);
        process.exit(1);
    })