const hre = require('hardhat');
const { ethers } = hre;
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');

const { buildSrcEscrowParams, buildDstEscrowParams } = require('./helpers/escrowParams');

describe('EscrowFactory', async function () {
    async function initContracts () {
        const EscrowRegistry = await ethers.getContractFactory('EscrowRegistry');
        const escrowRegistry = await EscrowRegistry.deploy();
        await escrowRegistry.waitForDeployment();

        const EscrowFactory = await ethers.getContractFactory('EscrowFactory');
        const escrowFactory = await EscrowFactory.deploy(escrowRegistry.target);
        await escrowFactory.waitForDeployment();

        return { escrowFactory, escrowRegistry };
    }

    it('should deploy clones for maker', async function () {
        const { escrowFactory } = await loadFixture(initContracts);

        for (let i = 0; i < 3; i++) {
            const srcAmount = Math.floor(Math.random() * 100) + 1;
            const dstAmount = Math.floor(Math.random() * 100) + 1;
            const { escrowParams, hashlock } = buildSrcEscrowParams({
                srcAmount,
                dstAmount,
                srcToken: ethers.ZeroAddress,
                dstToken: ethers.ZeroAddress,
                srcChainId: 1,
                dstChainId: 2,
            });

            const tx = await escrowFactory.createEscrow(escrowParams);
            const receipt = await tx.wait();
            const events = await escrowFactory.queryFilter('EscrowCreated', receipt.blockNumber, receipt.blockNumber);
            const srcClone = await ethers.getContractAt('EscrowRegistry', events[0].args[0]);
            const returnedSrcEscrowParams = await srcClone.srcEscrowParams();
            expect(returnedSrcEscrowParams.hashlock).to.equal(hashlock);
            expect(returnedSrcEscrowParams.srcConditions.amount).to.equal(srcAmount);
            expect(returnedSrcEscrowParams.dstConditions.amount).to.equal(dstAmount);
        }
    });

    it('should deploy clones for taker', async function () {
        const { escrowFactory } = await loadFixture(initContracts);

        for (let i = 0; i < 3; i++) {
            const amount = Math.floor(Math.random() * 100) + 1;
            const { escrowParams, hashlock } = buildDstEscrowParams({
                amount,
                token: ethers.ZeroAddress,
                chainId: 2,
            });

            const tx = await escrowFactory.createEscrow(escrowParams);
            const receipt = await tx.wait();
            const events = await escrowFactory.queryFilter('EscrowCreated', receipt.blockNumber, receipt.blockNumber);
            const srcClone = await ethers.getContractAt('EscrowRegistry', events[0].args[0]);
            const returnedDstEscrowParams = await srcClone.dstEscrowParams();
            expect(returnedDstEscrowParams.hashlock).to.equal(hashlock);
            expect(returnedDstEscrowParams.conditions.amount).to.equal(amount);
        }
    });
});
