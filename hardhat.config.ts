import { configVariable, defineConfig } from "hardhat/config";
import hardhatViem from "@nomicfoundation/hardhat-viem";
import hardhatIgnitionViem from "@nomicfoundation/hardhat-ignition-viem";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import hardhatKeystore from "@nomicfoundation/hardhat-keystore";
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
  plugins: [
    dynamicContractImports,
    hardhatViem,
    hardhatIgnitionViem,
    hardhatVerify,
    hardhatKeystore,
  ],
  solidity: {
    // LimitOrderProtocol is a heavy external contract the tests deploy. Build
    // it as a contracts-scope root so it emits an artifact and gets a shim.
    npmFilesToBuild: [
      "@1inch/limit-order-protocol-contract/contracts/LimitOrderProtocol.sol",
      "@1inch/limit-order-protocol-contract/contracts/extensions/FeeTaker.sol",
      "@1inch/solidity-utils/contracts/mocks/TokenMock.sol",
      "@1inch/solidity-utils/contracts/mocks/TokenCustomDecimalsMock.sol",
      "murky/src/Merkle.sol",
      // Deployer interface used by the Ignition CREATE3 deployment module.
      "@1inch/solidity-utils/contracts/interfaces/ICreate3Deployer.sol",
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
  networks: {
    mainnet: {
      type: "http",
      chainId: 1,
      chainType: "l1",
      url: configVariable("MAINNET_RPC_URL"),
      accounts: [configVariable("DEPLOYER_PRIVATE_KEY")],
    },
  },
  test: {
    solidity: {
      fuzz: {
        runs: 1024,
      },
    },
  },
  verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    },
  },
});
