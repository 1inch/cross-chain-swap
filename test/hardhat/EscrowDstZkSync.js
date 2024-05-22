const hre = require('hardhat');
const { ethers } = hre;
const { expect } = require('chai');

const { Wallet, Provider } = require('zksync-ethers');
const { Deployer } = require('@matterlabs/hardhat-zksync-deploy');
const { buildMakerTraits, buildOrder, buildOrderData } = require('@1inch/limit-order-protocol-contract/test/helpers/orderUtils');
const { ether } = require('@1inch/solidity-utils');

describe('EscrowDstZkSync', function () {
    const RESCUE_DELAY = 604800; // 7 days
    const SECRET = ethers.keccak256(ethers.toUtf8Bytes('secret'));
    const HASHLOCK = ethers.keccak256(SECRET);
    const MAKING_AMOUNT = ether('0.3');
    const TAKING_AMOUNT = ether('0.5');
    const DST_SAFETY_DEPOSIT = ether('0.05');
    const provider = Provider.getDefaultProvider();
    const timestamps = { withdrawal: 300n, publicWithdrawal: 540n, cancellation: 900n };
    const basicTimelocks = (timestamps.withdrawal << 128n) | (timestamps.publicWithdrawal << 160n) | (timestamps.cancellation << 192n);

    async function deployContracts () {
        const alice = new Wallet(process.env.ZKSYNC_TEST_PRIVATE_KEY_0, provider);
        const bob = new Wallet(process.env.ZKSYNC_TEST_PRIVATE_KEY_1, provider);
        const accounts = { alice, bob };
        const deployer = new Deployer(hre, bob);

        const limitOrderProtocol = bob.address;

        const TokenMock = await deployer.loadArtifact('TokenMock');
        const dai = await deployer.deploy(TokenMock, ['DAI', 'DAI'], { gasLimit: '2000000000' });
        await dai.waitForDeployment();
        const TokenCustomDecimalsMock = await deployer.loadArtifact('TokenCustomDecimalsMock');
        const usdc = await deployer.deploy(TokenCustomDecimalsMock, ['USDC', 'USDC', ether('1000').toString(), 6]);
        await usdc.waitForDeployment();
        const inch = await deployer.deploy(TokenMock, ['1INCH', '1INCH']);
        const tokens = { dai, usdc, inch };

        const EscrowFactory = await deployer.loadArtifact('EscrowFactoryZkSync');
        const escrowFactory = await deployer.deploy(EscrowFactory, [limitOrderProtocol, await inch.getAddress(), RESCUE_DELAY, RESCUE_DELAY]);
        await escrowFactory.waitForDeployment();

        const contracts = { limitOrderProtocol, escrowFactory };

        const chainId = (await ethers.provider.getNetwork()).chainId;

        return { accounts, contracts, tokens, chainId };
    }
    async function initContracts () {
        const { accounts, contracts, tokens, chainId } = await deployContracts();

        await tokens.dai.mint(accounts.bob.address, ether('1000'));
        await tokens.usdc.mint(accounts.bob.address, ether('1000'));
        await tokens.inch.mint(accounts.bob.address, ether('1000'));

        await tokens.dai.approve(contracts.escrowFactory, ether('1'));
        await tokens.usdc.approve(contracts.escrowFactory, ether('1'));

        const order = buildOrder({
            makerAsset: await tokens.usdc.getAddress(),
            takerAsset: await tokens.dai.getAddress(),
            makingAmount: MAKING_AMOUNT,
            takingAmount: TAKING_AMOUNT,
            maker: accounts.alice.address,
            makerTraits: buildMakerTraits({ allowMultipleFills: false }),
        });

        const data = buildOrderData(chainId, contracts.limitOrderProtocol, order);
        const orderHash = ethers.TypedDataEncoder.hash(data.domain, data.types, data.value);

        return { accounts, contracts, tokens, chainId, order, orderHash };
    }

    it('should withdraw tokens on the destination chain by the resolver', async function () {
        const { accounts, contracts, tokens, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const srcCancellationTimestamp = blockTimestamp + RESCUE_DELAY;
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.dai.getAddress(),
            amount: TAKING_AMOUNT,
            safetyDeposit: DST_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowDst(immutables);
        const dstClone = await ethers.getContractAt('EscrowDstZkSync', predictedAddress, accounts.bob);

        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.createDstEscrow(immutables, srcCancellationTimestamp, { value: DST_SAFETY_DEPOSIT, gasLimit: '2000000000' });

        const balanceBeforeAlice = await tokens.dai.balanceOf(accounts.alice.address);
        const balanceBeforeBobNative = await provider.getBalance(accounts.bob.address);
        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(TAKING_AMOUNT);
        expect(await provider.getBalance(predictedAddress)).to.equal(DST_SAFETY_DEPOSIT);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.withdrawal)]);
        await dstClone.withdraw(SECRET, immutables);
        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(0);
        expect(await tokens.dai.balanceOf(accounts.alice.address)).to.equal(balanceBeforeAlice + TAKING_AMOUNT);
        expect(await provider.getBalance(predictedAddress)).to.equal(0);
        expect(await provider.getBalance(accounts.bob.address)).to.be.gt(balanceBeforeBobNative);
    });

    it('should withdraw tokens on the destination chain by anyone', async function () {
        const { accounts, contracts, tokens, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const srcCancellationTimestamp = blockTimestamp + RESCUE_DELAY;
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.dai.getAddress(),
            amount: TAKING_AMOUNT,
            safetyDeposit: DST_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowDst(immutables);
        const dstClone = await ethers.getContractAt('EscrowDstZkSync', predictedAddress, accounts.bob);

        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.createDstEscrow(immutables, srcCancellationTimestamp, { value: DST_SAFETY_DEPOSIT, gasLimit: '2000000000' });

        const balanceBeforeAlice = await tokens.dai.balanceOf(accounts.alice.address);
        const balanceBeforeAliceNative = await provider.getBalance(accounts.alice.address);
        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(TAKING_AMOUNT);
        expect(await provider.getBalance(predictedAddress)).to.equal(DST_SAFETY_DEPOSIT);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.publicWithdrawal)]);
        await dstClone.connect(accounts.alice).publicWithdraw(SECRET, immutables);
        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(0);
        expect(await tokens.dai.balanceOf(accounts.alice.address)).to.equal(balanceBeforeAlice + TAKING_AMOUNT);
        expect(await provider.getBalance(predictedAddress)).to.equal(0);
        expect(await provider.getBalance(accounts.alice.address)).to.be.gt(balanceBeforeAliceNative);
    });

    it('should cancel escrow on the destination chain', async function () {
        const { accounts, contracts, tokens, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const srcCancellationTimestamp = blockTimestamp + RESCUE_DELAY;
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.dai.getAddress(),
            amount: TAKING_AMOUNT,
            safetyDeposit: DST_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowDst(immutables);
        const dstClone = await ethers.getContractAt('EscrowDstZkSync', predictedAddress, accounts.bob);

        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.createDstEscrow(immutables, srcCancellationTimestamp, { value: DST_SAFETY_DEPOSIT, gasLimit: '2000000000' });

        const balanceBeforeBob = await tokens.dai.balanceOf(accounts.bob.address);
        const balanceBeforeBobNative = await provider.getBalance(accounts.bob.address);
        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(TAKING_AMOUNT);
        expect(await provider.getBalance(predictedAddress)).to.equal(DST_SAFETY_DEPOSIT);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.cancellation)]);
        await dstClone.cancel(immutables);
        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(0);
        expect(await tokens.dai.balanceOf(accounts.bob.address)).to.equal(balanceBeforeBob + TAKING_AMOUNT);
        expect(await provider.getBalance(predictedAddress)).to.equal(0);
        expect(await provider.getBalance(accounts.bob.address)).to.be.gt(balanceBeforeBobNative);
    });

    it('should rescue extra tokens on the destination chain', async function () {
        const { accounts, contracts, tokens, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const srcCancellationTimestamp = blockTimestamp + RESCUE_DELAY;
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.dai.getAddress(),
            amount: TAKING_AMOUNT,
            safetyDeposit: DST_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowDst(immutables);
        const dstClone = await ethers.getContractAt('EscrowDstZkSync', predictedAddress, accounts.bob);

        await accounts.bob.sendTransaction({ to: predictedAddress, value: DST_SAFETY_DEPOSIT });
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.createDstEscrow(immutables, srcCancellationTimestamp, { value: DST_SAFETY_DEPOSIT, gasLimit: '2000000000' });

        const balanceBeforeBob = await tokens.dai.balanceOf(accounts.bob.address);
        let balanceBeforeBobNative = await provider.getBalance(accounts.bob.address);
        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(TAKING_AMOUNT);
        expect(await provider.getBalance(predictedAddress)).to.equal(DST_SAFETY_DEPOSIT * 2n);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.cancellation)]);
        await dstClone.cancel(immutables);
        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(0);
        expect(await tokens.dai.balanceOf(accounts.bob.address)).to.equal(balanceBeforeBob + TAKING_AMOUNT);
        expect(await provider.getBalance(predictedAddress)).to.equal(DST_SAFETY_DEPOSIT);
        expect(await provider.getBalance(accounts.bob.address)).to.be.gt(balanceBeforeBobNative);

        balanceBeforeBobNative = await provider.getBalance(accounts.bob.address);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) + RESCUE_DELAY]);
        await dstClone.rescueFunds(ethers.ZeroAddress, DST_SAFETY_DEPOSIT, immutables);
        expect(await provider.getBalance(predictedAddress)).to.equal(0);
        expect(await provider.getBalance(accounts.bob.address)).to.be.gt(balanceBeforeBobNative);
    });
});
