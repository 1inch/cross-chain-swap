import { defineConfig } from "hardhat/config";
import dynamicContractImports from "@ignored/imports-plugin";

const baseCompilerSettings = {
  optimizer: {
    enabled: true,
    runs: 1000000,
  },
  viaIR: true,
  evmVersion: "shanghai",
};

export default defineConfig({
  plugins: [dynamicContractImports],
  solidity: {
    // LimitOrderProtocol is a heavy external contract the tests deploy. Build
    // it as a contracts-scope root so it emits an artifact and gets a shim.
    npmFilesToBuild: [
      "@1inch/limit-order-protocol-contract/contracts/LimitOrderProtocol.sol",
      "@1inch/limit-order-protocol-contract/contracts/extensions/FeeTaker.sol",
      "@1inch/solidity-utils/contracts/mocks/TokenMock.sol",
      "@1inch/solidity-utils/contracts/mocks/TokenCustomDecimalsMock.sol",
      "murky/src/Merkle.sol",
    ],
    profiles: {
      default: {
        version: "0.8.23",
        settings: baseCompilerSettings,
      },
      lite: {
        version: "0.8.23",
        settings: {
          ...baseCompilerSettings,
          optimizer: {
            ...baseCompilerSettings.optimizer,
            details: { yulDetails: { optimizerSteps: "" } },
          },
        },
      },
    },
  },
  test: {
    solidity: {
      fuzz: {
        runs: 1024,
      },
    },
  },
});
