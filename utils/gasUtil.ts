import { Provider } from "@ethersproject/providers";
import { ContractTransaction } from "ethers";

export async function gasReport(tx:ContractTransaction, provider:Provider) {
    const gasUsed = (await tx.wait()).gasUsed;
    console.log(`Gas used: ${gasUsed.toString()}`);
    const gasPrice = await provider.getGasPrice();
    console.log(`Gas price (wei): ${gasPrice.toString()}`);
    const costInWei = gasUsed.mul(gasPrice);
    console.log(`Cost (in wei): ${costInWei.toString()}`);
    const costInGwei = costInWei.div(1e9);
    console.log(`Cost (in gwei): ${costInGwei.toString()}`);
    const costInEth = costInGwei.toNumber() / 1e9 ;
    console.log(`Cost (in ethers): ${costInEth.toString()}`);
    const usdPerEth = (parseFloat(process.env.NAMEFI_USD_PER_ETHER as string) || 3000.0) as number;
    console.log(`Cost (in USD): ${costInEth * usdPerEth}`);
}