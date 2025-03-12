import { expect } from "chai";
import { ethers, network } from "hardhat";
import { deployByName } from "../utils/deployUtil";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";

describe("NamefiServiceCredit", function () {
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

  const CHAINLINK_ETH_USD_FEED = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

  // Updated deployFixture to accept blockNumber parameter
  async function deployFixture(blockNumber?: number) {
    // Fork mainnet with optional block number
    await network.provider.request({
      method: "hardhat_reset",
      params: [{
        forking: {
          jsonRpcUrl: process.env.MAINNET_RPC_URL,
          blockNumber // If undefined, will fork from latest block
        }
      }]
    });

    const contractDeploySigner = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    ).connect(ethers.provider);
    const signers = await ethers.getSigners();
    const scDefaultAdmin = signers[1];
    const scMinter = signers[2];
    const scPauser = signers[3];
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
    const { instance: nftInstance, logic: nftLogic } = await creatUpgradableContract("NamefiNFT", proxyAdmin);
    await nftInstance.connect(contractDeploySigner).grantRole(DEFAULT_ADMIN_ROLE, nftDefaultAdmin.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(MINTER_ROLE, contractDeploySigner.address);
    await nftInstance.connect(contractDeploySigner).renounceRole(PAUSER_ROLE, contractDeploySigner.address);
  
    const { instance: scInstance } = await creatUpgradableContract("NamefiServiceCredit", proxyAdmin);
    await scInstance.connect(contractDeploySigner).grantRole(MINTER_ROLE, scMinter.address);
    await scInstance.connect(contractDeploySigner).grantRole(DEFAULT_ADMIN_ROLE, scDefaultAdmin.address);
    expect(await scInstance.hasRole(DEFAULT_ADMIN_ROLE, scDefaultAdmin.address)).to.be.true;
    await scInstance.connect(contractDeploySigner).renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address);
    await scInstance.connect(contractDeploySigner).renounceRole(MINTER_ROLE, contractDeploySigner.address);
    expect(await scInstance.hasRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address)).to.be.false;
    await scInstance.connect(scDefaultAdmin).grantRole(PAUSER_ROLE, scPauser.address);

    await scInstance.connect(scDefaultAdmin).setEthUsdPriceFeed(CHAINLINK_ETH_USD_FEED);

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

  // Create named fixture functions for specific block numbers
  async function deployFixtureLatest() {
    return deployFixture();
  }

  async function deployFixtureBefore() {
    return deployFixture(18535000);
  }

  async function deployFixtureAfter() {
    return deployFixture(19250000);
  }

  it("should be able mintBatch service credits", async function () {
    const { nftInstance, scInstance, 
      scDefaultAdmin, scMinter, scPauser,
      nftDefaultAdmin, nftMinter, 
      alice, bob, charlie 
    } = await loadFixture(deployFixtureLatest);
    await scInstance.connect(scDefaultAdmin).grantRole(MINTER_ROLE, scMinter.address);
    await scInstance.connect(scMinter).mintBatch(
      [alice.address, bob.address], 
      [ethers.utils.parseUnits("100", 18), ethers.utils.parseUnits("200", 18)], []);
    expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 18)); 
    expect(await scInstance.balanceOf(bob.address)).to.equal(ethers.utils.parseUnits("200", 18));
      
    await scInstance.transferFromBatch(
      [alice.address, bob.address], 
      [charlie.address, charlie.address], 
      [ethers.utils.parseUnits("50", 18), ethers.utils.parseUnits("100", 18)], 
      []);
    expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("50", 18));
    expect(await scInstance.balanceOf(bob.address)).to.equal(ethers.utils.parseUnits("100", 18));
    expect(await scInstance.balanceOf(charlie.address)).to.equal(ethers.utils.parseUnits("150", 18));

    await scInstance.transferFromBatch(
      [charlie.address, charlie.address], 
      [bob.address, alice.address], 
      [ethers.utils.parseUnits("50", 18), ethers.utils.parseUnits("100", 18)], 
      []);
    expect(await scInstance.balanceOf(bob.address)).to.equal(ethers.utils.parseUnits("150", 18));
    expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("150", 18));
    expect(await scInstance.balanceOf(charlie.address)).to.equal(ethers.utils.parseUnits("0", 18));
  });

  it("should be able to be charged to mint a new name", async function () {
    const { nftInstance, scInstance, 
      scDefaultAdmin, scMinter, scPauser,
      nftDefaultAdmin, nftMinter, 
      alice, bob, charlie 
    } = await loadFixture(deployFixtureLatest);   
        
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
            ethers.utils.parseUnits("20", 18),
            []
          );
        expect(await nftInstance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(bob.address);
        expect(await nftInstance.ownerOf(ethers.utils.id("bob.alice.eth"))).to.equal(bob.address);
        expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("80", 18));
  });

  it("DEPRECATED should be able to be charged default amount to mint extend a domain with a multiple of year", async function () {
    const { nftInstance, scInstance, 
      scDefaultAdmin, scMinter, scPauser,
      nftDefaultAdmin, nftMinter, 
      alice, bob, charlie 
    } = await loadFixture(deployFixtureLatest);   
        
        await scInstance.connect(scDefaultAdmin).grantRole(MINTER_ROLE, scMinter.address);
        await scInstance.connect(scMinter).mint(alice.address, ethers.utils.parseUnits("100", 18));
        await scInstance.connect(scDefaultAdmin).revokeRole(MINTER_ROLE, scMinter.address);

        const normalizedDomainName = "bob.alice.eth";

        const expirationTime =
          (await ethers.provider.getBlock("latest")).timestamp +
          60 * 60 * 24 * 365 * 10; // 10 years
    
        expect(await scInstance.connect(scMinter).balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 18));
        await scInstance.connect(scDefaultAdmin).grantRole(CHARGER_ROLE, nftInstance.address);
        await nftInstance.connect(nftDefaultAdmin).grantRole(MINTER_ROLE, nftMinter.address);
        await nftInstance.connect(nftDefaultAdmin).setServiceCreditContract(scInstance.address);
        const tx = await nftInstance.connect(nftMinter)
          .safeMintByNameWithChargeAmount(
            bob.address,
            normalizedDomainName,
            expirationTime,
            alice.address, // chargee
            ethers.utils.parseUnits("20", 18),
            []
          );
        expect(await nftInstance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(bob.address);
        expect(await nftInstance.ownerOf(ethers.utils.id("bob.alice.eth"))).to.equal(bob.address);
        expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("80", 18));

        const tx2 = await nftInstance.connect(nftMinter)
            .extendByNameWithCharge(
            normalizedDomainName,
            60 * 60 * 24 * 365 * 2, // 2 years
            alice.address, // chargee
            ethers.utils.parseUnits("40", 18),
            [] // extra data
            );          
        expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("40", 18));  
        expect(await nftInstance.getExpiration(ethers.utils.id(normalizedDomainName))).to.equal(expirationTime + 60 * 60 * 24 * 365 * 2);

  });

  it("should be able to be charged any amount to mint extend a domain with a multiple of year", async function () {
    const { nftInstance, scInstance, 
      scDefaultAdmin, scMinter, scPauser,
      nftDefaultAdmin, nftMinter, 
      alice, bob, charlie 
    } = await loadFixture(deployFixtureLatest);   
        
        await scInstance.connect(scDefaultAdmin).grantRole(MINTER_ROLE, scMinter.address);
        await scInstance.connect(scMinter).mint(alice.address, ethers.utils.parseUnits("100", 18));
        await scInstance.connect(scDefaultAdmin).revokeRole(MINTER_ROLE, scMinter.address);

        const normalizedDomainName = "bob.alice.eth";

        const expirationTime =
          (await ethers.provider.getBlock("latest")).timestamp +
          60 * 60 * 24 * 365 * 3; // 3 years
    
        expect(await scInstance.connect(scMinter).balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", 18));
        await scInstance.connect(scDefaultAdmin).grantRole(CHARGER_ROLE, nftInstance.address);
        await nftInstance.connect(nftDefaultAdmin).grantRole(MINTER_ROLE, nftMinter.address);
        await nftInstance.connect(nftDefaultAdmin).setServiceCreditContract(scInstance.address);
        const tx = await nftInstance.connect(nftMinter)
          .safeMintByNameWithChargeAmount(
            bob.address,
            normalizedDomainName,
            expirationTime,
            alice.address, // chargee
            ethers.utils.parseUnits("60", 18),
            []
          );
        expect(await nftInstance.ownerOf(ethers.utils.id(normalizedDomainName))).to.equal(bob.address);
        expect(await nftInstance.ownerOf(ethers.utils.id("bob.alice.eth"))).to.equal(bob.address);
        expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("40", 18));

        const tx2 = await nftInstance.connect(nftMinter)
            .extendByNameWithChargeAmount(
            normalizedDomainName,
            60 * 60 * 24 * 365 * 2, // 2 years
            alice.address, // chargee
            ethers.utils.parseUnits("18", 18),
            [] // extra data
            );          
        expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("22", 18));  
        expect(await nftInstance.getExpiration(ethers.utils.id(normalizedDomainName))).to.equal(expirationTime + 60 * 60 * 24 * 365 * 2);

  });

  it("should be able to be buyable with ethers", async function () {
    const { nftInstance, scInstance, 
      scDefaultAdmin, scMinter, scPauser,
      nftDefaultAdmin, nftMinter, 
      alice, bob, charlie 
    } = await loadFixture(deployFixtureLatest);   

    // await expect(scInstance.price(ethers.constants.AddressZero))
    //   // .to.be.revertedWith("NamefiServiceCredit: unsupported payToken");
    //   .to.be.revertedWithCustomError(scInstance, "NamefiServiceCredit_UnsupportedPayToken");

    // await expect(scInstance.connect(alice).setPrice(
    //   ethers.constants.AddressZero,
    //   ethers.utils.parseUnits("2", 6)))
    //   .to.be.revertedWith(/^AccessControl.*is missing role/);
    // let tx0 = await scInstance.connect(scMinter).setPrice(
    //   ethers.constants.AddressZero,
    //   ethers.utils.parseUnits("2", 6));
    // let rc0 = await tx0.wait();
    // let event0 = rc0.events?.find((e: any) => e.event === "SetPrice");
    // expect(event0).to.not.be.undefined;
    // expect(event0?.args?.payToken).to.equal(ethers.constants.AddressZero);
    // expect(event0?.args?.price).to.equal(ethers.utils.parseUnits("2", 6));
    // expect(await scInstance.price(ethers.constants.AddressZero))
    //   .to.equal(ethers.utils.parseUnits("2", 6));

    // Compare chainlink price with contract price
    const ethUsdFeed = await ethers.getContractAt("AggregatorV3Interface", CHAINLINK_ETH_USD_FEED);
    const [, answer, , ,] = await ethUsdFeed.latestRoundData();
    expect(await scInstance.price(ethers.constants.AddressZero)).to.equal(answer.div(1e6));

    expect(scInstance.connect(alice).buyWithEthers({value: ethers.utils.parseUnits("1", 18)}))
      // .to.be.revertedWith("NamefiServiceCredit: insufficient purchasble supply"); 
      .to.be.revertedWithCustomError(scInstance, "NamefiServiceCredit_InsufficientBuyableSupply")
  
    let tx = await scInstance.connect(scMinter).increaseBuyableSupply(ethers.utils.parseUnits("10000", 18));
    let rc = await tx.wait();
    let event = rc.events?.find((e: any) => e.event === "IncreaseBuyableSupply");
    expect(event).to.not.be.undefined;
    expect(event?.args?.increaseBy).to.equal(ethers.utils.parseUnits("10000", 18));
    expect(await scInstance.connect(scMinter).buyableSupply()).to.equal(ethers.utils.parseUnits("10000", 18));

    const ethUsdPrice = await scInstance.price(ethers.constants.AddressZero);

    const expectedTokens = ethers.utils.parseUnits("0.5", 18).mul(1e9).div(ethUsdPrice);

    let tx2 = await scInstance.connect(alice).buyWithEthers({value: ethers.utils.parseUnits("0.5", 18)});
    // check that tx2 contains the event BuyToken
    rc = await tx2.wait();
    event = rc.events?.find((e: any) => e.event === "BuyToken");
    expect(event).to.not.be.undefined;
    expect(event?.args?.buyAmount).to.equal(expectedTokens);
    expect(event?.args?.buyer).to.equal(alice.address);
    expect(event?.args?.payToken).to.equal(ethers.constants.AddressZero);
    expect(event?.args?.payAmount).to.equal(ethers.utils.parseUnits("0.5", 18));
    expect(await scInstance.balanceOf(alice.address)).to.equal(expectedTokens);
  });

  // Should be buyable with Ethers at different price.
  // Handle cases when 1ETH = 2000USD, 3000USD, 5000USD 
  describe("Buy with Ethers at different price", async () => {

    const ETH_TO_NFSC_PRICES = [
      850,
      2000, 
      3000, 
      5000,
      2136,
      10000, 
    ];
    
    for (const price of ETH_TO_NFSC_PRICES) {
      // run the test sequentially

      const payingEthAmount = 0.5; // 0.5ETH
      const payingEthAmountInWei = ethers.utils.parseUnits(payingEthAmount.toString(), 18);
      const expectedNFSCAmount = payingEthAmount * price;
      const expectedNFSCAmountInWei = ethers.utils.parseUnits(expectedNFSCAmount.toString(), 18);
      await it.only(`should be able buy NFSC with ${payingEthAmount} ethers at ${price} and get ${expectedNFSCAmount} NFSC`, async function () {
        const { nftInstance, scInstance, 
          scDefaultAdmin, scMinter, scPauser,
        nftDefaultAdmin, nftMinter, 
        alice, bob, charlie 
      } = await loadFixture(deployFixture);   
      

      const priceGWadOfNFSCPerGWadOfETH = 
        ethers.utils.parseUnits("1", 18).div(ethers.utils.parseUnits(price.toString(), 9));

      await expect(scInstance.price(ethers.constants.AddressZero))
        // .to.be.revertedWith("NamefiServiceCredit: unsupported payToken");
        .to.be.revertedWithCustomError(scInstance, "NamefiServiceCredit_UnsupportedPayToken");
  
      console.log(`For current price: ${price}, SetPrice input (priceGWadOfNFSCPerGWadOfETH) = ${priceGWadOfNFSCPerGWadOfETH}`);
      await expect(scInstance.connect(alice).setPrice(
        ethers.constants.AddressZero,
        priceGWadOfNFSCPerGWadOfETH))
        .to.be.revertedWith(/^AccessControl.*is missing role/);
      let tx0 = await scInstance.connect(scMinter).setPrice(
        ethers.constants.AddressZero,
        priceGWadOfNFSCPerGWadOfETH);
      let rc0 = await tx0.wait();
      let event0 = rc0.events?.find((e: any) => e.event === "SetPrice");
      expect(event0).to.not.be.undefined;
      expect(event0?.args?.payToken).to.equal(ethers.constants.AddressZero);
      expect(event0?.args?.price).to.equal(priceGWadOfNFSCPerGWadOfETH);
      expect(await scInstance.price(ethers.constants.AddressZero))
        .to.equal(priceGWadOfNFSCPerGWadOfETH);
  
      expect(scInstance.connect(alice).buyWithEthers({value: payingEthAmountInWei}))
        // .to.be.revertedWith("NamefiServiceCredit: insufficient purchasble supply"); 
        .to.be.revertedWithCustomError(scInstance, "NamefiServiceCredit_InsufficientBuyableSupply")
    
      const increaseSupplyAmountInGwei = ethers.utils.parseUnits("100000", 18); // Increase supply by 100000 NFSC, should be large enough to buy.
      let tx = await scInstance.connect(scMinter).increaseBuyableSupply(increaseSupplyAmountInGwei);
      let rc = await tx.wait();
      let event = rc.events?.find((e: any) => e.event === "IncreaseBuyableSupply");
      expect(event).to.not.be.undefined;
      expect(event?.args?.increaseBy).to.equal(increaseSupplyAmountInGwei);
      expect(await scInstance.connect(scMinter).buyableSupply()).to.equal(increaseSupplyAmountInGwei);
  
      // print out how much ETH we are using to buy and expected NFSC amount
      console.log(`Assuming current price: ${price}`);
      console.log(`Number of ETH used to buy: ${payingEthAmount}`);
      console.log(`Expected NFSC amount purchased: ${expectedNFSCAmount}`);
      let tx2 = await scInstance.connect(alice).buyWithEthers({value: payingEthAmountInWei});
      // check that tx2 contains the event BuyToken
      rc = await tx2.wait();
      event = rc.events?.find((e: any) => e.event === "BuyToken");
      expect(event).to.not.be.undefined;
      // There will be a small difference due to the precision of the floating point number.
      const allowedDifferenceRatio = 0.00001; // 1e-5
      const actualNFSCAmountInWei = event?.args?.buyAmount;
      const actualDifferenceRatio = actualNFSCAmountInWei.sub(expectedNFSCAmountInWei).div(expectedNFSCAmountInWei).toNumber();
      console.log(`Actual difference ratio: ${actualDifferenceRatio}`);
      expect(actualDifferenceRatio).to.be.lessThan(allowedDifferenceRatio);

      expect(event?.args?.buyer).to.equal(alice.address);
      expect(event?.args?.payToken).to.equal(ethers.constants.AddressZero);
      expect(event?.args?.payAmount).to.equal(payingEthAmountInWei);
      expect(await scInstance.balanceOf(alice.address)).to.equal(actualNFSCAmountInWei);
      });
    }
  });

  it("should be able to be buyable with a TestERC20", async function () {
    const { nftInstance, scInstance, 
      scDefaultAdmin, scMinter, scPauser,
      nftDefaultAdmin, nftMinter, 
      alice, bob, charlie 
    } = await loadFixture(deployFixtureLatest);
    // deploy TestERC20
    const TestERC20 = await ethers.getContractFactory("TestERC20");
    const terc20 = await TestERC20.deploy();
    await terc20.deployed();
    await terc20.grantRole(DEFAULT_ADMIN_ROLE, scMinter.address);
    await expect(scInstance.price(terc20.address))
      // .to.be.revertedWith("NamefiServiceCredit: unsupported payToken");
      .to.be.revertedWithCustomError(scInstance, "NamefiServiceCredit_UnsupportedPayToken");
    let tx0 = await scInstance.connect(scMinter).setPrice(
      terc20.address,
      ethers.utils.parseUnits("2", 9));
    let rc0 = await tx0.wait();
    let event0 = rc0.events?.find((e: any) => e.event === "SetPrice");
    expect(event0).to.not.be.undefined;
    expect(event0?.args?.payToken).to.equal(terc20.address);
    expect(event0?.args?.price).to.equal(ethers.utils.parseUnits("2", 9));
    expect(await scInstance.price(terc20.address))
      .to.equal(ethers.utils.parseUnits("2", 9));
  
    await scInstance.connect(scMinter)
      .increaseBuyableSupply(ethers.utils.parseUnits("1000", 18));
    expect(await scInstance.connect(scMinter).buyableSupply()).to.equal(ethers.utils.parseUnits("1000", 18));

    await expect(scInstance.connect(alice).buy(
      ethers.utils.parseUnits("250", 18),
      terc20.address, 
      ethers.utils.parseUnits("500", 18)))
        .to.be.revertedWith("ERC20: transfer amount exceeds allowance");
    await terc20.connect(scMinter)
      .mint(alice.address, ethers.utils.parseUnits("1000", 18));
    await expect(scInstance.connect(alice).buy(
      ethers.utils.parseUnits("250", 18),
      terc20.address, 
      ethers.utils.parseUnits("500", 18)))
        .to.be.revertedWith("ERC20: transfer amount exceeds allowance");
    await terc20.connect(alice).approve(scInstance.address, ethers.utils.parseUnits("500", 18));
    await expect(scInstance.connect(alice).buy(
      ethers.utils.parseUnits("250", 18),
      terc20.address, 
      ethers.utils.parseUnits("400", 18)))
        // .to.be.revertedWith("NamefiServiceCredit: payAmount insufficient.");
        .to.be.revertedWithCustomError(scInstance, "NamefiServiceCredit_PayAmountInsufficient");
    let tx2 = await scInstance.connect(alice).buy(
      ethers.utils.parseUnits("250", 18),
      terc20.address, 
      ethers.utils.parseUnits("500", 18));
      // check that tx2 contains the event BuyToken
    const rc2 = await tx2.wait();
    const ev2 = rc2.events?.find((e: any) => e.event === "BuyToken");
    expect(ev2).to.not.be.undefined;
    expect(ev2?.args?.buyAmount).to.equal(ethers.utils.parseUnits("250", 18));
    expect(ev2?.args?.buyer).to.equal(alice.address);
    expect(ev2?.args?.payToken).to.equal(terc20.address);
    expect(ev2?.args?.payAmount).to.equal(ethers.utils.parseUnits("500", 18));
    expect(await scInstance.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("250", 18));
  });

  it("should give different token amounts based on ETH/USD price changes at different blocks", async function () {

    const { scInstance, scMinter, scDefaultAdmin, alice } = await loadFixture(deployFixtureBefore);
    
    // Set Chainlink price feed and increase supply
    await scInstance.connect(scDefaultAdmin).setEthUsdPriceFeed(CHAINLINK_ETH_USD_FEED);
    await scInstance.connect(scMinter).increaseBuyableSupply(ethers.utils.parseEther("1000000"));
    
    // Buy with 1 ETH at first block's price
    const ethAmount = ethers.utils.parseEther("1");
    
    await scInstance.connect(alice).buyWithEthers({ value: ethAmount });
    
    // Get price and tokens from first purchase
    const price1 = await scInstance.price(ethers.constants.AddressZero);
    console.log("ETH/USD Price before:", ethers.utils.formatUnits(price1, 2));
    const balance1 = await scInstance.balanceOf(alice.address);
    
    // Second deployment at March block
    const { scInstance: scInstance2, scMinter: scMinter2, scDefaultAdmin: scDefaultAdmin2, alice: alice2 } = await loadFixture(deployFixtureAfter);
    
    await scInstance2.connect(scDefaultAdmin2).setEthUsdPriceFeed(CHAINLINK_ETH_USD_FEED);
    await scInstance2.connect(scMinter2).increaseBuyableSupply(ethers.utils.parseEther("1000000"));
    
    // Buy with same ETH amount at second block's price
    await scInstance2.connect(alice2).buyWithEthers({ value: ethAmount });
    
    // Get price and tokens from second purchase
    const price2 = await scInstance2.price(ethers.constants.AddressZero);
    console.log("ETH/USD Price after:", ethers.utils.formatUnits(price2, 2));
    const balance2 = await scInstance2.balanceOf(alice2.address);
    
    // Verify that higher ETH price results in fewer tokens
    expect(price2).to.be.gt(price1, "ETH price should be higher in second block");
    expect(balance2).to.be.lt(balance1, "Should receive fewer tokens at higher ETH price");
    
    // Calculate and verify the price ratio matches token ratio
    const priceRatio = price2.mul(1000).div(price1);
    const tokenRatio = balance1.mul(1000).div(balance2);
    expect(priceRatio).to.equal(tokenRatio);
    
    console.log("Price ratio:", ethers.utils.formatUnits(priceRatio, 3));
    console.log("Token ratio:", ethers.utils.formatUnits(tokenRatio, 3));
  });
});