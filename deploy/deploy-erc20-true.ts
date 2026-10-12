import hre from "hardhat";

import ERC20TrueModule from "../ignition/modules/ERC20True.js";
import {
  isSetAddress,
  MissingChainConfigError,
  parseSalt,
  readChainConfig,
} from "./deploy-utils.js";

async function main(): Promise<void> {
  const { ignition, viem } = await hre.network.getOrCreate();

  const publicClient = await viem.getPublicClient();
  const chainId = (await publicClient.getChainId()).toString();

  const { create3Deployer, trueTokenSalt } = readChainConfig(chainId);

  if (!isSetAddress(create3Deployer) || !trueTokenSalt) {
    throw new MissingChainConfigError(chainId);
  }

  const salt = parseSalt("trueTokenSalt", trueTokenSalt);

  const { bytecode: initCode } = await hre.artifacts.readArtifact("ERC20True");

  const { erc20True } = await ignition.deploy(ERC20TrueModule, {
    parameters: {
      ERC20TrueModule: { create3Deployer, salt, initCode },
    },
  });

  console.log(`ERC20True deployed at: ${erc20True.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
