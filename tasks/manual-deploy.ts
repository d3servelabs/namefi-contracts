import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

const NICK_DEPLOYER = "0x4e59b44847b379578588920ca78fbf26c0b4956c";

task("namefi-manual-deploy", "Generate manual deployment instructions for any wallet")
    .addParam("contract", "Contract name (NamefiNFT or NamefiServiceCredit)")
    .addParam("nonce", "The nonce to use for deployment")
    .setAction(async ({ contract, nonce }: TaskArguments, { ethers }) => {
        // Validate contract
        if (!["NamefiNFT", "NamefiServiceCredit"].includes(contract)) {
            throw new Error(`Invalid contract: ${contract}`);
        }

        // Get contract bytecode
        const factory = await ethers.getContractFactory(contract);
        const initCode = factory.bytecode;
        const initCodeHash = ethers.utils.keccak256(initCode);
        
        // Create deployment data
        const deploymentData = "0x" + nonce.substring(2) + initCode.substring(2);
        
        // Calculate expected address
        const expectedAddress = ethers.utils.getCreate2Address(NICK_DEPLOYER, nonce, initCodeHash);
        
        console.log(`Manual Deployment Instructions for ${contract}`);
        console.log(`Bytecode: ${initCode}`);
        console.log(`${"=".repeat(50)}`);
        console.log(`To:       ${NICK_DEPLOYER}`);
        console.log(`Value:    0 ETH`);
        console.log(`Data:     ${deploymentData}`);
        console.log(`Expected: ${expectedAddress}`);
        console.log(`${"=".repeat(50)}`);
        console.log(`Copy the data above into your wallet's custom transaction field`);
    });