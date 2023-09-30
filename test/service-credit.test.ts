import { expect } from "chai";
import { ethers } from "hardhat";
import { deployByName } from "../utils/deployUtil";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";

describe("D3BridgeServiceCredit", function () {
  const DEFAULT_ADMIN_ROLE = ethers.utils.hexZeroPad("0x00", 32);
  const MINTER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("MINTER")
  );
  const PAUSER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("PAUSER")
  );
  // deployFixture
  async function deployFixture() {
    const contractDeploySigner = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    ).connect(ethers.provider);
    const signers = await ethers.getSigners();
    const minter = signers[1];
    const pauser = signers[2];
    const defaultAdmin = signers[3];
    const alice =signers[11];
    const bob = signers[12];
    const charlie = signers[13];
    async function creatUpgradableContract(contractName: string, proxyAdmin: any) {
        const { contract: logic } = await deployByName(
            ethers,
            contractName,
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
            contractName,
            proxy.address);
    
        await instance.connect(contractDeploySigner).initialize();
        return {instance, proxy, logic};
    };
    
    const { contract: proxyAdmin } = await deployByName(
        ethers, 
        "ProxyAdmin", 
        [], 
        contractDeploySigner
      );
    const { instance: nftInstance, logic: nftLogic } = await creatUpgradableContract("D3BridgeNFT", proxyAdmin);
    await nftInstance.connect(contractDeploySigner).grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(MINTER_ROLE, contractDeploySigner.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(PAUSER_ROLE, contractDeploySigner.address);
  
    const { instance: scInstance } = await creatUpgradableContract("D3BridgeServiceCredit", proxyAdmin);
    await scInstance.connect(contractDeploySigner).grantRole(MINTER_ROLE, minter.address);
    await scInstance.connect(contractDeploySigner).grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin.address);
    expect(await scInstance.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin.address)).to.be.true;
    await scInstance.connect(contractDeploySigner).renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address);
    await scInstance.connect(contractDeploySigner).renounceRole(MINTER_ROLE, contractDeploySigner.address);
    expect(await scInstance.hasRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address)).to.be.false;
    await scInstance.connect(defaultAdmin).grantRole(PAUSER_ROLE, pauser.address);
    expect(await scInstance.connect(defaultAdmin).setD3BridgeNFTAddress(nftInstance.address))
        .to.be.revertedWith(/^AccessControl: account.*missing role.*/);

    await nftInstance.connect(defaultAdmin).grantRole(MINTER_ROLE, scInstance.address);
    await scInstance.connect(defaultAdmin).setD3BridgeNFTAddress(nftInstance.address);
    return { nftInstance, scInstance, contractDeploySigner, signers, 
      minter, pauser, defaultAdmin,
      alice, bob, charlie };

  }

  it("should be able to payAndSafeMintByName", async function () {
    const { nftInstance, scInstance, contractDeploySigner, 
        minter, pauser, defaultAdmin, 
        alice, bob, charlie } = await loadFixture(deployFixture);
        await scInstance.connect(minter).mint(alice.address, ethers.utils.parseUnits("100", 18));
        const normalizedDomainName = "bob.alice.eth";

        const expirationTime =
          (await ethers.provider.getBlock("latest")).timestamp +
          60 * 60 * 24 * 365 * 10; // 10 days
    
        expect(await scInstance.connect(minter).balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 18));
        const tx = await scInstance.connect(alice)
            .payAndSafeMintByName(
            bob.address,
            normalizedDomainName,
            expirationTime);
        const rc = await tx.wait();
        const event = rc.events?.find((e: any) => e.event === "Transfer");
        expect(event).to.not.be.undefined;
        expect(event?.args?.to).to.equal(ethers.constants.AddressZero);
        expect(event?.args?.from).to.equal(alice.address);
        expect(await nftInstance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(bob.address);
        expect(await nftInstance.ownerOf(ethers.utils.id("bob.alice.eth"))).to.equal(bob.address);
        expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("80", 18));
  });
});
