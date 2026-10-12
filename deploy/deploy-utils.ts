import type { Artifact } from "hardhat/types/artifacts";
import type { Hex } from "viem";

import { readFileSync } from "node:fs";
import { isAddress, isHex, keccak256, toBytes } from "viem";

// The values come straight from JSON.parse, so nothing about their types is
// known until the deploy scripts check them.
export interface ChainConfig {
  lop: unknown;
  accessToken: unknown;
  create3Deployer: unknown;
  factoryOwner: unknown;
  factorySalt: unknown;
  trueTokenSalt: unknown;
}

/**
 * A hex salt must be exactly 32 bytes and is used as-is; any other string is
 * hashed with keccak256.
 */
export function parseSalt(key: string, salt: unknown): Hex {
  if (typeof salt !== "string") {
    throw new InvalidChainConfigError(key, salt, "a string");
  }
  if (!isHex(salt)) {
    return keccak256(toBytes(salt));
  }
  if (salt.length !== 66) {
    throw new InvalidChainConfigError(
      key,
      salt,
      "32 bytes of hex, or text to hash"
    );
  }
  return salt;
}

/** True when `value` is a valid, non-zero address. */
export function isSetAddress(value: unknown): value is Hex {
  return typeof value === "string" && isAddress(value) && BigInt(value) !== 0n;
}

export class InvalidChainConfigError extends Error {
  constructor(key: string, value: unknown, expected: string) {
    super(
      `Invalid ${key} in deploy/config.json: expected ${expected}, got ${JSON.stringify(value)}`
    );
  }
}

export class MissingChainConfigError extends Error {
  constructor(chainId: string) {
    super(
      `Missing deploy/config.json entries while deploying to chain ${chainId}. ` +
        `The config is single-chain (Ethereum mainnet by default) — edit it before deploying elsewhere.`
    );
  }
}

// deploy/config.json is single-chain: it holds one set of addresses and salts
// (mainnet's by default), with no chain id keying. Deploying to another
// network means editing that file — same contract as the forge scripts.
// The file is resolved next to this module, so the working directory doesn't
// matter.
export function readChainConfig(chainId: string): ChainConfig {
  let raw;
  try {
    raw = JSON.parse(
      readFileSync(new URL("config.json", import.meta.url), "utf8")
    );
  } catch {
    throw new MissingChainConfigError(chainId);
  }
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw new MissingChainConfigError(chainId);
  }

  return {
    lop: raw.lop,
    accessToken: raw.accessToken,
    create3Deployer: raw.create3Deployer,
    factoryOwner: raw.factoryOwner,
    factorySalt: raw.factorySalt,
    trueTokenSalt: raw.trueTokenSalt,
  };
}

/**
 * Fills the placeholders in a contract's creation bytecode with the addresses
 * of its external libraries
 */
export function linkLibraries(
  artifact: Artifact,
  libraryAddresses: Record<string, string>
): Hex {
  let bytecode = artifact.bytecode;
  for (const libs of Object.values(artifact.linkReferences)) {
    for (const [libName, positions] of Object.entries(libs)) {
      const address = libraryAddresses[libName];
      if (address === undefined) {
        throw new Error(`Missing address for linked library ${libName}`);
      }
      const addr = address.toLowerCase().replace(/^0x/, "");
      for (const { start, length } of positions) {
        const offset = 2 + start * 2; // skip "0x", 2 hex chars per byte
        bytecode =
          bytecode.slice(0, offset) +
          addr +
          bytecode.slice(offset + length * 2);
      }
    }
  }
  if (!isHex(bytecode)) {
    throw new Error("Linked bytecode is not valid hex");
  }
  return bytecode;
}
