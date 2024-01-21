import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { nickDeployByName } from "../utils/deployUtil";
import { randomBytes } from "crypto";
import { hexlify } from "ethers/lib/utils";

const WAIT_FOR_BLOCK = 6;

task("namefi-nick-deploy-proxy-admin", "Deploy the ProxyAdmin contract")
    .addOptionalParam("nonce", "The nonce to use for the deployment", "0x00000000000000000000000000000000000000005715a2bbff5b843d84e1daf8")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        let nonce = taskArguments.nonce ? taskArguments.nonce : hexlify(randomBytes(32));
        console.log(`Using nonce ${nonce}`);
        const initOwner = `0x01Bf7f00540988622a32de1089B7DeA09a867188`;
        const { contract: proxyAdmin, tx } = await nickDeployByName(
            ethers,
            "NamefiProxyAdmin",
            [
                initOwner
            ],
            nonce
        );

        await proxyAdmin.deployed();

        for (let i = 0; i < WAIT_FOR_BLOCK; i++) {
            console.log(`Block ${i}...`);
            await tx.wait(i);
        }

        console.log(`Done waiting for the confirmation for contract proxyAdmin at ${proxyAdmin.address}`);
        await run("verify:verify", {
            address: proxyAdmin.address,
            constructorArguments: [
                initOwner
            ],
        }).catch(e => console.log(`Failure ${e} when verifying proxyAdmin at ${proxyAdmin.address}`));
        console.log(`Done verifying proxyAdmin at ${proxyAdmin.address}`);
    });