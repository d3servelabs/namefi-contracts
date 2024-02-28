import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { gasReport } from "../utils/gasUtil";

const WAIT_FOR_BLOCK = 6;

task("namefi-set-nfsc-address", "Call NamefiNFT.setServiceCreditContract(NamefiServiceCredit.address)")
    .addParam("nft", "The address to NamefiNFT", "0x0000000000cf80E7Cf8Fa4480907f692177f8e06")
    .addParam("nfsc", "The address to NamefiServiceCredit", "0x0000000000c39A0F674c12A5e63eb8031B550b6f")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const nft = taskArguments.nft;
        const nfsc = taskArguments.nfsc;
        const nftContract = await ethers.getContractAt("NamefiNFT", nft);
        const tx = await nftContract.setServiceCreditContract(nfsc, );
        
        await gasReport(tx, ethers.provider);
        
        const nfscContract = await ethers.getContractAt("NamefiServiceCredit", nft);

        const CHARGER_ROLE = await nfscContract.CHARGER_ROLE();
        const tx2 = await nfscContract.grantRole(CHARGER_ROLE, nft);

        await gasReport(tx2, ethers.provider);
    });


task("namefi-grant-nft-minter", "Call NamefiNFT.grantRole(MINTER_ROLE, minter)")
    .addParam("nft", "The address to NamefiNFT", "0x0000000000cf80E7Cf8Fa4480907f692177f8e06")
    .addParam("minter", "The address for minter", "")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const nft = taskArguments.nft;
        const nftContract = await ethers.getContractAt("NamefiNFT", nft);
        
        if (taskArguments.minter) {
            const MINTER_ROLE = await nftContract.MINTER_ROLE();
            const tx = await nftContract.grantRole(MINTER_ROLE, taskArguments.minter);
            await gasReport(tx, ethers.provider);
        } else {
            console.log("No minter address provided");
        }
    });

task("namefi-grant-nfsc-minter", "Call NamefiServiceCredit.grantRole(MINTER_ROLE, minter)")
    .addParam("nfsc", "The address to NamefiServiceCredit", "0x0000000000c39A0F674c12A5e63eb8031B550b6f")
    .addParam("minter", "The address for minter", "")
    .setAction(async function (taskArguments: TaskArguments, { ethers, run }) {
        const nfsc = taskArguments.nfsc;
        const nfscContract = await ethers.getContractAt("NamefiServiceCredit", nfsc);
        
        if (taskArguments.minter) {
            const MINTER_ROLE = await nfscContract.MINTER_ROLE();
            const tx = await nfscContract.grantRole(MINTER_ROLE, taskArguments.minter);
            await gasReport(tx, ethers.provider);
        } else {
            console.log("No minter address provided");
        }
    });


