import { concat, encodeAbiParameters, zeroAddress } from "viem";
import hre from "hardhat";

import EscrowFactoryModule from "../ignition/modules/EscrowFactory.js";
import ImmutablesLibModule from "../ignition/modules/ImmutablesLib.js";
import {
  InvalidChainConfigError,
  isSetAddress,
  linkLibraries,
  MissingChainConfigError,
  parseSalt,
  readChainConfig,
} from "./deploy-utils.js";

const RESCUE_DELAY = 691200; // 8 days

async function main(): Promise<void> {
  const { ignition, viem } = await hre.network.getOrCreate();

  const publicClient = await viem.getPublicClient();
  const chainId = (await publicClient.getChainId()).toString();

  const { lop, accessToken, create3Deployer, factoryOwner, factorySalt } =
    readChainConfig(chainId);

  if (
    !isSetAddress(lop) ||
    !isSetAddress(accessToken) ||
    !isSetAddress(create3Deployer) ||
    !factorySalt
  ) {
    throw new MissingChainConfigError(chainId);
  }

  // Owner falls back to the DEPLOYER_ADDRESS env var when the configured value
  // is missing or the zero address. Any other value must be a valid address.
  if (
    factoryOwner !== undefined &&
    factoryOwner !== zeroAddress &&
    !isSetAddress(factoryOwner)
  ) {
    throw new InvalidChainConfigError(
      "factoryOwner",
      factoryOwner,
      "a checksummed address"
    );
  }
  const owner = isSetAddress(factoryOwner)
    ? factoryOwner
    : process.env.DEPLOYER_ADDRESS;
  if (!isSetAddress(owner)) {
    throw new Error(
      `Factory owner not set for chain ${chainId}: configure factoryOwner in deploy/config.json or the DEPLOYER_ADDRESS env var`
    );
  }

  const salt = parseSalt("factorySalt", factorySalt);

  // Deploy ImmutablesLib first, since EscrowFactory depends on it
  const { immutablesLib } = await ignition.deploy(ImmutablesLibModule);
  const immutablesLibAddress = immutablesLib.address;

  // Link the ImmutablesLib into the EscrowFactory bytecode and encode its constructor args
  const artifact = await hre.artifacts.readArtifact("EscrowFactory");
  const linkedBytecode = linkLibraries(artifact, {
    ImmutablesLib: immutablesLibAddress,
  });
  const encodedArgs = encodeAbiParameters(
    [
      { type: "address" },
      { type: "address" },
      { type: "address" },
      { type: "uint32" },
      { type: "uint32" },
    ],
    [lop, accessToken, owner, RESCUE_DELAY, RESCUE_DELAY]
  );
  const initCode = concat([linkedBytecode, encodedArgs]);

  // Deploy EscrowFactory
  const { escrowFactory } = await ignition.deploy(EscrowFactoryModule, {
    parameters: {
      EscrowFactoryModule: { create3Deployer, salt, initCode },
    },
  });

  console.log(`ImmutablesLib deployed at: ${immutablesLibAddress}`);
  console.log(`EscrowFactory deployed at: ${escrowFactory.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
