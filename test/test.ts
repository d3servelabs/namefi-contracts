import { expect } from "chai";
import { ethers } from "hardhat";

describe("DonkeyDecay", function () {
  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("DonkeyDecay");

    const instance = await ContractFactory.deploy();
    await instance.waitForDeployment();

    expect(await instance.name()).to.equal("Donkey Decay");
  });
});
