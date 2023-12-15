const hre = require('hardhat');
const { ethers } = hre;
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ether } = require('@1inch/solidity-utils');
const { buildOrder, buildOrderData } = require('@1inch/limit-order-protocol-contract/test/helpers/orderUtils');

const { buldDynamicData, buildDstEscrowImmutables } = require('./helpers/escrowUtils');

describe('EscrowFactory', async function () {
    async function deployContracts () {
        const [deployer, alice, bob, charlie] = await ethers.getSigners();
        const accounts = { deployer, alice, bob, charlie };
        const limitOrderProtocol = deployer;

        const TokenMock = await ethers.getContractFactory('TokenMock');
        const dai = await TokenMock.deploy('DAI', 'DAI');
        await dai.waitForDeployment();
        const TokenCustomDecimalsMock = await ethers.getContractFactory('TokenCustomDecimalsMock');
        const usdc = await TokenCustomDecimalsMock.deploy('USDC', 'USDC', ether('1000'), 6);
        await usdc.waitForDeployment();
        const tokens = { dai, usdc };

        const EscrowRegistry = await ethers.getContractFactory('EscrowRegistry');
        const escrowRegistry = await EscrowRegistry.deploy();
        await escrowRegistry.waitForDeployment();

        const EscrowFactory = await ethers.getContractFactory('EscrowFactory');
        const escrowFactory = await EscrowFactory.deploy(escrowRegistry, limitOrderProtocol);
        await escrowFactory.waitForDeployment();
        const contracts = { escrowRegistry, escrowFactory, limitOrderProtocol };

        const chainId = (await ethers.provider.getNetwork()).chainId;

        return { accounts, contracts, tokens, chainId };
    }
    async function initContracts () {
        const { accounts, contracts, tokens, chainId } = await deployContracts();

        await tokens.dai.mint(accounts.deployer, ether('1000'));

        await tokens.dai.approve(contracts.escrowFactory, ether('1'));
        await tokens.usdc.approve(contracts.escrowFactory, ether('1'));

        return { accounts, contracts, tokens, chainId };
    }

    it('should deploy clones for maker', async function () {
        const { accounts, contracts, tokens, chainId } = await loadFixture(initContracts);

        for (let i = 0; i < 3; i++) {
            const srcAmount = Math.floor(Math.random() * 100) + 1;
            const dstAmount = Math.floor(Math.random() * 100) + 1;
            const order = buildOrder({
                makerAsset: tokens.usdc.target,
                takerAsset: tokens.dai.target,
                makingAmount: srcAmount,
                takingAmount: dstAmount,
                maker: await accounts.alice.getAddress(),
            });
            const data = buildOrderData(chainId, await contracts.limitOrderProtocol.getAddress(), order);
            const orderHash = ethers.TypedDataEncoder.hash(data.domain, data.types, data.value);

            const { data: extraData, hashlock } = buldDynamicData({
                chainId,
                token: tokens.dai.target,
            });

            const srcClone = await ethers.getContractAt('EscrowRegistry', await contracts.escrowFactory.addressOfEscrow(orderHash));
            await tokens.usdc.transfer(srcClone, srcAmount);

            await contracts.escrowFactory.postInteraction(
                order,
                '0x', // extension
                orderHash,
                accounts.deployer, // taker
                srcAmount, // makingAmount
                dstAmount, // takingAmount
                0, // remainingMakingAmount
                extraData,
            );
            const returnedSrcEscrowImmutables = await srcClone.srcEscrowImmutables();
            expect(returnedSrcEscrowImmutables.extraDataParams.hashlock).to.equal(hashlock);
            expect(returnedSrcEscrowImmutables.interactionParams.srcAmount).to.equal(srcAmount);
            expect(returnedSrcEscrowImmutables.extraDataParams.dstToken).to.equal(tokens.dai.target);
        }
    });

    it('should deploy clones for taker', async function () {
        const { accounts, contracts, tokens, chainId } = await loadFixture(initContracts);

        for (let i = 0; i < 3; i++) {
            const amount = Math.floor(Math.random() * 100) + 1;
            const safetyDeposit = Math.floor(amount * 0.1);
            const { data, escrowImmutables, hashlock } = buildDstEscrowImmutables({
                maker: await accounts.alice.getAddress(),
                chainId,
                token: tokens.dai.target,
                amount,
                safetyDeposit,
            });

            const deployedAt = (await ethers.provider.getBlock('latest')).timestamp + 1;
            const msgSender = await accounts.deployer.getAddress();
            const salt = ethers.solidityPackedKeccak256(
                ['uint256', 'bytes', 'address'],
                [deployedAt, data, msgSender],
            );
            const srcClone = await ethers.getContractAt('EscrowRegistry', await contracts.escrowFactory.addressOfEscrow(salt));

            await time.setNextBlockTimestamp(deployedAt);
            const tx = contracts.escrowFactory.createEscrow(escrowImmutables);
            await expect(tx).to.changeTokenBalances(tokens.dai, [accounts.deployer, srcClone], [-(amount + safetyDeposit), (amount + safetyDeposit)]);
            const returnedDstEscrowImmutables = await srcClone.dstEscrowImmutables();
            expect(returnedDstEscrowImmutables.hashlock).to.equal(hashlock);
            expect(returnedDstEscrowImmutables.amount).to.equal(amount);
        }
    });
});
