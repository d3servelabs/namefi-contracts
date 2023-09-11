import { expect } from "chai";
import { ethers } from "hardhat";
import { deployByName } from "../utils/deployUtil";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("D3BridgeNFT", function () {
  // deployFixture
  async function deployFixture() {
    const deterministicTestSigner = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    ).connect(ethers.provider);
    const { contract: instance } = await deployByName(ethers, "D3BridgeNFT", [], deterministicTestSigner);
    const signers = await ethers.getSigners();
    expect(await instance.owner()).to.equal(deterministicTestSigner.address);
    return { instance, deterministicTestSigner, signers };
  }

  it("Test contract", async function () {
    const { instance, signers, deterministicTestSigner } = await loadFixture(deployFixture);
    const contractOwner = deterministicTestSigner;
    const alice = signers[1];
    const bob = signers[2];
    const charlie = signers[3];
    const normalizedDomainName = "bob.alice.eth";

    const expirationTime =
      (await ethers.provider.getBlock("latest")).timestamp +
      60 * 60 * 24 * 365 * 10; // 10 days

    // Verify that owner can mint
    await expect(instance.connect(alice).safeMintByName(
      bob.address,
      normalizedDomainName,
      expirationTime))
      .to.be.revertedWith("Ownable: caller is not the owner");

    const tx = await instance.connect(deterministicTestSigner)
      .safeMintByName(
        bob.address,
        normalizedDomainName,
        expirationTime
      );
    const rc = await tx.wait();
    const event = rc.events?.find((e: any) => e.event === "Transfer");
    expect(event).to.not.be.undefined;
    expect(event?.args?.from).to.equal(ethers.constants.AddressZero);
    expect(event?.args?.to).to.equal(bob.address);
    expect(event?.args?.tokenId).to.equal(ethers.utils.id(normalizedDomainName));
    expect(await instance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(bob.address);
    expect(await instance.ownerOf(ethers.utils.id("bob.alice.eth"))).to.equal(bob.address);

    // // Verify that holder can transfer NFT
    await expect(instance.connect(alice).safeTransferFromByName(bob.address, charlie.address, normalizedDomainName))
      .to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
    const tx0 = await instance.connect(bob).safeTransferFromByName(bob.address, charlie.address, normalizedDomainName);
    const rc0 = await tx0.wait();
    const event0 = rc0.events?.find((e: any) => e.event === "Transfer");
    expect(event0).to.not.be.undefined;
    expect(event0?.args?.from).to.equal(bob.address);
    expect(event0?.args?.to).to.equal(charlie.address);
    expect(event0?.args?.tokenId).to.equal(ethers.utils.id(normalizedDomainName));
    expect(await instance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(charlie.address);
    expect(await instance.ownerOf(ethers.utils.id("bob.alice.eth"))).to.equal(charlie.address);

    // // Verify that owner can burn
    await expect(instance.connect(charlie).burnByName(normalizedDomainName))
      .to.be.revertedWith("Ownable: caller is not the owner");
    const tx1 = await instance.burnByName(normalizedDomainName);
    const rc1 = await tx1.wait();
    const event1 = rc1.events?.find((e: any) => e.event === "Transfer");
    expect(event1).to.not.be.undefined;
    expect(event1?.args?.to).to.equal(ethers.constants.AddressZero);
    expect(event1?.args?.from).to.equal(charlie.address);
    expect(event1?.args?.tokenId).to.equal(ethers.utils.id(normalizedDomainName));
    await expect(instance.ownerOf(ethers.utils.id(normalizedDomainName))).to.be.revertedWith("ERC721: invalid token ID");
  });

});
