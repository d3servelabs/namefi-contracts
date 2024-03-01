import {expect} from 'chai'
import {ethers} from 'hardhat'
import {deployByName} from '../utils/deployUtil'
import {loadFixture, time} from '@nomicfoundation/hardhat-network-helpers'

describe('NamefiNFT', function () {
    const DEFAULT_ADMIN_ROLE = ethers.utils.hexZeroPad('0x00', 32)
    const MINTER_ROLE = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes('MINTER')
    )
    // deployFixture
    async function deployFixture() {
        const contractDeploySigner = ethers.Wallet.fromMnemonic(
            'test test test test test test test test test test test junk'
        ).connect(ethers.provider)
        const signers = await ethers.getSigners()
        const minter = signers[1]
        const defaultAdmin = signers[2]
        const alice = signers[3]
        const bob = signers[4]
        const charlie = signers[5]

        const {contract: logic} = await deployByName(
            ethers,
            'NamefiNFT',
            [],
            contractDeploySigner
        )

        const {contract: proxyAdmin} = await deployByName(
            ethers,
            'ProxyAdmin',
            [],
            contractDeploySigner
        )

        const {contract: proxy} = await deployByName(
            ethers,
            'TransparentUpgradeableProxy',
            [logic.address, proxyAdmin.address, []],
            contractDeploySigner
        )
        const instance = await ethers.getContractAt('NamefiNFT', proxy.address)

        await instance.connect(contractDeploySigner).initialize()

        await instance
            .connect(contractDeploySigner)
            .grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin.address)
        expect(await instance.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin.address))
            .to.be.true
        expect(await instance.hasRole(MINTER_ROLE, defaultAdmin.address)).to.be
            .false

        expect(
            await instance.hasRole(
                DEFAULT_ADMIN_ROLE,
                contractDeploySigner.address
            )
        ).to.be.true
        expect(
            await instance.hasRole(MINTER_ROLE, contractDeploySigner.address)
        ).to.be.true
        await instance
            .connect(contractDeploySigner)
            .renounceRole(DEFAULT_ADMIN_ROLE, contractDeploySigner.address)
        await instance
            .connect(contractDeploySigner)
            .renounceRole(MINTER_ROLE, contractDeploySigner.address)
        expect(
            await instance.hasRole(
                DEFAULT_ADMIN_ROLE,
                contractDeploySigner.address
            )
        ).to.be.false
        expect(
            await instance.hasRole(MINTER_ROLE, contractDeploySigner.address)
        ).to.be.false

        await instance
            .connect(defaultAdmin)
            .grantRole(MINTER_ROLE, minter.address)
        expect(await instance.hasRole(MINTER_ROLE, minter.address)).to.be.true
        expect(await instance.hasRole(DEFAULT_ADMIN_ROLE, minter.address)).to.be
            .false

        return {
            instance,
            contractDeploySigner,
            signers,
            minter,
            defaultAdmin,
            alice,
            bob,
            charlie
        }
    }

    it('should function e2e', async function () {
        const {instance, signers, minter, alice, bob, charlie} =
            await loadFixture(deployFixture)
        const normalizedDomainName = 'bob.alice.eth'

        const expirationTime =
            (await ethers.provider.getBlock('latest')).timestamp +
            60 * 60 * 24 * 365 * 10 // 10 days

        // Verify that owner can mint
        await expect(
            instance
                .connect(alice)
                .safeMintByNameNoCharge(
                    bob.address,
                    normalizedDomainName,
                    expirationTime
                )
        ).to.be.revertedWith(/AccessControl: account.*missing role.*/)

        const tx = await instance
            .connect(minter)
            .safeMintByNameNoCharge(
                bob.address,
                normalizedDomainName,
                expirationTime
            )
        const rc = await tx.wait()
        const event = rc.events?.find((e: any) => e.event === 'Transfer')
        expect(event).to.not.be.undefined
        expect(event?.args?.from).to.equal(ethers.constants.AddressZero)
        expect(event?.args?.to).to.equal(bob.address)
        expect(event?.args?.tokenId).to.equal(
            ethers.utils.id(normalizedDomainName)
        )
        expect(
            await instance.ownerOf(ethers.utils.id(normalizedDomainName))
        ).to.equal(bob.address)
        expect(
            await instance.ownerOf(ethers.utils.id('bob.alice.eth'))
        ).to.equal(bob.address)

        // // Verify that holder can transfer NFT
        await expect(
            instance
                .connect(alice)
                .safeTransferFromByName(
                    bob.address,
                    charlie.address,
                    normalizedDomainName
                )
        )
            .to.be.revertedWithCustomError(
                instance,
                'NamefiNFT_TransferUnauthorized'
            )
            .withArgs(
                alice.address,
                bob.address,
                charlie.address,
                ethers.utils.id(normalizedDomainName)
            )
        const tx0 = await instance
            .connect(bob)
            .safeTransferFromByName(
                bob.address,
                charlie.address,
                normalizedDomainName
            )
        const rc0 = await tx0.wait()
        const event0 = rc0.events?.find((e: any) => e.event === 'Transfer')
        expect(event0).to.not.be.undefined
        expect(event0?.args?.from).to.equal(bob.address)
        expect(event0?.args?.to).to.equal(charlie.address)
        expect(event0?.args?.tokenId).to.equal(
            ethers.utils.id(normalizedDomainName)
        )
        expect(
            await instance.ownerOf(ethers.utils.id(normalizedDomainName))
        ).to.equal(charlie.address)
        expect(
            await instance.ownerOf(ethers.utils.id('bob.alice.eth'))
        ).to.equal(charlie.address)

        // Verify the tokenURI outputs svg
        const tokenURI = await instance.tokenURI(
            ethers.utils.id(normalizedDomainName)
        )
        expect(tokenURI === `https://d3serve.xyz/nft/${normalizedDomainName}`)

        // // Verify that owner can burn
        await expect(
            instance.connect(charlie).burnByName(normalizedDomainName)
        ).to.be.revertedWith(/AccessControl: account.*missing role.*/)
        await expect(instance.connect(minter).burnByName(normalizedDomainName))
            .to.be.revertedWithCustomError(instance, 'LockableNFT_NotLocked')
            .withArgs(ethers.utils.id(normalizedDomainName))
        await instance.connect(minter).lockByName(normalizedDomainName)
        const tx1 = await instance
            .connect(minter)
            .burnByName(normalizedDomainName)
        const rc1 = await tx1.wait()
        const event1 = rc1.events?.find((e: any) => e.event === 'Transfer')
        expect(event1).to.not.be.undefined
        expect(event1?.args?.to).to.equal(ethers.constants.AddressZero)
        expect(event1?.args?.from).to.equal(charlie.address)
        expect(event1?.args?.tokenId).to.equal(
            ethers.utils.id(normalizedDomainName)
        )
        await expect(
            instance.ownerOf(ethers.utils.id(normalizedDomainName))
        ).to.be.revertedWith('ERC721: invalid token ID')
    })

    describe('Expiration', function () {
        it('Should be respected at minting', async function () {
            const {instance, signers, minter} = await loadFixture(deployFixture)
            const alice = signers[1]
            const bob = signers[2]
            const charlie = signers[3]
            const normalizedDomainName = 'bob.alice.eth'

            const expirationTime =
                (await ethers.provider.getBlock('latest')).timestamp - 1

            await expect(
                instance
                    .connect(minter)
                    .safeMintByNameNoCharge(
                        bob.address,
                        normalizedDomainName,
                        expirationTime
                    )
            )
                // .to.be.revertedWith("NamefiNFT: expiration time too early");
                .to.be.revertedWithCustomError(
                    instance,
                    'NamefiNFT_EpxirationDateTooEarly'
                )
                .withArgs(
                    expirationTime,
                    (await ethers.provider.getBlock('latest')).timestamp + 1
                )
        })

        it('Should be respected at transfering', async function () {
            const {instance, signers, defaultAdmin, minter} = await loadFixture(
                deployFixture
            )
            const alice = signers[1]
            const bob = signers[2]
            const charlie = signers[3]
            const normalizedDomainName = 'bob.alice.eth'

            const expirationTime =
                (await ethers.provider.getBlock('latest')).timestamp + 10

            const tx = await instance
                .connect(minter)
                .safeMintByNameNoCharge(
                    bob.address,
                    normalizedDomainName,
                    expirationTime
                )
            await time.increaseTo(expirationTime + 1)
            await expect(
                instance
                    .connect(bob)
                    .safeTransferFromByName(
                        bob.address,
                        charlie.address,
                        normalizedDomainName
                    )
            )
                // .to.be.revertedWith("ExpirableNFT: expired");
                .to.be.revertedWithCustomError(instance, 'ExpirableNFT_Expired')
                .withArgs(ethers.utils.id(normalizedDomainName))
        })
    })

    describe('Lock', function () {
        it('Should yield an event of Lock or Unlock', async function () {
            const {instance, signers, minter} = await loadFixture(deployFixture)
            const alice = signers[1]
            const bob = signers[2]
            const charlie = signers[3]
            const normalizedDomainName = 'bob.alice.eth'

            const expirationTime =
                (await ethers.provider.getBlock('latest')).timestamp + 1000

            await expect(
                instance
                    .connect(minter)
                    .safeMintByNameNoCharge(
                        bob.address,
                        normalizedDomainName,
                        expirationTime
                    )
            )
            await expect(
                instance
                    .connect(bob)
                    .safeTransferFromByName(
                        bob.address,
                        charlie.address,
                        normalizedDomainName
                    )
            )
            let tx = await instance
                .connect(minter)
                .lockByName(normalizedDomainName)
            let rc = await tx.wait()
            let event = rc.events?.find((e: any) => e.event === 'Lock')
            expect(event).to.not.be.undefined
            expect(event?.args?.tokenId).to.equal(
                ethers.utils.id(normalizedDomainName)
            )

            await expect(
                instance
                    .connect(charlie)
                    .safeTransferFromByName(
                        charlie.address,
                        bob.address,
                        normalizedDomainName
                    )
            )
                .to.be.revertedWithCustomError(instance, 'LockableNFT_Locked')
                .withArgs(ethers.utils.id(normalizedDomainName))

            let tx2 = await instance
                .connect(minter)
                .unlockByName(normalizedDomainName)
            let rc2 = await tx2.wait()
            let event2 = rc2.events?.find((e: any) => e.event === 'Unlock')
            expect(event2).to.not.be.undefined
            expect(event2?.args?.tokenId).to.equal(
                ethers.utils.id(normalizedDomainName)
            )
        })

        it('Should be respected at transfer', async function () {
            const {instance, signers, minter} = await loadFixture(deployFixture)
            const alice = signers[1]
            const bob = signers[2]
            const charlie = signers[3]
            const normalizedDomainName = 'bob.alice.eth'

            const expirationTime =
                (await ethers.provider.getBlock('latest')).timestamp + 1000

            await expect(
                instance
                    .connect(minter)
                    .safeMintByNameNoCharge(
                        bob.address,
                        normalizedDomainName,
                        expirationTime
                    )
            )
            await expect(
                instance
                    .connect(bob)
                    .safeTransferFromByName(
                        bob.address,
                        charlie.address,
                        normalizedDomainName
                    )
            )
            await instance.connect(minter).lockByName(normalizedDomainName)
            await expect(
                instance
                    .connect(charlie)
                    .safeTransferFromByName(
                        charlie.address,
                        bob.address,
                        normalizedDomainName
                    )
            )
                .to.be.revertedWithCustomError(instance, 'LockableNFT_Locked')
                .withArgs(ethers.utils.id(normalizedDomainName))
        })

        it('Should be respected at burning', async function () {
            const {instance, signers, minter} = await loadFixture(deployFixture)
            const alice = signers[1]
            const bob = signers[2]
            const charlie = signers[3]
            const normalizedDomainName = 'bob.alice.eth'

            const expirationTime =
                (await ethers.provider.getBlock('latest')).timestamp + 100
            await expect(
                instance
                    .connect(minter)
                    .safeMintByNameNoCharge(
                        bob.address,
                        normalizedDomainName,
                        expirationTime
                    )
            )
            await expect(
                instance.connect(minter).burnByName(normalizedDomainName)
            )
                .to.be.revertedWithCustomError(
                    instance,
                    'LockableNFT_NotLocked'
                )
                .withArgs(ethers.utils.id(normalizedDomainName))
            await instance.connect(minter).lockByName(normalizedDomainName)
            await instance.connect(minter).burnByName(normalizedDomainName)
            await expect(
                instance.connect(minter).burnByName(normalizedDomainName)
            ).to.be.revertedWith('ERC721: invalid token ID')
        })
    })

    it('should enforce normalization upon minting', async function () {
        const {instance, signers, minter, alice, bob, charlie} =
            await loadFixture(deployFixture)
        const notNormalizedDomainName = 'Bob.Alice.eth'
        const expirationTime =
            (await ethers.provider.getBlock('latest')).timestamp +
            60 * 60 * 24 * 365 * 10 // 10 days
        expect(await instance.isNormalizedName(notNormalizedDomainName)).to.be
            .false
        await expect(
            instance
                .connect(minter)
                .safeMintByNameNoCharge(
                    alice.address,
                    notNormalizedDomainName,
                    expirationTime
                )
        )
            .to.be // ("NamefiNFT: domain name is not normalized");
            .revertedWithCustomError(
                instance,
                'NamefiNFT_DomainNameNotNomalized'
            )
            .withArgs(notNormalizedDomainName)

        const normalizedDomainName = 'bob.alice.eth'
        expect(await instance.isNormalizedName(normalizedDomainName)).to.be.true
        let tx = await instance
            .connect(minter)
            .safeMintByNameNoCharge(
                alice.address,
                normalizedDomainName,
                expirationTime
            )
        let rc = await tx.wait()
        let event = rc.events?.find((e: any) => e.event === 'Transfer')
        expect(event).to.not.be.undefined
        expect(event?.args?.from).to.equal(ethers.constants.AddressZero)
        expect(event?.args?.to).to.equal(alice.address)
        expect(event?.args?.tokenId).to.equal(
            ethers.utils.id(normalizedDomainName)
        )
        expect(
            await instance.ownerOf(ethers.utils.id(normalizedDomainName))
        ).to.equal(alice.address)
    })
})
