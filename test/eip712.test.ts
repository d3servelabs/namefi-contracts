import { expect } from "chai";
import { ethers } from "hardhat";
import { deployByName } from "../utils/deployUtil";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";

describe("EIP712", function () {
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
    const alice = signers[3];
    const bob = signers[4];
    const charlie = signers[5];
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
      return { instance, proxy, logic };
    };
    const { instance, logic, proxy } = await creatUpgradableContract(
      "D3BridgeNFT",
      defaultAdmin
    );
    return {
      instance, contractDeploySigner, signers, logic, proxy,
      minter, defaultAdmin,
      alice, bob, charlie
    };
  }

  it("should function e2e", async function () {
    const {
      instance,
      signers,
      minter,
      alice,
      bob,
      charlie,
      logic,
    } = await loadFixture(deployFixture);
    const signer = signers[0];
    const eip712DomainValue = await instance.eip712Domain();
    console.log(`eip712DomainValue is ${JSON.stringify(eip712DomainValue)}`);
    // resemble eip712DomainValue into a struct so we can access its field by name
    const eip712DomainStruct = {
      name: eip712DomainValue.name,
      version: eip712DomainValue.version,
      chainId: eip712DomainValue.chainId,
      verifyingContract: eip712DomainValue.verifyingContract,
    };
    console.log(`eip712DomainStruct is ${JSON.stringify(eip712DomainStruct, null, 2)}`);

    const typedMessage = {
      primaryType: "DnsUpdateRequest",
      domain: {
        name: eip712DomainValue.name,
        version: eip712DomainValue.version,
        chainId: eip712DomainValue.chainId,
        verifyingContract: eip712DomainValue.verifyingContract,
        // salt: eip712DomainValue.salt, XXX INCOMPETIBLE WITH eth_signTypedData_v4
        // extensions: eip712DomainValue.extensions XXX INCOMPETIBLE WITH eth_signTypedData_v4
      },

      types: {
        // Unforunately, ethers-5.7 doesn't currently support including EIP712Domain and PrimaryType 
        //   EIP712Domain: [
        //     { name: "name", type: "string" },
        //     { name: "version", type: "string" },
        //     { name: "chainId", type: "uint256" },
        //     { name: "verifyingContract", type: "address" }
        //   ]
        DnsUpdateRequest: [
          { name: "updateType", type: "string" },
          { name: "record", type: "DnsRecord" }
        ],
        DnsRecord: [
          { name: "name", type: "string" },
          { name: "dnsType", type: "string" },
          { name: "value", type: "string" },
          { name: "ttl", type: "uint256" }
        ],

      },
      message: {
        updateType: "ADD",
        record: {
          name: "test-alice.test.d3dev.xyz",
          dnsType: "A",
          value: "1.2.3.4",
          ttl: 300
        }
      }
    };

    const sigFromEthers5 = await signer._signTypedData(
      typedMessage.domain,
      typedMessage.types,
      typedMessage.message
    );

    const digestByEthers5 = ethers.utils._TypedDataEncoder.hash(
      typedMessage.domain,
      typedMessage.types,
      typedMessage.message
    );

    console.log(`Digest1 is ${digestByEthers5}`);
    // (typedMessage.types as any)['EIP712Domain'] = [
    //   { name: "name", type: "string" },
    //   { name: "version", type: "string" },
    //   { name: "chainId", type: "uint256" },
    //   { name: "verifyingContract", type: "address" }
    // ];

    // const sigFromStandard = await ethers.provider.send("eth_signTypedData_v4", [
    //   signer.address.toLowerCase(),
    //   JSON.stringify(typedMessage)
    // ]);
    // expect(sigFromEthers5).to.equal(sigFromStandard);
    // console.log(`sig is ${sigFromEthers5}`);
    
    const digestByContract = await instance.getDigest(typedMessage.message);
    expect(digestByEthers5).to.equal(digestByContract);
    const recoveredSigner = ethers.utils.recoverAddress(digestByEthers5, sigFromEthers5);
    console.log(`Recovered signer2 is ${recoveredSigner}`);
    expect(recoveredSigner).to.equal(signer.address);
  });
  
  it("should behave the same in ethers._signTypedData and standard RPC method eth_signTypedData_v4.", async function () {
    const {
      instance,
      signers,
      minter,
      alice,
      bob,
      charlie,
      logic,
    } = await loadFixture(deployFixture);
    const signer = signers[0];
    const chainId = await ethers.provider.getNetwork().then(network => network.chainId);
    const eip712DomainValue = await instance.eip712Domain();
    console.log(`eip712DomainValue is ${JSON.stringify(eip712DomainValue)}`);
    // resemble eip712DomainValue into a struct so we can access its field by name
    const eip712DomainStruct = {
      name: eip712DomainValue.name,
      version: eip712DomainValue.version,
      chainId: eip712DomainValue.chainId,
      verifyingContract: eip712DomainValue.verifyingContract,
    };
    console.log(`eip712DomainStruct is ${JSON.stringify(eip712DomainStruct, null, 2)}`);

    const typedMessage = {
      primaryType: "DnsUpdateRequest",
      domain: {
        name: eip712DomainValue.name,
        version: eip712DomainValue.version,
        chainId: eip712DomainValue.chainId.toNumber(),
        verifyingContract: eip712DomainValue.verifyingContract,
      },

      types: {
        DnsUpdateRequest: [
          { name: "updateType", type: "string" },
          { name: "record", type: "DnsRecord" }
        ],
        DnsRecord: [
          { name: "name", type: "string" },
          { name: "dnsType", type: "string" },
          { name: "value", type: "string" },
          { name: "ttl", type: "uint256" }
        ],

      },
      message: {
        updateType: "ADD",
        record: {
          name: "test-alice.test.d3dev.xyz",
          dnsType: "A",
          value: "1.2.3.4",
          ttl: 300
        }
      }
    };

    const sigFromEthers5 = await signer._signTypedData(
      typedMessage.domain,
      typedMessage.types,
      typedMessage.message
    );

    const digestByEthers5 = ethers.utils._TypedDataEncoder.hash(
      typedMessage.domain,
      typedMessage.types,
      typedMessage.message
    );

    console.log(`Digest1 is ${digestByEthers5}`);
    (typedMessage.types as any)['EIP712Domain'] = [
      { name: "name", type: "string" },
      { name: "version", type: "string" },
      { name: "chainId", type: "uint256" },
      { name: "verifyingContract", type: "address" }
    ];

    const sigFromStandard = await ethers.provider.send("eth_signTypedData_v4", [
      signer.address.toLowerCase(),
      JSON.stringify(typedMessage)
    ]);
    // expect(sigFromEthers5).to.equal(sigFromStandard);
    // console.log(`sig is ${sigFromEthers5}`);
  });
  
});
