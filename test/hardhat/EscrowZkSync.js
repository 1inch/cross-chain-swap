const hre = require('hardhat');
const { ethers } = hre;
const { expect } = require('chai');

const { Wallet, Provider } = require('zksync-ethers');
const { Deployer } = require('@matterlabs/hardhat-zksync-deploy');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { buildMakerTraits, buildOrder, buildOrderData } = require('@1inch/limit-order-protocol-contract/test/helpers/orderUtils');
const { ether, trim0x } = require('@1inch/solidity-utils');

describe('EscrowFactory', function () {
    const RESCUE_DELAY = 604800; // 7 days
    const SECRET = ethers.keccak256(ethers.toUtf8Bytes('secret'));
    const MAKING_AMOUNT = ether('0.3');
    const TAKING_AMOUNT = ether('0.5');
    const SRC_SAFETY_DEPOSIT = ether('0.03');
    const DST_SAFETY_DEPOSIT = ether('0.05');
    const RESOLVER_FEE = 100;
    const abiCoder = ethers.AbiCoder.defaultAbiCoder();
    const provider = Provider.getDefaultProvider();

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
        const escrowFactory = await deployer.deploy(EscrowFactory, [limitOrderProtocol, inch.target, RESCUE_DELAY, RESCUE_DELAY]);
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

        return { accounts, contracts, tokens, chainId };
    }

    async function buldDynamicData({ chainId, token, timelocks }) {
        const hashlock = ethers.keccak256(SECRET);
        const data = abiCoder.encode(
            ['bytes32', 'uint256', 'address', 'uint256', 'uint256'],
            [hashlock, chainId, token, SRC_SAFETY_DEPOSIT << 128n | DST_SAFETY_DEPOSIT, timelocks],
        );
        return { data, hashlock };
    }

    it('should withdraw tokens on the source chain', async function () {
        // TODO: is it possible to create a fixture?
        const { accounts, contracts, tokens, chainId } = await initContracts();

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

        const blockTimestamp = await provider.send("config_getCurrentTimestamp", []);
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        // set SrcCancellation to 1000 seconds
        const timelocks = newTimestamp | (1000n << 64n);
        const { data: extraData, hashlock } = await buldDynamicData({
            chainId,
            token: await tokens.dai.getAddress(),
            timelocks,
        });

        const immutables = {
            orderHash,
            hashlock,
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

        await provider.send("evm_setNextBlockTimestamp", [Number(newTimestamp) - 1]);
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
        )
        const srcClone = await ethers.getContractAt('EscrowSrcZkSync', predictedAddress, accounts.bob);

        const balanceBeforeBob = await tokens.usdc.balanceOf(accounts.bob.address);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(MAKING_AMOUNT);
        await srcClone.withdraw(SECRET, immutables);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(0);
        expect(await tokens.usdc.balanceOf(accounts.bob.address)).to.equal(balanceBeforeBob + MAKING_AMOUNT);

    });
});
