import { expect } from "chai";
import { ethers } from "hardhat";
import {
  loadFixture, mine
} from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("DonkeyDecay", function () {
  // deployFixture
  async function deployFixture() {
    const ContractFactory = await ethers.getContractFactory("DonkeyDecay");

    const instance = await ContractFactory.deploy();
    await instance.waitForDeployment();
    // signer 
    const signer = (await ethers.getSigners())[0];
    // await instance.safeMint(signer.address, { value: ethers.parseEther("10") });
    return { instance, signer };
  }

  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("DonkeyDecay");

    const instance = await ContractFactory.deploy();
    await instance.waitForDeployment();

    expect(await instance.name()).to.equal("Donkey Decay");
    expect(await instance.symbol()).to.equal("DKDK");
    console.log(`Contract deployed to ${await instance.getAddress()}`);
    // bytecode display
    console.log(`Contract bytecode: ${ContractFactory.bytecode}`);
  });

  it("should set default URI", async function () {
    const { instance, signer } = await loadFixture(deployFixture);
    // verify owner
    expect(await instance.owner()).to.equal(`0xd240bc7905f8D32320937cd9aCC3e69084ec4658`);
  });

  it("should correctly compute the price", async function () {
    const { instance, signer } = await loadFixture(deployFixture);
    expect(await instance.getLastMintBlock()).to.equal(2);

    expect(await instance.getElapsedTime()).to.equal(0);
    expect(await instance.getElapsedPortion()).to.equal(0);
    expect(await instance.currentPrice()).to.equal(ethers.parseEther("1"));

    // mine 24 hours 
    await mine(24 * 60 * 60 / 12);
    expect(await instance.getElapsedTime()).to.equal(24 * 60 * 60 / 12);
    expect(await instance.getElapsedPortion()).to.equal(ethers.toBigInt("1000000000000000000") / BigInt(3));
    expect(await instance.currentPrice()).to.equal(ethers.parseEther("0.1"));
    // mine 24 hours 
    await mine(24 * 60 * 60 / 12);
    expect(await instance.getElapsedTime()).to.equal(48 * 60 * 60 / 12);
    expect(await instance.getElapsedPortion()).to.equal(ethers.toBigInt("1000000000000000000") * BigInt(2) / BigInt(3));
    expect(await instance.currentPrice()).to.equal(ethers.parseEther("0.01"));
    // mine 24 hours 
    await mine(24 * 60 * 60 / 12);
    expect(await instance.getElapsedPortion()).to.equal(ethers.toBigInt("1000000000000000000"));
    expect(await instance.getElapsedTime()).to.equal(72 * 60 * 60 / 12);
    expect(await instance.currentPrice()).to.equal(ethers.parseEther("0.001"));

    await mine(24 * 60 * 60 / 12);
    expect(await instance.getElapsedPortion()).to.equal(ethers.toBigInt("1000000000000000000"));
    expect(await instance.getElapsedTime()).to.equal(96 * 60 * 60 / 12);
    expect(await instance.currentPrice()).to.equal(ethers.parseEther("0.001"));
  });

});
