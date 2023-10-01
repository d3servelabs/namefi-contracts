import { expect } from "chai";
import { ethers } from "hardhat";
import { deployByName } from "../utils/deployUtil";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";

describe("D3BridgeServiceCredit", function () {
  const DEFAULT_ADMIN_ROLE = ethers.utils.hexZeroPad("0x00", 32);
  const MINTER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("MINTER")
  );
  console.log(`MINTER_ROLE = `, MINTER_ROLE);
  const PAUSER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("PAUSER")
  );
  console.log(`PAUSER_ROLE = `, PAUSER_ROLE);
  const CHARGER_ROLE = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("CHARGER")
  );
  console.log(`CHARGER_ROLE = `, CHARGER_ROLE);


  // deployFixture
  async function deployFixture() {
    const contractDeploySigner = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    ).connect(ethers.provider);
    const signers = await ethers.getSigners();
    const scDefaultAdmin = signers[1];
    const scMinter = signers[2];
    const scPauser = signers[3];
    const scCharger = signers[4];
    const nftDefaultAdmin = signers[5];
    const nftMinter = signers[6];
    const alice =signers[7];
    const bob = signers[8];
    const charlie = signers[9];
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
    await nftInstance.connect(contractDeploySigner).grantRole(DEFAULT_ADMIN_ROLE, nftDefaultAdmin.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(MINTER_ROLE, contractDeploySigner.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(PAUSER_ROLE, contractDeploySigner.address);
  
    const { instance: scInstance } = await creatUpgradableContract("D3BridgeServiceCredit", proxyAdmin);
    await scInstance.connect(contractDeploySigner).grantRole(MINTER_ROLE, scMinter.address);
    await scInstance.connect(contractDeploySigner).grantRole(DEFAULT_ADMIN_ROLE, scDefaultAdmin.address);
    expect(await scInstance.hasRole(DEFAULT_ADMIN_ROLE, scDefaultAdmin.address)).to.be.true;
    await scInstance.connect(contractDeploySigner).renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address);
    await scInstance.connect(contractDeploySigner).renounceRole(MINTER_ROLE, contractDeploySigner.address);
    expect(await scInstance.hasRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address)).to.be.false;
    await scInstance.connect(scDefaultAdmin).grantRole(PAUSER_ROLE, scPauser.address);

    // Output the following account's address
    console.log("contractDeploySigner ", contractDeploySigner.address);
    console.log("nftInstance ", nftInstance.address);
    console.log("scInstance ", scInstance.address);
    console.log("scDefaultAdmin ", scDefaultAdmin.address);
    console.log("scMinter ", scMinter.address);
    console.log("scPauser ", scPauser.address);
    console.log("nftDefaultAdmin ", nftDefaultAdmin.address);
    console.log("nftMinter ", nftMinter.address);
    
    console.log("alice ", alice.address);
    console.log("bob ", bob.address);
    console.log("charlie ", charlie.address);


    return { nftInstance, scInstance, 
      scMinter, scPauser, scDefaultAdmin,
      nftDefaultAdmin, nftMinter,
      alice, bob, charlie };

  }

  it("should be able to payAndSafeMintByName", async function () {
    const { nftInstance, scInstance, 
        scDefaultAdmin, scMinter, scPauser,
        nftDefaultAdmin, nftMinter, 
        alice, bob, charlie 
      } = await loadFixture(deployFixture);    
        await nftInstance.connect(nftDefaultAdmin).grantRole(MINTER_ROLE, scInstance.address);
        await scInstance.connect(scMinter).mint(alice.address, ethers.utils.parseUnits("100", 18));
        const normalizedDomainName = "bob.alice.eth";

        const expirationTime =
          (await ethers.provider.getBlock("latest")).timestamp +
          60 * 60 * 24 * 365 * 10; // 10 days
    
        expect(await scInstance.connect(scMinter).balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 18));

        const tx = await scInstance.connect(alice)
            .payAndSafeMintByName(
            nftInstance.address,
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


  it("should be able to be charged", async function () {
    const { nftInstance, scInstance, 
      scDefaultAdmin, scMinter, scPauser,
      nftDefaultAdmin, nftMinter, 
      alice, bob, charlie 
    } = await loadFixture(deployFixture);   
        
        await scInstance.connect(scDefaultAdmin).grantRole(MINTER_ROLE, scMinter.address);
        await scInstance.connect(scMinter).mint(alice.address, ethers.utils.parseUnits("100", 18));
        await scInstance.connect(scDefaultAdmin).revokeRole(MINTER_ROLE, scMinter.address);

        const normalizedDomainName = "bob.alice.eth";

        const expirationTime =
          (await ethers.provider.getBlock("latest")).timestamp +
          60 * 60 * 24 * 365 * 10; // 10 days
    
        expect(await scInstance.connect(scMinter).balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 18));
        await scInstance.connect(scDefaultAdmin).grantRole(CHARGER_ROLE, nftInstance.address);
        await nftInstance.connect(nftDefaultAdmin).grantRole(MINTER_ROLE, nftMinter.address);
        await nftInstance.connect(nftDefaultAdmin).setServiceCreditContract(scInstance.address);
        const tx = await nftInstance.connect(nftMinter)
          .safeMintByNameWithCharge(
            bob.address,
            normalizedDomainName,
            expirationTime,
            alice.address, // chargee
            []
          );
        // const rc = await tx.wait();
        // const event = rc.events?.find((e: any) => e.event === "Transfer");
        // expect(event).to.not.be.undefined;
        // expect(event?.args?.to).to.equal(ethers.constants.AddressZero);
        // expect(event?.args?.from).to.equal(alice.address);
        // expect(await nftInstance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(bob.address);
        // expect(await nftInstance.ownerOf(ethers.utils.id("bob.alice.eth"))).to.equal(bob.address);
        // expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("80", 18));
  });
});
