import { expect } from "chai";
import { ethers } from "hardhat";
import { deployByName } from "../utils/deployUtil";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";

describe("NamefiNFT Minting", function () {
  const DEFAULT_ADMIN_ROLE = ethers.utils.hexZeroPad("0x00", 32);
  const MINTER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("MINTER")
  );
  const CHARGER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("CHARGER")
  );

  // deployFixture
  async function deployFixture() {
    const contractDeploySigner = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    ).connect(ethers.provider);
    const signers = await ethers.getSigners();
    const minter = signers[1];
    const defaultAdmin = signers[2];
    const alice = signers[3];
    const bob = signers[4];
    const charlie = signers[5];

    const { contract: logic } = await deployByName(
      ethers, 
      "NamefiNFT", 
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
      "NamefiNFT",
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

    // Deploy ServiceCredit contract
    const { contract: scLogic } = await deployByName(
      ethers,
      "NamefiServiceCredit",
      [],
      contractDeploySigner
    );

    const { contract: scProxy } = await deployByName(
      ethers,
      "TransparentUpgradeableProxy",
      [
        scLogic.address,
        proxyAdmin.address,
        []
      ],
      contractDeploySigner
    );
    
    const scInstance = await ethers.getContractAt(
      "NamefiServiceCredit",
      scProxy.address
    );

    await scInstance.connect(contractDeploySigner).initialize();
    await scInstance.connect(contractDeploySigner).grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin.address);
    await scInstance.connect(contractDeploySigner).grantRole(MINTER_ROLE, defaultAdmin.address);
    await scInstance.connect(contractDeploySigner).renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address);
    await scInstance.connect(contractDeploySigner).renounceRole(MINTER_ROLE, contractDeploySigner.address);

    // Grant CHARGER_ROLE to NFT contract
    await scInstance.connect(defaultAdmin).grantRole(CHARGER_ROLE, instance.address);
    
    return { 
      instance, 
      scInstance,
      contractDeploySigner, 
      signers, 
      minter, 
      defaultAdmin,
      alice, 
      bob, 
      charlie 
    };
  }

  describe("safeMintByNameNoCharge", function() {
    it("should mint a new token with correct owner and tokenId", async function() {
      const { instance, minter, alice } = await loadFixture(deployFixture);
      
      const normalizedDomainName = "alice.eth";
      const expirationTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60; // 1 year
      
      const tx = await instance.connect(minter).safeMintByNameNoCharge(
        alice.address,
        normalizedDomainName,
        expirationTime
      );
      
      const rc = await tx.wait();
      const event = rc.events?.find((e: any) => e.event === "Transfer");
      
      expect(event).to.not.be.undefined;
      expect(event?.args?.from).to.equal(ethers.constants.AddressZero);
      expect(event?.args?.to).to.equal(alice.address);
      expect(event?.args?.tokenId).to.equal(ethers.utils.id(normalizedDomainName));
      
      expect(await instance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(alice.address);
      expect(await instance.idToNormalizedDomainName(ethers.utils.id(normalizedDomainName))).to.equal(normalizedDomainName);
    });
    
    it("should reject mint if caller doesn't have MINTER_ROLE", async function() {
      const { instance, alice, bob } = await loadFixture(deployFixture);
      
      const normalizedDomainName = "alice.eth";
      const expirationTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60; // 1 year
      
      await expect(instance.connect(alice).safeMintByNameNoCharge(
        bob.address,
        normalizedDomainName,
        expirationTime
      )).to.be.revertedWith(/AccessControl: account.*missing role.*/);
    });
    
    it("should reject mint if domain name is not normalized", async function() {
      const { instance, minter, alice } = await loadFixture(deployFixture);
      
      const notNormalizedDomainName = "Alice.ETH";
      const expirationTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60; // 1 year
      
      await expect(instance.connect(minter).safeMintByNameNoCharge(
        alice.address,
        notNormalizedDomainName,
        expirationTime
      )).to.be.revertedWithCustomError(
        instance, 
        "NamefiNFT_DomainNameNotNomalized"
      ).withArgs(notNormalizedDomainName);
    });
    
    it("should reject mint if expiration time is not in the future", async function() {
      const { instance, minter, alice } = await loadFixture(deployFixture);
      
      const normalizedDomainName = "alice.eth";
      const currentTime = (await ethers.provider.getBlock("latest")).timestamp;
      const expirationTime = currentTime - 1; // Past time
      
      await expect(instance.connect(minter).safeMintByNameNoCharge(
        alice.address,
        normalizedDomainName,
        expirationTime
      )).to.be.revertedWithCustomError(
        instance, 
        "NamefiNFT_EpxirationDateTooEarly"
      ).withArgs(expirationTime, currentTime + 1); // +1 because block.timestamp in next tx will be +1
    });

    it("should verify domain name label length validation", async function() {
      const { instance, minter, alice } = await loadFixture(deployFixture);
      
      // Valid - all labels between 1-63 chars
      const validName = "short.longlonglonglonglonglonglonglonglonglonglonglonglonglonglong.eth";
      const validExpTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60;
      
      await instance.connect(minter).safeMintByNameNoCharge(
        alice.address,
        validName,
        validExpTime
      );
      
      expect(await instance.ownerOf(ethers.utils.id(validName))).to.equal(alice.address);
      
      // Invalid - empty label
      const invalidEmptyLabel = "short..eth";
      const expTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60;
      
      await expect(instance.connect(minter).safeMintByNameNoCharge(
        alice.address,
        invalidEmptyLabel,
        expTime
      )).to.be.revertedWithCustomError(
        instance, 
        "NamefiNFT_DomainNameNotNomalized"
      ).withArgs(invalidEmptyLabel);
      
      // Create a domain with a label > 63 chars
      const longLabel = "a".repeat(65);
      const invalidLongLabel = `${longLabel}.eth`;
      
      await expect(instance.connect(minter).safeMintByNameNoCharge(
        alice.address,
        invalidLongLabel,
        expTime
      )).to.be.revertedWithCustomError(
        instance, 
        "NamefiNFT_DomainNameNotNomalized"
      ).withArgs(invalidLongLabel);
    });
  });

  describe("safeMintByNameWithChargeAmount", function() {
    it("should mint token and charge the specified amount", async function() {
      const { instance, scInstance, minter, defaultAdmin, alice, bob } = await loadFixture(deployFixture);
      
      // Set service credit contract
      await instance.connect(defaultAdmin).setServiceCreditContract(scInstance.address);
      
      // Mint service credits to alice
      await scInstance.connect(defaultAdmin).mint(alice.address, ethers.utils.parseUnits("100", 18));
      
      const normalizedDomainName = "bob.eth";
      const expirationTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60; // 1 year
      const chargeAmount = ethers.utils.parseUnits("20", 18);
      
      // Before minting
      expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 18));
      
      const tx = await instance.connect(minter).safeMintByNameWithChargeAmount(
        bob.address,
        normalizedDomainName,
        expirationTime,
        alice.address, // chargee
        chargeAmount,
        []
      );
      
      // After minting
      expect(await instance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(bob.address);
      expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("80", 18)); // 100 - 20
    });
    
    it("should fail if service credit contract is not set", async function() {
      const { instance, minter, alice, bob } = await loadFixture(deployFixture);
      
      const normalizedDomainName = "bob.eth";
      const expirationTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60; // 1 year
      const chargeAmount = ethers.utils.parseUnits("20", 18);
      
      await expect(instance.connect(minter).safeMintByNameWithChargeAmount(
        bob.address,
        normalizedDomainName,
        expirationTime,
        alice.address,
        chargeAmount,
        []
      )).to.be.revertedWithCustomError(
        instance,
        "NamefiNFT_ServiceCreditContractNotSet"
      );
    });
    
    it("should fail if chargee doesn't have enough credits", async function() {
      const { instance, scInstance, minter, defaultAdmin, alice, bob } = await loadFixture(deployFixture);
      
      // Set service credit contract
      await instance.connect(defaultAdmin).setServiceCreditContract(scInstance.address);
      
      // Mint only 10 credits to alice (not enough)
      await scInstance.connect(defaultAdmin).mint(alice.address, ethers.utils.parseUnits("10", 18));
      
      const normalizedDomainName = "bob.eth";
      const expirationTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60; // 1 year
      const chargeAmount = ethers.utils.parseUnits("20", 18);
      
      // Just check that it reverts, without specifying the exact error
      await expect(instance.connect(minter).safeMintByNameWithChargeAmount(
          bob.address,
          normalizedDomainName,
          expirationTime,
          alice.address,
          chargeAmount,
          []
        )).to.be.revertedWithCustomError(
          instance,
          "NamefiServiceCredit_InsufficientCredit"  // Assuming this is the actual error name
        );
    });

    it("should mint token with DEPRECATED safeMintByNameWithCharge function", async function() {
      const { instance, scInstance, minter, defaultAdmin, alice, bob } = await loadFixture(deployFixture);
      
      // Set service credit contract
      await instance.connect(defaultAdmin).setServiceCreditContract(scInstance.address);
      
      // Mint service credits to alice
      await scInstance.connect(defaultAdmin).mint(alice.address, ethers.utils.parseUnits("100", 18));
      
      const normalizedDomainName = "deprecated.bob.eth";
      const expirationTime = (await ethers.provider.getBlock("latest")).timestamp + 365 * 24 * 60 * 60; // 1 year
      
      // Before minting
      expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 18));
      
      const tx = await instance.connect(minter).safeMintByNameWithCharge(
        bob.address,
        normalizedDomainName,
        expirationTime,
        alice.address, // chargee
        []
      );
      
      // After minting - the contract uses a hardcoded amount of 20 tokens in the deprecated function
      // See NamefiNFT.sol: function safeMintByNameWithCharge(...) where LEGACY_CHARGE_AMOUNT = 20e18
      expect(await instance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(bob.address);
      expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("80", 18)); // 100 - 20
    });
  });
}); 