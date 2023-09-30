import { expect } from "chai";
import { ethers } from "hardhat";
import { deployByName } from "../utils/deployUtil";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { exec } from "child_process";

describe("D3BridgeServiceCredit", function () {
  const DEFAULT_ADMIN_ROLE = ethers.utils.hexZeroPad("0x00", 32);
  const MINTER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("MINTER")
  );
  // deployFixture
  async function deployFixture() {
    const contractDeploySigner = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    ).connect(ethers.provider);
    const signers = await ethers.getSigners();
    const minter = signers[1];
    const defaultAdmin = signers[2];
    const alice =signers[3];
    const bob = signers[4];
    const charlie = signers[5];

    const { contract: logic } = await deployByName(
      ethers, 
      "D3BridgeNFT", 
      [], 
      contractDeploySigner
    );

    const { contract: proxyAdmin } = await deployByName(
      ethers, 
      "ProxyAdmin", 
      [], 
      contractDeploySigner
    );

    const { contract: proxy } = await deployByName(
      ethers, 
      "TransparentUpgradeableProxy",
      [
        logic.address,
        proxyAdmin.address,
        []
      ], 
      contractDeploySigner
    );
    const instance = await ethers.getContractAt(
      "D3BridgeNFT",
      proxy.address);

    await instance.connect(contractDeploySigner).initialize();
    
    await instance.connect(contractDeploySigner).grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin.address);
    expect(await instance.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin.address)).to.be.true;
    expect(await instance.hasRole(MINTER_ROLE, defaultAdmin.address)).to.be.false;

    expect(await instance.hasRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address)).to.be.true;
    expect(await instance.hasRole(MINTER_ROLE, contractDeploySigner.address)).to.be.true;
    await instance.connect(contractDeploySigner).renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address);
    await instance.connect(contractDeploySigner).renounceRole(MINTER_ROLE, contractDeploySigner.address);
    expect(await instance.hasRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address)).to.be.false;
    expect(await instance.hasRole(MINTER_ROLE, contractDeploySigner.address)).to.be.false;

    await instance.connect(defaultAdmin).grantRole(MINTER_ROLE, minter.address);
    expect(await instance.hasRole(MINTER_ROLE, minter.address)).to.be.true;
    expect(await instance.hasRole(DEFAULT_ADMIN_ROLE, minter.address)).to.be.false;

    return { instance, contractDeploySigner, signers, 
      minter, defaultAdmin,
      alice, bob, charlie };
  }

  it("SHOULD PASS", async function () {
    
  });
});
