const hre = require('hardhat');
const { ethers } = hre;
const { expect } = require('chai');

const { Wallet, Provider } = require('zksync-ethers');
const { Deployer } = require('@matterlabs/hardhat-zksync-deploy');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { buildMakerTraits, buildOrder, buildTakerTraits, buildOrderData, signOrder } = require('@1inch/limit-order-protocol-contract/test/helpers/orderUtils');
const { ether, trim0x } = require('@1inch/solidity-utils');

describe('EscrowFactory', function () {
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

    async function deployContracts () {
        const alice = new Wallet(process.env.ZKSYNC_TEST_PRIVATE_KEY_0, provider);
        const bob = new Wallet(process.env.ZKSYNC_TEST_PRIVATE_KEY_1, provider);
        const accounts = { alice, bob };
        const deployer = new Deployer(hre, bob);

        const TokenMock = await deployer.loadArtifact('TokenMock');
        const dai = await deployer.deploy(TokenMock, ['DAI', 'DAI'], { gasLimit: '2000000000' });
        await dai.waitForDeployment();
        const TokenCustomDecimalsMock = await deployer.loadArtifact('TokenCustomDecimalsMock');
        const usdc = await deployer.deploy(TokenCustomDecimalsMock, ['USDC', 'USDC', ether('1000').toString(), 6]);
        await usdc.waitForDeployment();
        const inch = await deployer.deploy(TokenMock, ['1INCH', '1INCH']);
        await inch.waitForDeployment();
        const ERC20True = await deployer.loadArtifact('ERC20True');
        const erc20t = await deployer.deploy(ERC20True);
        await erc20t.waitForDeployment();
        const tokens = { dai, usdc, inch, erc20t };

        const LimitOrderProtocol = await deployer.loadArtifact('LimitOrderProtocol');
        const limitOrderProtocol = await deployer.deploy(LimitOrderProtocol, [await inch.getAddress()]);
        await limitOrderProtocol.waitForDeployment();

        const EscrowFactory = await deployer.loadArtifact('EscrowFactoryZkSync');
        const escrowFactory = await deployer.deploy(EscrowFactory, [await limitOrderProtocol.getAddress(), inch.target, RESCUE_DELAY, RESCUE_DELAY]);
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
        await tokens.usdc.mint(accounts.alice.address, ether('1000'));
        await tokens.inch.mint(accounts.bob.address, ether('1000'));

        await tokens.dai.approve(contracts.escrowFactory, ether('1'));
        await tokens.usdc.connect(accounts.alice).approve(await contracts.limitOrderProtocol.getAddress(), ether('1'));
        await tokens.inch.approve(contracts.feeBank, ether('1000'));
        await contracts.feeBank.deposit(ether('10'));

        return { accounts, contracts, tokens, chainId };
    }

    async function buldDynamicData({ chainId, token, timelocks }) {
        const data = abiCoder.encode(
            ['bytes32', 'uint256', 'address', 'uint256', 'uint256'],
            [HASHLOCK, chainId, token, SRC_SAFETY_DEPOSIT << 128n | DST_SAFETY_DEPOSIT, timelocks],
        );
        return { data };
    }

    it('should deploy escrow on the source chain', async function () {
        // TODO: is it possible to create a fixture?
        const { accounts, contracts, tokens, chainId } = await initContracts();

        const blockTimestamp = await provider.send("config_getCurrentTimestamp", []);
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        // set SrcCancellation to 1000 seconds
        const timelocks = newTimestamp | (1000n << 64n);
        const { data: extraData } = await buldDynamicData({
            chainId,
            token: await tokens.dai.getAddress(),
            timelocks,
        });
        const whitelist = ethers.solidityPacked(
            ['uint32', 'bytes10', 'uint16'],
            [blockTimestamp - time.duration.minutes(5), '0x' + (accounts.bob.address).substring(22), 0],
        );
        const postIntData = '0x' + trim0x(extraData) + RESOLVER_FEE.toString(16).padStart(8, '0') + trim0x(whitelist) + '09';
        const order = buildOrder(
            {
                makerAsset: await tokens.usdc.getAddress(),
                takerAsset: await tokens.erc20t.getAddress(),
                makingAmount: MAKING_AMOUNT,
                takingAmount: TAKING_AMOUNT,
                maker: accounts.alice.address,
                makerTraits: buildMakerTraits({ allowMultipleFills: false }),
            },
            {
                postInteraction: await contracts.escrowFactory.getAddress() + trim0x(postIntData),
            },
        );

        const data = buildOrderData(chainId, await contracts.limitOrderProtocol.getAddress(), order);
        const orderHash = ethers.TypedDataEncoder.hash(data.domain, data.types, data.value);

        const { r: r, yParityAndS: vs } = ethers.Signature.from(await signOrder(order, chainId, await contracts.limitOrderProtocol.getAddress(), accounts.alice));
        const signature = { r, vs };


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
        await accounts.bob.sendTransaction({ to: predictedAddress, value: SRC_SAFETY_DEPOSIT });

        const takerTraits = buildTakerTraits({
            makingAmount: true,
            target: predictedAddress,
            extension: order.extension,
        });

        const balanceBeforeAlice = await tokens.usdc.balanceOf(accounts.alice.address);
        const balanceBeforePredicted = await tokens.usdc.balanceOf(predictedAddress);
        

        await provider.send("evm_setNextBlockTimestamp", [Number(newTimestamp) - 1]);
        await contracts.limitOrderProtocol.fillOrderArgs(
            order,
            signature.r,
            signature.vs,
            MAKING_AMOUNT, // amount
            takerTraits.traits,
            takerTraits.args,
            { gasLimit: '2000000000' },
        );

        expect(await tokens.usdc.balanceOf(accounts.alice.address)).to.equal(balanceBeforeAlice - MAKING_AMOUNT);
        expect(await tokens.usdc.balanceOf(predictedAddress)).to.equal(balanceBeforePredicted + MAKING_AMOUNT);
    });

    it('should deploy escrow on the destination chain', async function () {
        const { accounts, contracts, tokens } = await initContracts();

        const blockTimestamp = await provider.send("config_getCurrentTimestamp", []);
        const srcCancellationTimestamp = blockTimestamp + 1000000;
        const newTimestamp = BigInt(blockTimestamp) + 100n;
        // set DstCancellation to 1000 seconds
        const timelocks = newTimestamp | (1000n << 192n);

        const immutables = {
            orderHash: ethers.keccak256(ethers.toUtf8Bytes('orderHash')),
            hashlock: HASHLOCK,
            maker: accounts.alice.address,
            taker: accounts.bob.address,
            token: await tokens.dai.getAddress(),
            amount: TAKING_AMOUNT,
            safetyDeposit: DST_SAFETY_DEPOSIT,
            timelocks,
        };

        const predictedAddress = await contracts.escrowFactory.addressOfEscrowDst(immutables);

        await provider.send("evm_setNextBlockTimestamp", [Number(newTimestamp) - 1]);
        await contracts.escrowFactory.createDstEscrow(immutables, srcCancellationTimestamp, { value: DST_SAFETY_DEPOSIT, gasLimit: '2000000000' });

        expect(await tokens.dai.balanceOf(predictedAddress)).to.equal(TAKING_AMOUNT);
    });
});
