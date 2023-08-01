import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { deployByName } from "../utils/deployUtil";

const WAIT_FOR_BLOCK = 3;

task("d3bridge-nft-deploy", "Deploy")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const contractName = "D3BridgeNFT";
        const signers = await ethers.getSigners();
        const signer = signers[0];
        const {contract, tx} = await deployByName(
            ethers,
            contractName,
            [],
            signer);
        
        console.log(`Contract ${contractName} deployed to ${contract.address}`);

        // wait for a few blocks
        const WAIT_FOR_BLOCK = 6;
        console.log(`Waiting for ${WAIT_FOR_BLOCK} blocks...`);
        for (let i = 0; i < WAIT_FOR_BLOCK; i++) {
            console.log(`${i} time: ${new Date().toLocaleTimeString()}`);
            await tx.wait(i);
        }
        console.log(`Wait done for ${WAIT_FOR_BLOCK} blocks.`);
        // verify on etherscan
        await run("verify:verify", {
            address: contract.address
        });
        console.log(`Contract ${contractName} verified at ${contract.address}.`);
    });
