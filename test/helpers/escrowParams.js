const hre = require('hardhat');
const { ethers } = hre;

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

srcTimelockDurations.finalitySecondChain = dstTimelockDurations.finality;
dstTimelockDurations.finalitySecondChain = srcTimelockDurations.finality;

const Timelocks = [
    { name: 'finality', type: 'uint256' },
    { name: 'unlock', type: 'uint256' },
    { name: 'publicUnlock', type: 'uint256' },
];

const Conditions = [
    { name: 'chainId', type: 'uint256' },
    { name: 'token', type: 'address' },
    { name: 'amount', type: 'uint256' },
    { name: 'timelocks', type: 'tuple', components: Timelocks },
];

const SrcEscrowParams = [
    { name: 'hashlock', type: 'uint256' },
    { name: 'srcConditions', type: 'tuple', components: Conditions },
    { name: 'dstConditions', type: 'tuple', components: Conditions },
];

const DstEscrowParams = [
    { name: 'hashlock', type: 'uint256' },
    { name: 'conditions', type: 'tuple', components: Conditions },
];

const ABISrcEscrowParams = {
    name: 'data',
    type: 'tuple',
    components: SrcEscrowParams,
};

const ABIDstEscrowParams = {
    name: 'data',
    type: 'tuple',
    components: DstEscrowParams,
};

function getRandomBytes () {
    return ethers.toUtf8Bytes((Math.floor(Math.random() * 1000) + 1).toString());
}

function buildConditions ({
    amount,
    token,
    chainId,
    timelockDurations,
}) {
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const finality = currentTimestamp + timelockDurations.finality + timelockDurations.finalitySecondChain;
    const unlock = finality + timelockDurations.unlock;
    const publicUnlock = unlock + timelockDurations.publicUnlock;

    const timelocks = {
        finality,
        unlock,
        publicUnlock,
    };
    const conditions = {
        chainId,
        token,
        amount,
        timelocks,
    };
    return conditions;
};

function buildSrcEscrowParams ({
    srcAmount,
    dstAmount,
    srcToken,
    dstToken,
    srcChainId,
    dstChainId,
}) {
    const hashlock = ethers.keccak256(getRandomBytes());
    const srcConditions = buildConditions({
        amount: srcAmount,
        token: srcToken,
        chainId: srcChainId,
        timelockDurations: srcTimelockDurations,
    });
    const dstConditions = buildConditions({
        amount: dstAmount,
        token: dstToken,
        chainId: dstChainId,
        timelockDurations: dstTimelockDurations,
    });
    const data = {
        hashlock,
        srcConditions,
        dstConditions,
    };

    const escrowParams = abiCoder.encode([ABISrcEscrowParams], [data]);

    return { escrowParams, hashlock };
};

function buildDstEscrowParams ({
    amount,
    token,
    chainId,
}) {
    const hashlock = ethers.keccak256(getRandomBytes());
    const conditions = buildConditions({
        amount,
        token,
        chainId,
        timelockDurations: dstTimelockDurations,
    });
    const data = {
        hashlock,
        conditions,
    };

    const escrowParams = abiCoder.encode([ABIDstEscrowParams], [data]);

    return { escrowParams, hashlock };
}

module.exports = {
    buildSrcEscrowParams,
    buildDstEscrowParams,
};
