import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { deployByName } from "../utils/deployUtil";

const WAIT_FOR_BLOCK = 6;
task("print-signers", "Printer signers")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        // get signer from hardhat 
        
        const node = ethers.utils.HDNode.fromMnemonic(process.env.MNEMONIC as string);
        
        for (let i = 0; i < 10; i++) {
            const path = `m/44'/60'/0'/0/${i}`;
            const wallet = node.derivePath(path);
            console.log(`${path}: ${wallet.address}`);
        }
    });

task("namefi-logic-deploy", "Deploy the logic contract")
    .addParam("logicContractName")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const signers = await ethers.getSigners();
        const signer = signers[0];
        const { contract, tx } = await deployByName(
            ethers,
            taskArguments.logicContractName,
            [],
            signer);

        console.log(`Contract ${taskArguments.logicContractName} deployed to ${contract.address}`);

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
        console.log(`Contract ${taskArguments.logicContractName} verified at ${contract.address}.`);
    });

task("namefi-proxy-deploy", "Deploy Transparent Upgradeable Proxy")
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
        await (proxyAsLogic as any).initialize();
    
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

task("namefi-admin-deploy", "Deploy the ProxyAdmin contract")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const signers = await ethers.getSigners();
        const signer = signers[0];
        const { contract: proxyAdmin } = await deployByName(
            ethers,
            "NamefiProxyAdmin",
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

task("namefi-upgrade", "Deploy the ProxyAdmin contract")
    .addParam("proxyAddress")
    .addParam("logicAddress")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const signers = await ethers.getSigners();
        const signer = signers[0];
        const slotIndex = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"; // AdminAddress https://eips.ethereum.org/EIPS/eip-1967
        console.log(`Proxy address is ${taskArguments.proxyAddress}`);
        // get the admin address from the proxy
        const proxy = await ethers.getContractAt(
            "TransparentUpgradeableProxy",
            taskArguments.proxyAddress);
        // get admin address from storage at slot from ethers
        const adminAddressBytes32 = await ethers.provider.getStorageAt(
            taskArguments.proxyAddress,
            slotIndex);
        // get last 20 bytes of the address
        const adminAddress = ethers.utils.getAddress("0x" + adminAddressBytes32.slice(26));
        
        console.log(`Admin address is ${adminAddress}`);
        const admin = await ethers.getContractAt(
            "ProxyAdmin",
            adminAddress);
        let tx = await admin.upgrade(
            taskArguments.proxyAddress,
            taskArguments.logicAddress
        );
        let rc = await tx.wait();
        console.log(`Upgrade transaction hash is ${tx.hash}`);
        console.log(`Done waiting for the confirmation for contract upgrade at ${taskArguments.proxyAddress}`);


    });
