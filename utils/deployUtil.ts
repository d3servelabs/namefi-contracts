import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Signer } from 'ethers';

export const deployedContracts:any[] = [];

export async function deployByName(
        ethers: HardhatRuntimeEnvironment["ethers"], 
        contractName: string, 
        parameters: any[],
        signer?: Signer
    ): Promise<any> /*deployed address*/ {
    console.log(`Deploying ${contractName} with parameters ${parameters}`);
    const contractFactory = await ethers.getContractFactory(contractName);
    const contract = await contractFactory.connect(signer ? signer : (await ethers.getSigners())[0]).deploy(...parameters);
    await contract.deployed();
    console.log(`${contractName} deployed to: ${contract.address}`);
    let tx = contract.deployTransaction;
    deployedContracts.push(contract);

    console.log(`Contract ${contractName} deployed to ${contract.address}`);
    return { contract, tx };
}