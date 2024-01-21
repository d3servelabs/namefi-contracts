import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Signer, Wallet, getDefaultProvider } from 'ethers';
import { Hexable, hexlify } from 'ethers/lib/utils';

export const deployedContracts:any[] = [];

export async function deployByName(
        ethers: HardhatRuntimeEnvironment["ethers"], 
        contractName: string, 
        parameters: any[],
        signer?: Signer
    ): Promise<any> /*deployed address*/ {
    console.log(`Deploying ${contractName} with parameters ${parameters}`);
    const contractFactory = await ethers.getContractFactory(contractName);
    const contract = await contractFactory
        .connect(signer ? signer : (await ethers.getSigners())[0])
        .deploy(...parameters);
    await contract.deployed();
    console.log(`${contractName} deployed to: ${contract.address}`);
    let tx = contract.deployTransaction;
    deployedContracts.push(contract);

    console.log(`Contract ${contractName} deployed to ${contract.address}`);
    return { contract, tx };
}

export async function nickDeployByName(
    ethers: HardhatRuntimeEnvironment["ethers"], 
    contractName: string, 
    parameters: any[],
    nonce: string,
): Promise<any> /*deployed address*/ {
    // https://github.com/Zoltu/deterministic-deployment-proxy
    // https://etherscan.io/tx/0x8ee59123fee2379c81c6fed5fa4310d24b0e40027b3bb04684bde87f0e3caaf1
    const NICK_DETERM_DEPLOYER = `0x4e59b44847b379578588920ca78fbf26c0b4956c`;

    console.log(`Deploying ${contractName} with parameters ${parameters}`);
    const contractFactory = await ethers.getContractFactory(contractName);
    let txDeployOriginal = await contractFactory.getDeployTransaction(...parameters);
    if (!txDeployOriginal.data) {
        throw new Error(`No data in txDeployOriginal`);
    }
    let initCode = hexlify(txDeployOriginal.data);
    let nickData = // concat the salt with the contract deployment bytecode
        "0x" +
        nonce.substring(2) +
        initCode.substring(2);

    let wallet = Wallet
        .fromMnemonic(process.env.MNEMONIC as string)
        .connect(ethers.provider);
    console.log(`Wallet address: ${wallet.address}`);
    // Compose a raw transaction to send to the deployer

    // get gasPrice
    let gasPrice = await ethers.provider.getGasPrice();
    console.log(`Gas price: ${gasPrice.toString()}`);
    let gasLimit = await ethers.provider.estimateGas({
        to: NICK_DETERM_DEPLOYER,
        data: nickData,
    });
    console.log(`Gas limit: ${gasLimit.toString()}`);

    let rawTx = {
        to: NICK_DETERM_DEPLOYER, // The address of the recipient
        value: ethers.utils.parseEther("0"), // The amount of ether to send
        data: nickData, // The data to be sent
        gasPrice: gasPrice.mul(10),
        gasLimit
    };
    let initCodeHash = ethers.utils.keccak256(initCode);
    console.log(`initCodeHash: ${initCodeHash}`);
    let contractAddress = ethers.utils.getCreate2Address(
        NICK_DETERM_DEPLOYER,
        nonce,
        initCodeHash
    );
    console.log(`Sending TX, expeding new contract address: ${contractAddress}`);
    let tx = await wallet.sendTransaction(rawTx);
    console.log(`TX sent: ${tx.hash}`);
    let receipt = await tx.wait();
    // get code at address
    let code = await ethers.provider.getCode(contractAddress);
    if (code === "0x") {
        throw new Error(`No code at address ${contractAddress}`);
    } else {
        console.log(`Code at address ${contractAddress} is ${code}`);
        // TODO verify the code is the same as the bytecode without the constructor
    }

    let contract = await contractFactory.attach(contractAddress);
    return { contract, tx };
}