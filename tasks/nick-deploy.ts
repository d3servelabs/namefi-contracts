import {task} from 'hardhat/config'
import type {TaskArguments} from 'hardhat/types'
import {nickDeployByName} from '../utils/deployUtil'
import {randomBytes} from 'crypto'
import {hexlify} from 'ethers/lib/utils'

const WAIT_FOR_BLOCK = 12

task('namefi-nick-deploy-proxy-admin', 'Deploy the ProxyAdmin contract')
    .addOptionalParam(
        'nonce',
        'The nonce to use for the deployment',
        '0x00000000000000000000000000000000000000005715a2bbff5b843d84e1daf8'
    )

    .addFlag('dryRun', 'Do a dry run')
    .setAction(async function (taskArguments: TaskArguments, {ethers, run}) {
        let nonce = taskArguments.nonce
            ? taskArguments.nonce
            : hexlify(randomBytes(32))
        console.log(`Using nonce ${nonce}`)
        const initOwner = `0x01Bf7f00540988622a32de1089B7DeA09a867188`
        const {contract: proxyAdmin, tx} = await nickDeployByName(
            ethers,
            'NamefiProxyAdmin',
            [initOwner],
            nonce,
            taskArguments.dryRun
        )
        if (taskArguments.dryRun) {
            console.log(`Dry run done`)
            return
        } else {
            await proxyAdmin.deployed()

            for (let i = 0; i < WAIT_FOR_BLOCK; i++) {
                console.log(`Block ${i}...`)
                await tx.wait(i)
            }

            console.log(
                `Done waiting for the confirmation for contract proxyAdmin at ${proxyAdmin.address}`
            )
            await run('verify:verify', {
                address: proxyAdmin.address,
                constructorArguments: [initOwner],
                contract: 'contracts/NamefiProxyAdmin.sol:NamefiProxyAdmin'
            }).catch((e) =>
                console.log(
                    `Failure ${e} when verifying proxyAdmin at ${proxyAdmin.address}`
                )
            )
            console.log(`Done verifying proxyAdmin at ${proxyAdmin.address}`)
        }
    })

task('namefi-nick-deploy-logic', 'Deploy the logic contract')
    .addParam('logicContractName')
    .addFlag('dryRun', 'Do a dry run')
    .addOptionalParam('nonce', 'The nonce to use for the deployment')
    .setAction(async function (taskArguments: TaskArguments, {ethers, run}) {
        let nonce = taskArguments.nonce
            ? taskArguments.nonce
            : hexlify(randomBytes(32))
        console.log(`Using nonce ${nonce}`)
        if (taskArguments.dryRun) {
            console.log(`Doing a dry run`)
        }
        const {contract, tx} = await nickDeployByName(
            ethers,
            taskArguments.logicContractName,
            [],
            nonce,
            taskArguments.dryRun
        )
        if (taskArguments.dryRun) {
            console.log(`Dry run done`)
            return
        } else {
            await contract.deployed()

            for (let i = 0; i < WAIT_FOR_BLOCK; i++) {
                console.log(`Block ${i}...`)
                await tx.wait(i)
            }

            console.log(
                `Done waiting for the confirmation for contract at ${contract.address}`
            )
            await run('verify:verify', {
                address: contract.address
            }).catch((e) =>
                console.log(
                    `Failure ${e} when verifying contract at ${contract.address}`
                )
            )
            console.log(`Done verifying contract at ${contract.address}`)
        }
    })

task('namefi-nick-deploy-proxy', 'Deploy the proxy contract')
    .addParam('logicContractName')
    .addParam('logicAddress')
    .addParam('adminAddress')
    .addFlag('dryRun', 'Do a dry run')
    .addOptionalParam('nonce', 'The nonce to use for the deployment')
    .setAction(async function (taskArguments: TaskArguments, {ethers, run}) {
        let nonce = taskArguments.nonce
            ? taskArguments.nonce
            : hexlify(randomBytes(32))
        console.log(`Using nonce ${nonce}`)
        if (taskArguments.dryRun) {
            console.log(`Doing a dry run`)
        }
        const {contract: proxy, tx} = await nickDeployByName(
            ethers,
            'TransparentUpgradeableProxy',
            [
                taskArguments.logicAddress,
                taskArguments.adminAddress,
                // Initialization data
                []
            ],
            nonce,
            taskArguments.dryRun
        )
        if (taskArguments.dryRun) {
            console.log(`Dry run done`)
            return
        } else {
            await tx.wait()

            await proxy.deployed()
            // attach contract to UnsafelyDestroyable
            const proxyAsLogic = await ethers.getContractAt(
                taskArguments.logicContractName,
                proxy.address
            )
            await (proxyAsLogic as any).initialize()

            for (let i = 0; i < WAIT_FOR_BLOCK; i++) {
                console.log(`Block ${i}...`)
                await tx.wait(i)
            }

            console.log(
                `Done waiting for the confirmation for contract TransparentUpgradeableProxy at ${proxy.address}`
            )
            await run('verify:verify', {
                address: proxy.address,
                constructorArguments: [
                    taskArguments.logicAddress,
                    taskArguments.adminAddress,
                    // Initialization data
                    []
                ]
            }).catch((e) =>
                console.log(
                    `Failure ${e} when verifying TransparentUpgradeableProxy at ${proxy.address}`
                )
            )
            console.log(
                `Done verifying TransparentUpgradeableProxy at ${proxy.address}`
            )
        }
    })
