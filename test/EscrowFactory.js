const hre = require('hardhat');
const { ethers } = hre;
const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ether } = require('@1inch/solidity-utils');
const { buildOrder, buildOrderData } = require('@1inch/limit-order-protocol-contract/test/helpers/orderUtils');

const {
    buldDynamicData,
    buildDstEscrowImmutables,
    buildSecret,
    dstTimelockDurations,
    srcTimelockDurations,
} = require('./helpers/escrowUtils');

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

        const Escrow = await ethers.getContractFactory('Escrow');
        const escrowRegistry = await Escrow.deploy();
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

    async function deployCloneSrc () {
        const { accounts, contracts, tokens, chainId } = await loadFixture(initContracts);
        const srcAmount = Math.floor(Math.random() * 100) + 1;
        const dstAmount = Math.floor(Math.random() * 100) + 1;
        const safetyDeposit = Math.floor(dstAmount * 0.1);
        const order = buildOrder({
            makerAsset: tokens.usdc.target,
            takerAsset: tokens.dai.target,
            makingAmount: srcAmount,
            takingAmount: dstAmount,
            maker: await accounts.alice.getAddress(),
        });
        const data = buildOrderData(chainId, await contracts.limitOrderProtocol.getAddress(), order);
        const orderHash = ethers.TypedDataEncoder.hash(data.domain, data.types, data.value);

        const { data: extraData, hashlock, secret } = buldDynamicData({
            chainId,
            token: tokens.dai.target,
            safetyDeposit,
        });

        const srcClone = await ethers.getContractAt('Escrow', await contracts.escrowFactory.addressOfEscrow(orderHash));
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

        return { accounts, contracts, tokens, chainId, srcClone, srcAmount, dstAmount, safetyDeposit, hashlock, secret };
    }

    async function deployCloneDst () {
        const { accounts, contracts, tokens, chainId } = await loadFixture(initContracts);
        const amount = Math.floor(Math.random() * 100) + 1;
        const safetyDeposit = Math.floor(amount * 0.1);
        const { data, escrowImmutables, secret } = buildDstEscrowImmutables({
            maker: await accounts.alice.getAddress(),
            taker: await accounts.deployer.getAddress(),
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
        const dstClone = await ethers.getContractAt('Escrow', await contracts.escrowFactory.addressOfEscrow(salt));

        await time.setNextBlockTimestamp(deployedAt);
        const tx = contracts.escrowFactory.createEscrow(escrowImmutables);
        return { accounts, contracts, tokens, chainId, dstClone, tx, escrowImmutables, secret };
    }

    it('should deploy clones for maker', async function () {
        for (let i = 0; i < 3; i++) {
            const { tokens, srcClone, srcAmount, hashlock } = await deployCloneSrc();
            const returnedSrcEscrowImmutables = await srcClone.srcEscrowImmutables();
            expect(returnedSrcEscrowImmutables.extraDataParams.hashlock).to.equal(hashlock);
            expect(returnedSrcEscrowImmutables.interactionParams.srcAmount).to.equal(srcAmount);
            expect(returnedSrcEscrowImmutables.extraDataParams.dstToken).to.equal(tokens.dai.target);
        }
    });

    it('should deploy clones for taker', async function () {
        for (let i = 0; i < 3; i++) {
            const { accounts, tokens, dstClone, tx, escrowImmutables } = await deployCloneDst();
            await expect(tx).to.changeTokenBalances(
                tokens.dai,
                [accounts.deployer, dstClone],
                [
                    -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
                    (escrowImmutables.amount + escrowImmutables.safetyDeposit),
                ],
            );
            const returnedDstEscrowImmutables = await dstClone.dstEscrowImmutables();
            expect(returnedDstEscrowImmutables.hashlock).to.equal(escrowImmutables.hashlock);
            expect(returnedDstEscrowImmutables.amount).to.equal(escrowImmutables.amount);
        }
    });

    it('should not deploy clone for taker when it is unsafe', async function () {
        const { contracts, tx, escrowImmutables } = await deployCloneDst();
        await time.setNextBlockTimestamp(escrowImmutables.srcCancellationTimestamp + 1n);
        await expect(tx).to.be.revertedWithCustomError(contracts.escrowFactory, 'InvalidCreationTime');
    });

    it('should not withdraw tokens on the source chain during finality lock', async function () {
        const { srcClone, secret } = await deployCloneSrc();

        await expect(
            srcClone.withdrawSrc(secret),
        ).to.be.revertedWithCustomError(srcClone, 'InvalidWithdrawalTime');
    });

    it('should not withdraw tokens on the destination chain during finality lock', async function () {
        const { accounts, tokens, dstClone, tx, escrowImmutables, secret } = await deployCloneDst();
        await expect(tx).to.changeTokenBalances(
            tokens.dai,
            [accounts.deployer, dstClone],
            [
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
                (escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );

        await expect(
            dstClone.withdrawDst(secret),
        ).to.be.revertedWithCustomError(dstClone, 'InvalidWithdrawalTime');
    });

    it('should withdraw tokens on the source chain', async function () {
        const { accounts, tokens, srcClone, srcAmount, secret } = await deployCloneSrc();

        const returnedSrcEscrowImmutables = await srcClone.srcEscrowImmutables();
        await time.setNextBlockTimestamp(returnedSrcEscrowImmutables.deployedAt + srcTimelockDurations.finality + 100n);

        const tx = srcClone.withdrawSrc(secret);
        await expect(tx).to.changeTokenBalances(tokens.usdc, [accounts.deployer, srcClone], [srcAmount, -srcAmount]);
    });

    it('should not withdraw tokens on the source chain with the wrong secret', async function () {
        const { srcClone } = await deployCloneSrc();

        const secret = buildSecret();

        const returnedSrcEscrowImmutables = await srcClone.srcEscrowImmutables();
        await time.setNextBlockTimestamp(returnedSrcEscrowImmutables.deployedAt + srcTimelockDurations.finality + 100n);

        await expect(
            srcClone.withdrawSrc(secret),
        ).to.be.revertedWithCustomError(srcClone, 'InvalidSecret');
    });

    it('should withdraw tokens on the destination chain by resolver', async function () {
        const { accounts, tokens, dstClone, tx, escrowImmutables, secret } = await deployCloneDst();
        await expect(tx).to.changeTokenBalances(
            tokens.dai,
            [accounts.deployer, dstClone],
            [
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
                (escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );

        const returnedDstEscrowImmutables = await dstClone.dstEscrowImmutables();
        await time.setNextBlockTimestamp(returnedDstEscrowImmutables.deployedAt + dstTimelockDurations.finality + 100n);
        const withdrawalTx = dstClone.withdrawDst(secret);
        await expect(withdrawalTx).to.changeTokenBalances(
            tokens.dai,
            [accounts.alice, accounts.deployer, dstClone],
            [
                escrowImmutables.amount,
                escrowImmutables.safetyDeposit,
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );
    });

    it('should not withdraw tokens on the destination chain with the wrong secret', async function () {
        const { accounts, tokens, dstClone, tx, escrowImmutables } = await deployCloneDst();
        await expect(tx).to.changeTokenBalances(
            tokens.dai,
            [accounts.deployer, dstClone],
            [
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
                (escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );

        const secret = buildSecret();

        const returnedSrcEscrowImmutables = await dstClone.dstEscrowImmutables();
        await time.setNextBlockTimestamp(returnedSrcEscrowImmutables.deployedAt + dstTimelockDurations.finality + 100n);

        await expect(
            dstClone.withdrawDst(secret),
        ).to.be.revertedWithCustomError(dstClone, 'InvalidSecret');
    });

    it('should not withdraw tokens on the destination chain by non-resolver during non-public unlock period', async function () {
        const { accounts, tokens, dstClone, tx, escrowImmutables, secret } = await deployCloneDst();
        await expect(tx).to.changeTokenBalances(
            tokens.dai,
            [accounts.deployer, dstClone],
            [
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
                (escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );

        const returnedDstEscrowImmutables = await dstClone.dstEscrowImmutables();
        await time.setNextBlockTimestamp(returnedDstEscrowImmutables.deployedAt + dstTimelockDurations.finality + 100n);
        await expect(
            dstClone.connect(accounts.bob).withdrawDst(secret),
        ).to.be.revertedWithCustomError(dstClone, 'InvalidCaller');
    });

    it('should withdraw tokens on the destination chain by anyone', async function () {
        const { accounts, tokens, dstClone, tx, escrowImmutables, secret } = await deployCloneDst();
        await expect(tx).to.changeTokenBalances(
            tokens.dai,
            [accounts.deployer, dstClone],
            [
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
                (escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );

        const returnedDstEscrowImmutables = await dstClone.dstEscrowImmutables();
        await time.setNextBlockTimestamp(
            returnedDstEscrowImmutables.deployedAt + dstTimelockDurations.finality + dstTimelockDurations.unlock + 100n,
        );
        const withdrawalTx = dstClone.connect(accounts.bob).withdrawDst(secret);
        await expect(withdrawalTx).to.changeTokenBalances(
            tokens.dai,
            [accounts.alice, accounts.bob, dstClone],
            [
                escrowImmutables.amount,
                escrowImmutables.safetyDeposit,
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );
    });

    it('should cancel escrow on the source chain', async function () {
        const { accounts, tokens, srcClone, srcAmount } = await deployCloneSrc();

        const returnedSrcEscrowImmutables = await srcClone.srcEscrowImmutables();
        await time.setNextBlockTimestamp(
            returnedSrcEscrowImmutables.deployedAt + srcTimelockDurations.finality + srcTimelockDurations.publicUnlock,
        );

        const tx = srcClone.connect(accounts.bob).cancelSrc();
        await expect(tx).to.changeTokenBalances(tokens.usdc, [accounts.alice, srcClone], [srcAmount, -srcAmount]);
    });

    it('should not cancel escrow on the source chain during unlock period', async function () {
        const { accounts, srcClone } = await deployCloneSrc();

        const returnedSrcEscrowImmutables = await srcClone.srcEscrowImmutables();
        await time.setNextBlockTimestamp(returnedSrcEscrowImmutables.deployedAt + srcTimelockDurations.finality + 100n);

        await expect(
            srcClone.connect(accounts.bob).cancelSrc(),
        ).to.be.revertedWithCustomError(srcClone, 'InvalidCancellationTime');
    });

    it('should cancel escrow on the destination chain', async function () {
        const { accounts, tokens, dstClone, tx, escrowImmutables } = await deployCloneDst();
        await expect(tx).to.changeTokenBalances(
            tokens.dai,
            [accounts.deployer, dstClone],
            [
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
                (escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );
        const returnedDstEscrowImmutables = await dstClone.dstEscrowImmutables();
        await time.setNextBlockTimestamp(
            returnedDstEscrowImmutables.deployedAt + dstTimelockDurations.finality + dstTimelockDurations.unlock + dstTimelockDurations.publicUnlock + 100n,
        );
        const withdrawalTx = dstClone.connect(accounts.bob).cancelDst();
        await expect(withdrawalTx).to.changeTokenBalances(
            tokens.dai,
            [accounts.deployer, accounts.bob, dstClone],
            [
                escrowImmutables.amount,
                escrowImmutables.safetyDeposit,
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );
    });

    it('should not cancel escrow on the destination chain during unlock period', async function () {
        const { accounts, tokens, dstClone, tx, escrowImmutables } = await deployCloneDst();
        await expect(tx).to.changeTokenBalances(
            tokens.dai,
            [accounts.deployer, dstClone],
            [
                -(escrowImmutables.amount + escrowImmutables.safetyDeposit),
                (escrowImmutables.amount + escrowImmutables.safetyDeposit),
            ],
        );
        const returnedDstEscrowImmutables = await dstClone.dstEscrowImmutables();
        await time.setNextBlockTimestamp(
            returnedDstEscrowImmutables.deployedAt + dstTimelockDurations.finality + 100n,
        );
        await expect(
            dstClone.connect(accounts.bob).cancelDst(),
        ).to.be.revertedWithCustomError(dstClone, 'InvalidCancellationTime');
    });
});
