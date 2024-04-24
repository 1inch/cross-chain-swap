require('@nomicfoundation/hardhat-chai-matchers');
require('@nomicfoundation/hardhat-foundry');
require('@matterlabs/hardhat-zksync-solc');
require('dotenv').config();

module.exports = {
  solidity: {
    compilers: [
        {
          version: '0.8.23',
          settings: {
              optimizer: {
                  enabled: true,
                  runs: 1000000,
              },
              evmVersion: 'shanghai',
              viaIR: true,
          },
        },
    ],
},
  namedAccounts: {
    deployer: {
        default: 0,
    },
  },
  networks: {
    zksyncTest: {
      url: process.env.ZKSYNC_TEST_RPC_URL,
      chainId: 260,
      zksync: true,
      accounts: [process.env.ZKSYNC_TEST_PRIVATE_KEY_0, process.env.ZKSYNC_TEST_PRIVATE_KEY_1],
      ethNetwork: 'mainnet',
    }
  },
  zksolc: {
    version: '1.4.0',
    compilerSource: 'binary',
    settings: {},
  },
  dependencyCompiler: {
    paths: [
        '@1inch/solidity-utils/contracts/mocks/TokenCustomDecimalsMock.sol',
        '@1inch/solidity-utils/contracts/mocks/TokenMock.sol',
    ],
  },
  mocha: {
    timeout: 10_000_000
  }
};
