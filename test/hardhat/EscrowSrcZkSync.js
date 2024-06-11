const hre = require('hardhat');
const { ethers } = hre;
const { expect } = require('chai');

const { Wallet, Provider } = require('zksync-ethers');
const { Deployer } = require('@matterlabs/hardhat-zksync-deploy');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { buildMakerTraits, buildOrder, buildOrderData } = require('@1inch/limit-order-protocol-contract/test/helpers/orderUtils');
const { ether, trim0x } = require('@1inch/solidity-utils');

describe('EscrowSrcZkSync', function () {
    const RESCUE_DELAY = 604800; // 7 days
    const SECRET = ethers.keccak256(ethers.toUtf8Bytes('secret'));
    const HASHLOCK = ethers.keccak256(SECRET);
    const MAKING_AMOUNT = ether('0.3');
    const TAKING_AMOUNT = ether('0.5');
    const SRC_SAFETY_DEPOSIT = ether('0.03');
    const DST_SAFETY_DEPOSIT = ether('0.05');
    const RESOLVER_FEE = 100;
    const abiCoder = ethers.AbiCoder.defaultAbiCoder();
    const provider = Provider.getDefaultProvider();
    const timestamps = { withdrawal: 120n, publicWithdrawal: 500n, cancellation: 1020n, publicCancellation: 1130n };
    const basicTimelocks = (timestamps.withdrawal << 32n) |
        (timestamps.publicWithdrawal << 64n) |
        (timestamps.cancellation << 96n) |
        (timestamps.publicCancellation << 128n);

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

        const FeeBank = await deployer.loadArtifact('FeeBank');
        const feeBank = new ethers.Contract(await escrowFactory.FEE_BANK(), FeeBank.abi, bob);

        const contracts = { limitOrderProtocol, escrowFactory, feeBank };

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
        await tokens.inch.approve(contracts.feeBank, ether('1000'));
        await contracts.feeBank.deposit(ether('10'));

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

    async function buldDynamicData ({ chainId, token, timelocks }) {
        const data = abiCoder.encode(
            ['bytes32', 'uint256', 'address', 'uint256', 'uint256'],
            [HASHLOCK, chainId, token, SRC_SAFETY_DEPOSIT << 128n | DST_SAFETY_DEPOSIT, timelocks],
        );
        return { data };
    }

    it('should not withdraw tokens with invalid immutables', async function () {
        const { accounts, contracts, tokens, chainId, order, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;
        const { data: extraData } = await buldDynamicData({
            chainId,
            token: await tokens.dai.getAddress(),
            timelocks,
        });

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.usdc.getAddress(),
            amount: MAKING_AMOUNT,
            safetyDeposit: SRC_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowSrc(immutables);

        await tokens.usdc.transfer(predictedAddress, MAKING_AMOUNT);
        await accounts.bob.sendTransaction({ to: predictedAddress, value: SRC_SAFETY_DEPOSIT });

        const whitelist = ethers.solidityPacked(
            ['uint32', 'bytes10', 'uint16'],
            [blockTimestamp - time.duration.minutes(5), '0x' + (accounts.bob.address).substring(22), 0],
        );

        const extraDataInt = '0x' + trim0x(extraData) + RESOLVER_FEE.toString(16).padStart(8, '0') + trim0x(whitelist) + '09';

        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.postInteraction(
            order,
            '0x', // extension
            orderHash,
            accounts.bob.address, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraDataInt,
            { gasLimit: '2000000000' },
        );
        const srcClone = await ethers.getContractAt('EscrowSrcZkSync', predictedAddress, accounts.bob);

        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(MAKING_AMOUNT);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.withdrawal)]);
        immutables.amount = MAKING_AMOUNT + 1n;
        await expect(srcClone.withdraw(SECRET, immutables)).to.be.revertedWithCustomError(srcClone, 'InvalidImmutables');
    });

    it('should withdraw tokens on the source chain', async function () {
        // TODO: is it possible to create a fixture?
        const { accounts, contracts, tokens, chainId, order, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;
        const { data: extraData } = await buldDynamicData({
            chainId,
            token: await tokens.dai.getAddress(),
            timelocks,
        });

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.usdc.getAddress(),
            amount: MAKING_AMOUNT,
            safetyDeposit: SRC_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowSrc(immutables);

        await tokens.usdc.transfer(predictedAddress, MAKING_AMOUNT);
        await accounts.bob.sendTransaction({ to: predictedAddress, value: SRC_SAFETY_DEPOSIT });

        const whitelist = ethers.solidityPacked(
            ['uint32', 'bytes10', 'uint16'],
            [blockTimestamp - time.duration.minutes(5), '0x' + (accounts.bob.address).substring(22), 0],
        );

        const extraDataInt = '0x' + trim0x(extraData) + RESOLVER_FEE.toString(16).padStart(8, '0') + trim0x(whitelist) + '09';

        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.postInteraction(
            order,
            '0x', // extension
            orderHash,
            accounts.bob.address, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraDataInt,
            { gasLimit: '2000000000' },
        );
        const srcClone = await ethers.getContractAt('EscrowSrcZkSync', predictedAddress, accounts.bob);

        const balanceBeforeBob = await tokens.usdc.balanceOf(accounts.bob.address);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(MAKING_AMOUNT);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.withdrawal)]);
        await srcClone.withdraw(SECRET, immutables);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(0);
        expect(await tokens.usdc.balanceOf(accounts.bob.address)).to.equal(balanceBeforeBob + MAKING_AMOUNT);
    });

    it('should cancel escrow on the source chain by the resolver', async function () {
        const { accounts, contracts, tokens, chainId, order, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;
        const { data: extraData } = await buldDynamicData({
            chainId,
            token: await tokens.dai.getAddress(),
            timelocks,
        });

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.usdc.getAddress(),
            amount: MAKING_AMOUNT,
            safetyDeposit: SRC_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowSrc(immutables);

        await tokens.usdc.transfer(predictedAddress, MAKING_AMOUNT);
        await accounts.bob.sendTransaction({ to: predictedAddress, value: SRC_SAFETY_DEPOSIT });

        const whitelist = ethers.solidityPacked(
            ['uint32', 'bytes10', 'uint16'],
            [blockTimestamp - time.duration.minutes(5), '0x' + (accounts.bob.address).substring(22), 0],
        );

        const extraDataInt = '0x' + trim0x(extraData) + RESOLVER_FEE.toString(16).padStart(8, '0') + trim0x(whitelist) + '09';

        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.postInteraction(
            order,
            '0x', // extension
            orderHash,
            accounts.bob.address, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraDataInt,
            { gasLimit: '2000000000' },
        );
        const srcClone = await ethers.getContractAt('EscrowSrcZkSync', predictedAddress, accounts.bob);

        const balanceBeforeAlice = await tokens.usdc.balanceOf(accounts.alice.address);
        const balanceBeforeBob = await provider.getBalance(accounts.bob);

        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(MAKING_AMOUNT);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.cancellation)]);
        await srcClone.cancel(immutables);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(0);
        expect(await provider.getBalance(predictedAddress)).to.equal(0);
        expect(await tokens.usdc.balanceOf(accounts.alice.address)).to.equal(balanceBeforeAlice + MAKING_AMOUNT);
        expect(await provider.getBalance(accounts.bob)).to.be.gt(balanceBeforeBob);
    });

    it('should cancel escrow on the source chain by anyone', async function () {
        const { accounts, contracts, tokens, chainId, order, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;
        const { data: extraData } = await buldDynamicData({
            chainId,
            token: await tokens.dai.getAddress(),
            timelocks,
        });

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.usdc.getAddress(),
            amount: MAKING_AMOUNT,
            safetyDeposit: SRC_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowSrc(immutables);

        await tokens.usdc.transfer(predictedAddress, MAKING_AMOUNT);
        await accounts.bob.sendTransaction({ to: predictedAddress, value: SRC_SAFETY_DEPOSIT });

        const whitelist = ethers.solidityPacked(
            ['uint32', 'bytes10', 'uint16'],
            [blockTimestamp - time.duration.minutes(5), '0x' + (accounts.bob.address).substring(22), 0],
        );

        const extraDataInt = '0x' + trim0x(extraData) + RESOLVER_FEE.toString(16).padStart(8, '0') + trim0x(whitelist) + '09';

        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.postInteraction(
            order,
            '0x', // extension
            orderHash,
            accounts.bob.address, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraDataInt,
            { gasLimit: '2000000000' },
        );
        const srcClone = await ethers.getContractAt('EscrowSrcZkSync', predictedAddress, accounts.bob);

        const balanceBeforeAlice = await tokens.usdc.balanceOf(accounts.alice.address);
        const balanceBeforeAliceNative = await provider.getBalance(accounts.alice);

        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(MAKING_AMOUNT);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.publicCancellation)]);
        await srcClone.connect(accounts.alice).publicCancel(immutables);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(0);
        expect(await provider.getBalance(predictedAddress)).to.equal(0);
        expect(await tokens.usdc.balanceOf(accounts.alice.address)).to.equal(balanceBeforeAlice + MAKING_AMOUNT);
        expect(await provider.getBalance(accounts.alice)).to.be.gt(balanceBeforeAliceNative);
    });

    it('should rescue extra tokens on the source chain', async function () {
        const { accounts, contracts, tokens, chainId, order, orderHash } = await initContracts();

        const blockTimestamp = await provider.send('config_getCurrentTimestamp', []);
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        const timelocks = newTimestamp | basicTimelocks;
        const { data: extraData } = await buldDynamicData({
            chainId,
            token: await tokens.dai.getAddress(),
            timelocks,
        });

        const immutables = {
            orderHash,
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.usdc.getAddress(),
            amount: MAKING_AMOUNT,
            safetyDeposit: SRC_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowSrc(immutables);

        await tokens.usdc.transfer(predictedAddress, MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);
        await accounts.bob.sendTransaction({ to: predictedAddress, value: SRC_SAFETY_DEPOSIT });

        const whitelist = ethers.solidityPacked(
            ['uint32', 'bytes10', 'uint16'],
            [blockTimestamp - time.duration.minutes(5), '0x' + (accounts.bob.address).substring(22), 0],
        );

        const extraDataInt = '0x' + trim0x(extraData) + RESOLVER_FEE.toString(16).padStart(8, '0') + trim0x(whitelist) + '09';

        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.postInteraction(
            order,
            '0x', // extension
            orderHash,
            accounts.bob.address, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraDataInt,
            { gasLimit: '2000000000' },
        );
        const srcClone = await ethers.getContractAt('EscrowSrcZkSync', predictedAddress, accounts.bob);

        const balanceBeforeAlice = await tokens.usdc.balanceOf(accounts.alice.address);
        let balanceBeforeBob = await provider.getBalance(accounts.bob);

        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp + timestamps.cancellation)]);
        await srcClone.cancel(immutables);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(SRC_SAFETY_DEPOSIT);
        expect(await provider.getBalance(predictedAddress)).to.equal(0);
        expect(await tokens.usdc.balanceOf(accounts.alice.address)).to.equal(balanceBeforeAlice + MAKING_AMOUNT);
        expect(await provider.getBalance(accounts.bob)).to.be.gt(balanceBeforeBob);

        balanceBeforeBob = await tokens.usdc.balanceOf(accounts.bob.address);
        await provider.send('evm_setNextBlockTimestamp', [Number(newTimestamp) + RESCUE_DELAY]);
        await srcClone.rescueFunds(await tokens.usdc.getAddress(), SRC_SAFETY_DEPOSIT, immutables);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(0);
        expect(await tokens.usdc.balanceOf(accounts.bob.address)).to.equal(balanceBeforeBob + SRC_SAFETY_DEPOSIT);
    });
});
