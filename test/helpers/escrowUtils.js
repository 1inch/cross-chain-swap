const hre = require('hardhat');
const { ethers } = hre;

const { trim0x } = require('@1inch/solidity-utils');

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

const srcTimelockDurations = {
    finality: 120, // 2 minutes
    unlock: 240, // 4 minutes
    publicUnlock: 720, // 12 minutes
};

const dstTimelockDurations = {
    finality: 300, // 5 minutes
    unlock: 240, // 4 minutes
    publicUnlock: 360, // 6 minutes
};

function getRandomBytes () {
    return ethers.toUtf8Bytes((Math.floor(Math.random() * 1000) + 1).toString());
}

function buldDynamicData ({
    chainId,
    token,
    safetyDeposit,
}) {
    const hashlock = ethers.keccak256(getRandomBytes());
    const data = '0x00' + trim0x(abiCoder.encode(
        ['uint256', 'uint256', 'address', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256'],
        [hashlock, chainId, token, safetyDeposit, ...Object.values(srcTimelockDurations), ...Object.values(dstTimelockDurations)],
    ));
    return { data, hashlock };
};

function buildDstEscrowImmutables ({
    maker,
    chainId,
    token,
    amount,
    safetyDeposit,
}) {
    const hashlock = ethers.keccak256(getRandomBytes());
    const escrowImmutables = {
        // deployedAt: 0,
        maker,
        hashlock,
        // chainId,
        token,
        amount,
        safetyDeposit,
        timelocks: dstTimelockDurations,
    };

    const data = abiCoder.encode(
        ['uint256', 'address', 'uint256', 'address', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256'],
        [hashlock, maker, chainId, token, amount, safetyDeposit, ...Object.values(dstTimelockDurations)],
    );

    return { data, escrowImmutables, hashlock };
}

module.exports = {
    abiCoder,
    buildDstEscrowImmutables,
    buldDynamicData,
};
