require("hardhat-deploy")
require("hardhat-deploy-ethers")

const { networkConfig } = require("../helper-hardhat-config")

const private_key = network.config.accounts[0]
const wallet = new ethers.Wallet(private_key, ethers.provider)
const CID = require("cids")

async function main() {
    console.log("Wallet Ethereum Address:", wallet.address)
    const chainId = network.config.chainId
    // const tokensToBeMinted = networkConfig[chainId]["tokensToBeMinted"]

    // //deploy Simplecoin
    const Cretodus = await ethers.getContractFactory("Cretodus", wallet)
    console.log("Deploying Cretodus...")
    const cretodus = await Cretodus.deploy()
    await cretodus.deployed()
    console.log("Cretodus deployed to:", cretodus.address)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
