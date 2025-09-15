import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { randomBytes } from "crypto";

const NICK_DEPLOYER = "0x4e59b44847b379578588920ca78fbf26c0b4956c";

task("namefi-mine-nonce", "Mine nonce for deterministic contract deployment")
    .addParam("contract", "Contract name (NamefiNFT or NamefiServiceCredit)")
    .addOptionalParam("logInterval", "Log interval in seconds", "2")
    .addOptionalParam("limitInterval", "Stop mining after N seconds", "6")
    .setAction(async ({ contract, logInterval, limitInterval }: TaskArguments, { ethers }) => {
        // Validate contract
        if (!["NamefiNFT", "NamefiServiceCredit"].includes(contract)) {
            throw new Error(`Invalid contract: ${contract}`);
        }
        
        // Get initCode hash
        const factory = await ethers.getContractFactory(contract);
        const initCode = factory.bytecode;
        const initCodeHash = ethers.utils.keccak256(initCode);
        
        console.log(`Mining ${contract}... (continuous, ${logInterval}s logs)`);
        console.log(`InitCode hash: ${initCodeHash}`);
        console.log(`Bytecode: ${initCode}`);
        console.log(`Artifacts: ${__dirname}/../artifacts/contracts/${contract}.sol/${contract}.json\n`);
        
        let bestAddress = "0xffffffffffffffffffffffffffffffffffffffff";
        let bestNonce = "";
        let attempts = 0;
        let shouldStop = false;
        
        const startTime = Date.now();
        let lastLogTime = startTime;
        const logMs = parseInt(logInterval) * 1000;
        const limitMs = parseInt(limitInterval) * 1000;
        
        // Handle Ctrl+C
        process.on('SIGINT', () => {
            shouldStop = true;
            console.log("\nStopping...");
        });
        
        
        while (!shouldStop) {
            // Generate random nonce
            const nonce = "0x" + randomBytes(32).toString('hex');
            
            // Calculate CREATE2 address
            const address = ethers.utils.getCreate2Address(NICK_DEPLOYER, nonce, initCodeHash);
            attempts++;
            
            // Check if smaller address
            if (address < bestAddress) {
                bestAddress = address;
                bestNonce = nonce;
                console.log(`✨ NEW BEST: ${address}, ${nonce}`);
            }
            
            // Progress log with yield
            const now = Date.now();
            if (now - lastLogTime >= logMs) {
                const rate = Math.round(attempts / ((now - startTime) / 1000));
                console.log(`⏳ ${attempts.toLocaleString()} attempts (${rate}/s) - Best: ${bestAddress}`);
                lastLogTime = now;
                
                // Yield for Ctrl+C handling
                await new Promise(resolve => setImmediate(resolve));
                if (shouldStop) break;
            }
            
            // Check time limit
            if (now - startTime >= limitMs) {
                shouldStop = true;
                console.log(`\n⏰ Time limit reached (${limitInterval}s)`);
                break;
            }
        }
        
        // Final result
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        console.log(`\n📊 Mining stopped after ${attempts.toLocaleString()} attempts (${elapsed}s)`);
        console.log(`🏆 Best: ${bestAddress}`);
        console.log(`📝 Nonce: ${bestNonce}`);
        console.log(`\n💡 Deploy with:`);
        console.log(`npx hardhat namefi-nick-deploy-logic --logic-contract-name ${contract} --nonce ${bestNonce} --dry-run`);
        console.log(`npx hardhat namefi-manual-deploy --contract ${contract} --nonce ${bestNonce}`);
    });