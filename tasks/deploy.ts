import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { deployByName } from "../utils/deployUtil";

const WAIT_FOR_BLOCK = 3;
task("dkdk-deploy", "Deploy")
    .addParam("contractName", "Contract name")
    .addParam("salt", "Salt")
    .addParam("create2Factory", "The create2 factory address")

    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {

        const { contractName, salt, create2Factory } = taskArguments;
        const signers = await ethers.getSigners();
        const signer = signers[0];
        const contractFactory = await ethers.getContractFactory(contractName);

        await signer.sendTransaction({ 
            to: create2Factory.address, 
            data: contractFactory.bytecode,
        });

        for (let i = 0; i < WAIT_FOR_BLOCK; i++) {
            console.log(`Block ${i}...`);
            await tx.wait(i);
        }

        console.log(`Done waiting for the confirmation for contract ${contractName} at ${logic.address}`);
        await run("verify:verify", {
            address: logic.address,
        }).catch(e => console.log(`Failure ${e} when verifying ${contractName} at ${logic.address}`));
        console.log(`Done verifying ${contractName} at ${logic.address}`);
    });
