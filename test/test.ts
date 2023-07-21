import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, mine } from "@nomicfoundation/hardhat-network-helpers";
const DEFAULT_HARDHAT_ETH_BALANCE = ethers.utils.parseEther("10000");
const DESIGNATIED_INTIALIZER = "0xd240bc7905f8D32320937cd9aCC3e69084ec4658";

describe("DonkeyDecay", function () {
  // deployFixture
  async function deployFixture() {
    const ContractFactory = await ethers.getContractFactory("DonkeyDecay");

    const instance = await ContractFactory.deploy();
    await instance.deployed();
    const signers = await ethers.getSigners();
    // signer 
    const signer = signers[0];
    return { instance, signer };
  }

  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("DonkeyDecay");
    const instance = await ContractFactory.deploy();
    await instance.deployed();

    expect(await instance.name()).to.equal("Donkey Decay");
    expect(await instance.symbol()).to.equal("DKDK");
  });

  it("should set default URI", async function () {
    const { instance, signer } = await loadFixture(deployFixture);
    // verify owner
    expect(await instance.owner()).to.equal(DESIGNATIED_INTIALIZER);
  });

  it("should correctly compute the price", async function () {
    const { instance, signer } = await loadFixture(deployFixture);
    expect(await instance.getLastMintBlock()).to.equal(2);

    let currentBlock = await ethers.provider.getBlockNumber();
    expect(await instance.getElapsedTime(currentBlock)).to.equal(0);
    expect(await instance.getElapsedPortion(currentBlock)).to.equal(0);
    expect(await instance.currentPrice()).to.equal(ethers.utils.parseEther("10"));
    // mine 24 hours 
    await mine(24 * 60 * 60 / 12);
    currentBlock = await ethers.provider.getBlockNumber();
    expect(await instance.getElapsedTime(currentBlock)).to.equal(24 * 60 * 60 / 12);
    expect(await instance.getElapsedPortion(currentBlock)).to.equal(ethers.BigNumber.from(BigInt(1000000000000000000) / BigInt(4)));
    expect(await instance.currentPrice()).to.equal(ethers.utils.parseEther("1"));

    // mine 24 hours 
    await mine(24 * 60 * 60 / 12);
    currentBlock = await ethers.provider.getBlockNumber();
    expect(await instance.getElapsedTime(currentBlock)).to.equal(48 * 60 * 60 / 12);
    expect(await instance.getElapsedPortion(currentBlock)).to.equal(ethers.BigNumber.from(BigInt(1000000000000000000) / BigInt(2)));
    expect(await instance.currentPrice()).to.equal(ethers.utils.parseEther("0.1"));
    // mine 24 hours 
    await mine(24 * 60 * 60 / 12);
    currentBlock = await ethers.provider.getBlockNumber();
    expect(await instance.getElapsedTime(currentBlock)).to.equal(72 * 60 * 60 / 12);
    expect(await instance.getElapsedPortion(currentBlock)).to.equal(ethers.BigNumber.from(BigInt(1000000000000000000) * BigInt(3) / BigInt(4)));
    expect(await instance.currentPrice()).to.equal(ethers.utils.parseEther("0.01"));
    // mine 24 hours 
    await mine(24 * 60 * 60 / 12);
    currentBlock = await ethers.provider.getBlockNumber();
    expect(await instance.getElapsedPortion(currentBlock)).to.equal(ethers.BigNumber.from(BigInt(1000000000000000000)));
    expect(await instance.getElapsedTime(currentBlock)).to.equal(96 * 60 * 60 / 12);
    expect(await instance.currentPrice()).to.equal(ethers.utils.parseEther("0.001"));

    await mine(24 * 60 * 60 / 12);
    currentBlock = await ethers.provider.getBlockNumber();
    expect(await instance.getElapsedPortion(currentBlock)).to.equal(ethers.BigNumber.from(BigInt(1000000000000000000)));
    expect(await instance.getElapsedTime(currentBlock)).to.equal(120 * 60 * 60 / 12);
    expect(await instance.currentPrice()).to.equal(ethers.utils.parseEther("0.001"));
  });

});

describe("DonkeyDecay deployed via Create2", function () {
  // deployFixture
  async function deployFixture() {
    const contractFactory = await ethers.getContractFactory("DonkeyDecay");
    const deterministicTestSigner = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    ).connect(ethers.providers.getDefaultProvider());
    const testingCreate2DeployerFactory = await ethers.getContractFactory("TestingCreate2Deployer");
    const testingCreate2Deployer = await testingCreate2DeployerFactory.deploy();
    await testingCreate2Deployer.deployed();
    const salt = ethers.utils.hexZeroPad("0x0", 32);
    let tx = await testingCreate2Deployer.deploy(salt, contractFactory.bytecode);
    let rc = await tx.wait();
    const contractAddress = rc.events?.find((e: any) => e.event === "OnDeploy")?.args?.addr;

    const calculatedCreateAddress = ethers.utils.getCreate2Address(
      testingCreate2Deployer.address,
      salt,
      ethers.utils.keccak256(contractFactory.bytecode)
    );
    const instance = contractFactory.attach(contractAddress);
    expect(contractAddress).to.equal(calculatedCreateAddress);
    return {
      instance,
      contractFactory,
      testingCreate2Deployer,
      deterministicTestSigner,
      salt,
      contractAddress
    };
  }

  it("should succeed", async function () {
    const {
      instance,
      contractFactory,
      testingCreate2Deployer,
      deterministicTestSigner,
      salt,
      contractAddress
    } = await loadFixture(deployFixture);
    const owner = await instance.owner();
    expect(owner).to.equal(DESIGNATIED_INTIALIZER);
  });

  it("should mint via other approach.", async function () {
    const {
      instance,
      contractFactory,
      testingCreate2Deployer,
      deterministicTestSigner,
      salt,
      contractAddress
    } = await loadFixture(deployFixture);
    const signers = await ethers.getSigners();
    let user = signers[1];
    let friend = signers[2];
    expect(await user.getBalance()).to.equal(DEFAULT_HARDHAT_ETH_BALANCE);
    const price = await instance.currentPrice();
    expect(price).to.equal(ethers.utils.parseEther("10"));
    const currentBlock = await ethers.provider.getBlockNumber();
    const priceNextBlock = await instance.getPriceAtBlock(currentBlock + 1);
    let tx = await instance.connect(user).safeMint(
      friend.address,
      { value: ethers.utils.parseEther("10.0") });
    let rc = await tx.wait();
    const gasCost = rc.gasUsed.mul(rc.effectiveGasPrice);
    expect(await instance.balanceOf(friend.address)).to.equal(1);
    expect(await instance.ownerOf(0)).to.equal(friend.address);
    expect(
      gasCost.add(priceNextBlock).add(await user.getBalance())
    ).to.equal(
      DEFAULT_HARDHAT_ETH_BALANCE
    )
  });
});

describe("Arugmentable DonkeyDecay", function () {
  // deployFixture
  async function deployFixture() {
    const ContractFactory = await ethers.getContractFactory("ADonkeyDecay");
    const deterministicTestSigner = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    ).connect(ethers.provider);

    expect(await deterministicTestSigner.getBalance())
      .to.greaterThan(ethers.utils.parseEther("9998"));

    const instance = await ContractFactory.deploy(
      deterministicTestSigner.address,
      "Donkey Decay",
      "DKDK",
      "https://dkdk.club/metadata/",
    );

    await instance.deployed();

    return { instance, deterministicTestSigner };
  }

  it("should succeed", async function () {
    const {
      instance,
      deterministicTestSigner,
    } = await loadFixture(deployFixture);
    const owner = await instance.owner();
    expect(owner).to.equal(deterministicTestSigner.address);
  });

  it("owner and ONLY owner should be able to setURI and treasury", async function () {
    const {
      instance,
      deterministicTestSigner,
    } = await loadFixture(deployFixture);
    const owner = await instance.owner();
    expect(owner).to.equal(deterministicTestSigner.address);
    const signers = await ethers.getSigners();
    let user = signers[1];

    await instance.connect(deterministicTestSigner).safeMint(
      deterministicTestSigner.address,
      {
        value: ethers.utils.parseEther("10.0")
      });
    expect(await instance.balanceOf(deterministicTestSigner.address)).to.equal(1);
    expect(await instance.ownerOf(0)).to.equal(deterministicTestSigner.address);
    expect(await instance.tokenURI(0)).to.equal("https://dkdk.club/metadata/0");
    await instance.connect(deterministicTestSigner).setBaseURI("https://example.com/");
    expect(await instance.tokenURI(0)).to.equal("https://example.com/0");

    expect(await instance.getTreasury()).to.equal(deterministicTestSigner.address);
    await instance.setTreasury(user.address);
    expect(await instance.getTreasury()).to.equal(user.address);

    const someGuy = signers[2];
    await expect(
      instance.connect(someGuy).setBaseURI("https://example.com/")
    ).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(
      instance.connect(someGuy).setTreasury(user.address)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("can mint until MAX_SUPPLY", async function () {
    const {
      instance,
      deterministicTestSigner,
    } = await loadFixture(deployFixture);
    const owner = await instance.owner();
    expect(owner).to.equal(deterministicTestSigner.address);
    const signers = await ethers.getSigners();
    // expect(await instance.balanceOf(deterministicTestSigner.address)).to.equal(0);
    // expect(await instance.ownerOf(0)).to.equal(ethers.constants.AddressZero);
    let user = signers[1];
    for (let i = 0; i < 1000; i++) {
      await mine(128 * 60 * 60 / 12);
      await instance.connect(user).safeMint(
        deterministicTestSigner.address,
        {
          value: ethers.utils.parseEther("0.001")
        });
    }

    expect(await instance.balanceOf(deterministicTestSigner.address)).to.equal(1000);
    expect(await instance.ownerOf(999)).to.equal(deterministicTestSigner.address);
    expect(await instance.tokenURI(999)).to.equal("https://dkdk.club/metadata/999");
    await expect(
      instance.connect(user).safeMint(
        deterministicTestSigner.address,
        {
          value: ethers.utils.parseEther("2.0")
        })
    ).to.be.revertedWith("Max supply reached");
  });


  it("Owner can withdraw to treasury", async function () {
    const {
      instance,
      deterministicTestSigner,
    } = await loadFixture(deployFixture);
    const owner = await instance.owner();
    expect(owner).to.equal(deterministicTestSigner.address);
    const signers = await ethers.getSigners();
    let user = signers[1];
    for (let i = 0; i < 1000; i++) {
      await mine(128 * 60 * 60 / 12);
      await instance.connect(user).safeMint(
        deterministicTestSigner.address,
        {
          value: ethers.utils.parseEther("0.001")
        });
    }
    await instance.connect(deterministicTestSigner).setTreasury(user.address);
    expect(await instance.getTreasury()).to.equal(user.address);
    const treasuryBalanceBefore = await user.getBalance();
    await instance.connect(deterministicTestSigner).withdrawProceeds();
    const treasuryBalanceAfter = await user.getBalance();
    expect(treasuryBalanceAfter.sub(treasuryBalanceBefore)).to.equal(ethers.utils.parseEther("1.0"));
    expect(await ethers.provider.getBalance(instance.address)).to.equal(ethers.constants.Zero);
  });

  it("Treasury can withdraw to treasury", async function () {
    const {
      instance,
      deterministicTestSigner,
    } = await loadFixture(deployFixture);
    const owner = await instance.owner();
    expect(owner).to.equal(deterministicTestSigner.address);
    const signers = await ethers.getSigners();
    let user = signers[1];
    for (let i = 0; i < 1000; i++) {
      await mine(128 * 60 * 60 / 12);
      await instance.connect(user).safeMint(
        deterministicTestSigner.address,
        {
          value: ethers.utils.parseEther("0.001")
        });
    }
    await instance.connect(deterministicTestSigner).setTreasury(user.address);
    expect(await instance.getTreasury()).to.equal(user.address);
    const treasuryBalanceBefore = await user.getBalance();
    let tx = await instance.connect(user).withdrawProceeds();
    let rc = await tx.wait();
    const gasCost = rc.gasUsed.mul(rc.effectiveGasPrice);
    const treasuryBalanceAfter = await user.getBalance();
    expect(treasuryBalanceAfter.sub(treasuryBalanceBefore).add(gasCost)).to.equal(ethers.utils.parseEther("1.0"));
    expect(await ethers.provider.getBalance(instance.address)).to.equal(ethers.constants.Zero);
  });

  it("Others can NOT withdraw to treasury", async function () {
    const {
      instance,
      deterministicTestSigner,
    } = await loadFixture(deployFixture);
    const owner = await instance.owner();
    expect(owner).to.equal(deterministicTestSigner.address);
    const signers = await ethers.getSigners();
    let user = signers[1];
    await mine(128 * 60 * 60 / 12);
    await instance.connect(user).safeMint(
      deterministicTestSigner.address,
      {
        value: ethers.utils.parseEther("0.001")
      });
    const someGuy = signers[2];
    // someGuy call withdrawProceeds and fail
    await expect(
      instance.connect(someGuy).withdrawProceeds()
    ).to.be.revertedWith("Not authorized");
  });
});