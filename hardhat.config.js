require('@nomicfoundation/hardhat-chai-matchers');
require('@nomicfoundation/hardhat-foundry');
require('hardhat-dependency-compiler');
require('@matterlabs/hardhat-zksync-solc');
require('@matterlabs/hardhat-zksync-deploy');
require('hardhat-gas-reporter');
require('dotenv').config();

module.exports = {
    solidity: {
        version: '0.8.23',
        settings: {
            optimizer: {
                enabled: true,
                runs: 1_000_000,
            },
            evmVersion: 'shanghai',
            viaIR: true,
        },
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
        },
    },
    zksolc: {
        version: '1.4.0',
        compilerSource: 'binary',
        settings: {},
    },
    gasReporter: {
    enable: true,
    currency: 'USD',
    },
    dependencyCompiler: {
        paths: [
            '@1inch/solidity-utils/contracts/mocks/TokenCustomDecimalsMock.sol',
            '@1inch/solidity-utils/contracts/mocks/TokenMock.sol',
            '@1inch/limit-order-protocol-contract/contracts/LimitOrderProtocol.sol',
        ],
    },
    mocha: {
        timeout: 10_000_000,
    },
};
