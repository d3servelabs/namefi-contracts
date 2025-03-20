const normalizedDomainNamesTestCases = [
  {
    name: 'example.com',
    valid: true,
  },
  {
    name: 'sub.example.com',
    valid: true,
  },
  {
    name: 'sub-domain.example.com',
    valid: true,
  },
  // domain name with 63 characters in each label
  {
    name: `${['a'.repeat(62), 'b'.repeat(62), 'c'.repeat(62), 'd'.repeat(62)].join('.')}.co`,
    // 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc.dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd.co'
    // length = 254 (without trailing dot)
    // length = 255 (with trailing dot)
    valid: true,
  },
];
const nonNormalizedDomainNamesTestCases = [
  {
    name: 'example.com.',
    valid: false,
    reason: 'Domain name contains a trailing dot',
  },
  {
    name: '_dmarc.example.com',
    valid: false,
    reason: 'Domain name contains an underscore',
  },
  {
    name: 'ab._dmarc.example.com',
    valid: false,
    reason: 'Domain name contains an underscore but it is not the first label',
  },
  {
    name: 'Example.com',
    valid: false,
    reason: 'Domain name contains uppercase letters',
  },
  {
    name: 'Example.com.',
    valid: false,
    reason: 'Domain name contains a trailing dot',
  },
  {
    name: 'example.com/path',
    valid: false,
    reason: 'Domain name contains a path',
  },
  {
    name: 'example.com:8080',
    valid: false,
    reason: 'Domain name contains a port',
  },
  {
    name: '宏',
    valid: false,
    reason: 'Domain name contains non-ASCII characters',
  },
  // domain name with label longer than 63 characters
  {
    name: `${'a'.repeat(64)}.com`,
    valid: false,
    reason: 'Domain name contains a label longer than 63 characters',
  }
];


import { expect } from "chai";
import { ethers } from "hardhat";
import { deployByName } from "../utils/deployUtil";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";

describe("NamefiNFT isNormalizedName function", function () {
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

    return { instance, contractDeploySigner, signers, 
      minter, defaultAdmin,
      alice, bob, charlie };
  }
  for (const testCase of normalizedDomainNamesTestCases) {
    it(`should return true for normalized domain name: ${testCase.name}`, async function () {
      const { instance } = await loadFixture(deployFixture);
      expect(await instance.isNormalizedName(testCase.name)).to.be.true;
    });
  }
  for (const testCase of nonNormalizedDomainNamesTestCases) {
    it(`should return false for non-normalized domain name: ${testCase.name}`, async function () {
      const { instance } = await loadFixture(deployFixture);
      expect(await instance.isNormalizedName(testCase.name), testCase.reason).to.be.false;
    });
  }
});

