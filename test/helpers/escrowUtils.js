const hre = require('hardhat');
const { ethers } = hre;
const { trim0x } = require('@1inch/solidity-utils');

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

const srcTimelockDurations = {
    finality: 120n, // 2 minutes
    publicUnlock: 900n, // 15 minutes
};

const dstTimelockDurations = {
    finality: 300n, // 5 minutes
    unlock: 240n, // 4 minutes
    publicUnlock: 360n, // 6 minutes
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
    const data = abiCoder.encode(
        ['uint256', 'uint256', 'address', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256'],
        [hashlock, chainId, token, safetyDeposit, ...Object.values(srcTimelockDurations), ...Object.values(dstTimelockDurations)],
    );
    return { data, hashlock };
};

function buildDstEscrowImmutables ({
    maker,
    taker,
    chainId,
    token,
    amount,
    safetyDeposit,
}) {
    const hashlock = ethers.keccak256(getRandomBytes());
    const srcCancellationTimestamp = BigInt(Math.floor(Date.now() / 1000)) + srcTimelockDurations.finality + srcTimelockDurations.publicUnlock;
    const escrowImmutables = {
        hashlock,
        maker,
        taker,
        token,
        amount,
        safetyDeposit,
        timelocks: dstTimelockDurations,
        srcCancellationTimestamp,
    };

    const data = abiCoder.encode(
        ['uint256', 'address', 'address', 'uint256', 'address', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256'],
        [hashlock, maker, taker, chainId, token, amount, safetyDeposit, ...Object.values(dstTimelockDurations)],
    );

    return { data, escrowImmutables, hashlock };
}

function buildSecret () {
    return '0x' + trim0x(ethers.hexlify(getRandomBytes())).padStart(64, '0');
}

module.exports = {
    abiCoder,
    buildDstEscrowImmutables,
    buldDynamicData,
    buildSecret,
    getRandomBytes,
    dstTimelockDurations,
    srcTimelockDurations,
};
