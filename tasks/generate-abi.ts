import { task } from "hardhat/config";
import fs from "node:fs";
import path from "node:path";

task("generate-abi", "Generates ABI JSON files for all contracts")
  .setAction(async (taskArgs, hre) => {
    // Make sure the output directory exists
    const outputDir = path.join(__dirname, "../abis");
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir);
      console.log(`Created directory: ${outputDir}`);
    }

    // Get all compiled artifacts
    const artifactPaths = await hre.artifacts.getArtifactPaths();
    
    // Filter out the test contracts and interfaces
    const mainContracts = artifactPaths.filter(artifactPath => {
      const contractName = path.basename(artifactPath, ".json");
      const contractPath = path.dirname(artifactPath);
      
      // Skip test contracts and OZ contracts
      return !contractPath.includes("testing") && 
             !contractPath.includes("@openzeppelin") &&
             !contractPath.includes("node_modules") &&
             !contractName.startsWith("I"); // Skip interfaces
    });

    console.log(`Found ${mainContracts.length} main contracts to extract ABIs from.`);

    // Extract and save ABIs
    for (const artifactPath of mainContracts) {
      try {
        const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
        const contractName = path.basename(artifactPath, ".json");
        
        // Skip if no ABI
        if (!artifact.abi || artifact.abi.length === 0) {
          console.log(`Skipping ${contractName} because it has no ABI`);
          continue;
        }
        
        // Write ABI to file
        const abiPath = path.join(outputDir, `${contractName}.json`);
        fs.writeFileSync(abiPath, JSON.stringify(artifact.abi, null, 2));
        console.log(`Generated ABI for ${contractName} at ${abiPath}`);
      } catch (error) {
        console.error(`Error processing ${artifactPath}:`, error);
      }
    }

    console.log("ABI generation complete!");
  }); 