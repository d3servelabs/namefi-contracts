import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { deployByName } from "../utils/deployUtil";

const WAIT_FOR_BLOCK = 6;

task("d3bridge-logic-deploy", "Deploy the logic contract")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const contractName = "D3BridgeNFT";
        const signers = await ethers.getSigners();
        const signer = signers[0];
        const { contract, tx } = await deployByName(
            ethers,
            contractName,
            [],
            signer);

        console.log(`Contract ${contractName} deployed to ${contract.address}`);

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

task("d3bridge-proxy-deploy", "Deploy Transparent Upgradeable Proxy")
    .addParam("logicContractName")
    .addParam("logicAddress")
    .addParam("adminAddress")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const signers = await ethers.getSigners();
        const signer = signers[0];
        const { contract: proxy } = await deployByName(
            ethers,
            "TransparentUpgradeableProxy",
            [
                taskArguments.logicAddress,
                taskArguments.adminAddress,
                // Initialization data
                [],
            ], 
            signer
        );

        await proxy.deployed();
        let tx2 = proxy.deployTransaction;
        // attach contract to UnsafelyDestroyable
        const proxyAsLogic = await ethers.getContractAt(
            taskArguments.logicContractName,
            proxy.address); 
        await proxyAsLogic.initialize();
    
        for (let i = 0; i < WAIT_FOR_BLOCK; i++) {
            console.log(`Block ${i}...`);
            await tx2.wait(i);
        }

        console.log(`Done waiting for the confirmation for contract TransparentUpgradeableProxy at ${proxy.address}`);
        await run("verify:verify", {
            address: proxy.address,
            constructorArguments: [
                taskArguments.logicAddress,
                taskArguments.adminAddress,
                // Initialization data
                [],
            ],
        }).catch(e => console.log(`Failure ${e} when verifying TransparentUpgradeableProxy at ${proxy.address}`));
        console.log(`Done verifying TransparentUpgradeableProxy at ${proxy.address}`);

    });

task("d3bridge-admin-deploy", "Deploy the ProxyAdmin contract")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const signers = await ethers.getSigners();
        const signer = signers[0];
        const { contract: proxyAdmin } = await deployByName(
            ethers,
            "ProxyAdmin",
            [],
            signer
        );

        await proxyAdmin.deployed();
        let tx3 = proxyAdmin.deployTransaction;

        for (let i = 0; i < WAIT_FOR_BLOCK; i++) {
            console.log(`Block ${i}...`);
            await tx3.wait(i);
        }

        console.log(`Done waiting for the confirmation for contract proxyAdmin at ${proxyAdmin.address}`);
        await run("verify:verify", {
            address: proxyAdmin.address,
        }).catch(e => console.log(`Failure ${e} when verifying proxyAdmin at ${proxyAdmin.address}`));
        console.log(`Done verifying proxyAdmin at ${proxyAdmin.address}`);
    });
