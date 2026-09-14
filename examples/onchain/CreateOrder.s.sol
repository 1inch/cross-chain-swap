// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { Script } from "forge-std/Script.sol";

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";

import { TokenCustomDecimalsMock } from "solidity-utils/contracts/mocks/TokenCustomDecimalsMock.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";
import { BaseEscrowFactory } from "contracts/BaseEscrowFactory.sol";
import { ResolverExample } from "contracts/mocks/ResolverExample.sol";
import { IResolverExample } from "contracts/interfaces/IResolverExample.sol";
import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";

import { CrossChainTestLib } from "test/utils/libraries/CrossChainTestLib.sol";
import { TimelocksSettersLib } from "test/utils/libraries/TimelocksSettersLib.sol";

import { Config, ConfigLib } from "./utils/ConfigLib.sol";
import { EscrowDevOpsTools } from "./utils/EscrowDevOpsTools.sol";

// solhint-disable no-console
import { console } from "forge-std/console.sol";

contract CreateOrder is Script {
    error NativeTokenTransferFailure();
    error InvalidMode();

    enum Mode {
        cancel,
        withdraw
    }
    
    mapping(uint256 => address) public FEE_TOKEN; // solhint-disable-line var-name-mixedcase
    BaseEscrowFactory internal _escrowFactory;
    uint256 internal _deployerPK;
    uint256 internal _makerPK;


    function run() external {
        _defineFeeTokens();

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/examples/config/config.json");

        Config memory config = ConfigLib.getConfig(vm, path);

        _escrowFactory = BaseEscrowFactory(config.escrowFactory);

        _deployerPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
        _makerPK = vm.envUint("MAKER_PRIVATE_KEY");

        string memory mode = vm.envString("MODE");

        if (keccak256(bytes(mode)) == keccak256("deployMocks")) {
            _deployResolverExample(config);
            _replaceTokensForMocks(config);
        } else if (keccak256(bytes(mode)) == keccak256("deployEscrowSrc")) {
            _deployEscrowSrc(config);
        } else if (keccak256(bytes(mode)) == keccak256("deployEscrowDst")) {
            _deployEscrowDst(config);
        } else if (keccak256(bytes(mode)) == keccak256("withdrawSrc")) {
            _callResolverForSrc(config, Mode.withdraw);
        } else if (keccak256(bytes(mode)) == keccak256("withdrawDst")) {
            _callResolverForDst(config, Mode.withdraw);
        } else if (keccak256(bytes(mode)) == keccak256("cancelSrc")) {
            _callResolverForSrc(config, Mode.cancel);
        } else if (keccak256(bytes(mode)) == keccak256("cancelDst")) {
            _callResolverForDst(config, Mode.cancel);
        }
    }

    function _deployEscrowSrc(Config memory config) internal {
        bytes32 secret = keccak256(abi.encodePacked(config.secret));
        bytes32 hashlock = keccak256(abi.encode(secret));

        address srcToken = EscrowDevOpsTools.getSrcToken(config);
        address dstToken = EscrowDevOpsTools.getDstToken(config);
        address resolver = EscrowDevOpsTools.getResolver(config);

        console.log("Src token: %s", srcToken);
        console.log("Dst token: %s", dstToken);
        console.log("Resolver: %s", resolver);

        CrossChainTestLib.SrcTimelocks memory srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: config.withdrawalSrcTimelock, // finality lock
            publicWithdrawal: config.publicWithdrawalSrcTimelock, // for private withdrawal
            cancellation: config.cancellationSrcTimelock, // for public withdrawal
            publicCancellation: config.publicCancellationSrcTimelock // for private cancellation 
        });

        CrossChainTestLib.DstTimelocks memory dstTimelocks = CrossChainTestLib.DstTimelocks({
            withdrawal: config.withdrawalDstTimelock, // finality lock
            publicWithdrawal: config.publicWithdrawalDstTimelock, // for private withdrawal
            cancellation: config.cancellationDstTimelock // for public withdrawal
        });

        Timelocks timelocks = TimelocksSettersLib.init(
            srcTimelocks.withdrawal,
            srcTimelocks.publicWithdrawal,
            srcTimelocks.cancellation,
            srcTimelocks.publicCancellation,
            dstTimelocks.withdrawal,
            dstTimelocks.publicWithdrawal,
            dstTimelocks.cancellation,
            0
        );
    
        address[] memory resolvers = new address[](1);
        resolvers[0] = resolver;

        address maker = config.maker;

        CrossChainTestLib.SwapData memory swapData = CrossChainTestLib.prepareDataSrc(
            CrossChainTestLib.OrderDetails({
                maker: maker,
                receiver: address(0),
                srcToken: srcToken,
                dstToken: dstToken,
                srcAmount: config.srcAmount,
                dstAmount: config.dstAmount,
                srcSafetyDeposit: config.safetyDeposit,
                dstSafetyDeposit: config.safetyDeposit,
                resolvers: resolvers,
                resolverFee: 0,
                auctionDetails: CrossChainTestLib.buildAuctionDetails(
                    0, // gasBumpEstimate
                    0, // gasPriceEstimate
                    0, // startTime
                    0, // duration: 10 minutes
                    0, // delay
                    0, // initialRateBump
                    "" // auctionPoints
                )
            }),
            CrossChainTestLib.EscrowDetails({
                hashlock: hashlock,
                timelocks: timelocks,
                fakeOrder: false,
                allowMultipleFills: false
            }),
            config.escrowFactory,
            IOrderMixin(config.limitOrderProtocol)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_makerPK, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            true, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            swapData.extension, // extension
            "", // interaction
            0 // threshold
        );
        
        _mintToken(srcToken, maker, config.srcAmount);
        _approveTokens(_makerPK, srcToken, config.limitOrderProtocol, config.srcAmount);
        _sendNativeToken(resolver, config.safetyDeposit);

        vm.startBroadcast(uint256(_deployerPK));
        IResolverExample(resolver).deploySrc(
            swapData.immutables,
            swapData.order,
            r,
            vs,
            config.srcAmount,
            takerTraits,
            args
        );
        vm.stopBroadcast();
    }

    function _deployEscrowDst(
        Config memory config
    ) internal {
        bytes32 secret = keccak256(abi.encodePacked(config.secret));
        bytes32 hashlock = keccak256(abi.encode(secret));

        address dstToken = EscrowDevOpsTools.getDstToken(config);
        address srcToken = EscrowDevOpsTools.getSrcToken(config);
        (bytes32 orderHash, Timelocks timelocks) = EscrowDevOpsTools.getOrderHashAndTimelocksFromSrcEscrowCreatedEvent(config);
        address resolver = EscrowDevOpsTools.getResolver(config);

        console.log("Src token: %s", srcToken);
        console.log("Dst token: %s", dstToken);
        console.log("Resolver: %s", resolver);
        console.logBytes32(orderHash);
        console.log(Timelocks.unwrap(timelocks));
        
        IBaseEscrow.Immutables memory escrowImmutables = CrossChainTestLib.buildDstEscrowImmutables(
            orderHash,
            hashlock,
            config.dstAmount,
            config.maker,
            resolver,
            dstToken,
            config.safetyDeposit,
            timelocks
        );

        uint256 srcCancellationTimestamp = type(uint32).max;

        _mintToken(dstToken, resolver, config.dstAmount);
        _sendNativeToken(resolver, config.safetyDeposit);

        uint256 safetyDeposit = config.safetyDeposit;
        if (dstToken == address(0)) {
            safetyDeposit += config.dstAmount; // add safety deposit to the amount if native token
        } else {
            address[] memory targets = new address[](1);
            bytes[] memory arguments = new bytes[](1);
            targets[0] = dstToken;
            arguments[0] = abi.encodePacked(IERC20(dstToken).approve.selector, abi.encode(config.escrowFactory, config.dstAmount));

            vm.startBroadcast(uint256(_deployerPK));
            IResolverExample(resolver).arbitraryCalls(targets, arguments);
            vm.stopBroadcast();
        }

        vm.startBroadcast(uint256(_deployerPK));
        IResolverExample(resolver).deployDst{ value: safetyDeposit }(
            escrowImmutables,
            srcCancellationTimestamp
        );
        vm.stopBroadcast();
    }

    function _callResolverForDst(Config memory config, Mode mode) internal {
        bytes32 secret = keccak256(abi.encodePacked(config.secret));
        bytes32 hashlock = keccak256(abi.encode(secret));

        address dstToken = EscrowDevOpsTools.getDstToken(config);
        (bytes32 orderHash, Timelocks timelocks) = EscrowDevOpsTools.getOrderHashAndTimelocksFromSrcEscrowCreatedEvent(config);
        (address escrow, uint256 deployedAt) = EscrowDevOpsTools.getEscrowDstAddressAndDeployTimeFromDstEscrowCreatedEvent(config);
        address resolver = EscrowDevOpsTools.getResolver(config);

        timelocks = TimelocksLib.setDeployedAt(timelocks, deployedAt);

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            amount: config.dstAmount,
            maker: Address.wrap(uint160(config.maker)),
            taker: Address.wrap(uint160(resolver)),
            token: Address.wrap(uint160(dstToken)),
            hashlock: hashlock,
            safetyDeposit: config.safetyDeposit,
            timelocks: timelocks
        });

        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = escrow;

        if (mode == Mode.cancel) {
            data[0] = abi.encodeWithSelector(IBaseEscrow(escrow).cancel.selector, immutables);
        } else if (mode == Mode.withdraw) {
            data[0] = abi.encodeWithSelector(IBaseEscrow(escrow).withdraw.selector, secret, immutables);
        } else {
            revert InvalidMode();
        }

        vm.startBroadcast(uint256(_deployerPK));
        IResolverExample(resolver).arbitraryCalls(targets, data);
        vm.stopBroadcast();
    }

    function _callResolverForSrc(Config memory config, Mode mode) internal {
        bytes32 secret = keccak256(abi.encodePacked(config.secret));
        bytes32 hashlock = keccak256(abi.encode(secret));

        address srcToken = EscrowDevOpsTools.getSrcToken(config);
        (bytes32 orderHash, Timelocks timelocks) = EscrowDevOpsTools.getOrderHashAndTimelocksFromSrcEscrowCreatedEvent(config);
        address resolver = EscrowDevOpsTools.getResolver(config);

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            amount: config.srcAmount,
            maker: Address.wrap(uint160(config.maker)),
            taker: Address.wrap(uint160(resolver)),
            token: Address.wrap(uint160(srcToken)),
            hashlock: hashlock,
            safetyDeposit: config.safetyDeposit,
            timelocks: timelocks
        });

        address escrow = IEscrowFactory(_escrowFactory).addressOfEscrowSrc(immutables);

        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = escrow;

        if (mode == Mode.cancel) {
            data[0] = abi.encodeWithSelector(IBaseEscrow(escrow).cancel.selector, immutables);
        } else if (mode == Mode.withdraw) {
            data[0] = abi.encodeWithSelector(IBaseEscrow(escrow).withdraw.selector, secret, immutables);
        } else {
            revert InvalidMode();
        }

        vm.startBroadcast(uint256(_deployerPK));
        IResolverExample(resolver).arbitraryCalls(targets, data);
        vm.stopBroadcast();
    }

    function _sendNativeToken(address to, uint256 amount) internal {
        vm.startBroadcast(_deployerPK);
        (bool success,) = to.call{ value: amount }("");
        if (!success) {
            revert NativeTokenTransferFailure();
        }
        vm.stopBroadcast();
    }

    function _approveTokens(uint256 pk, address token, address to, uint256 amount) internal {
        if (token == address(0) || amount == 0) {
            return;
        }
        
        vm.startBroadcast(pk);
        IERC20(token).approve(to, amount);
        vm.stopBroadcast();
    }

    function _mintToken(address token, address to, uint256 amount) internal {
        if (block.chainid != 31337) {
            return;
        }

        vm.startBroadcast(uint256(_deployerPK));
        if (token == address(0)) {
            (bool success,) = to.call{ value: amount }("");
            if (!success) {
                revert NativeTokenTransferFailure();
            }
        } else {
            TokenCustomDecimalsMock(token).mint(to, amount);
        }
        vm.stopBroadcast();

        console.log("Minted %s src tokens for maker: %s", amount, to);
    }

    function _replaceTokensForMocks(Config memory config) internal {
        if (block.chainid != 31337) {
            return;
        }

        if (config.srcToken != address(0)) {
            config.srcToken = _deployMockToken(config, config.srcToken);

            console.log("Mock src token deployed at: %s", config.srcToken);
        }
        
        if (config.dstToken != address(0)) {
            config.dstToken = _deployMockToken(config, config.dstToken);

            console.log("Mock dst token deployed at: %s", config.dstToken);
        }
    }

    function _deployMockToken(
        Config memory config,
        address tokenAddress
    ) internal returns(address) {
        if (block.chainid != 31337) {
            return tokenAddress;
        }

        vm.startBroadcast(uint256(_deployerPK));
        TokenCustomDecimalsMock token = new TokenCustomDecimalsMock(
            ERC20(tokenAddress).name(),
            ERC20(tokenAddress).symbol(), 
            0,
            ERC20(tokenAddress).decimals()
        );

        token.transferOwnership(config.deployer);
        vm.stopBroadcast();

        return address(token);
    }

    function _deployResolverExample(Config memory config) internal {
        if (block.chainid != 31337) {
            return;
        }

        vm.startBroadcast(uint256(_deployerPK));
        new ResolverExample(
            IEscrowFactory(_escrowFactory),
            IOrderMixin(config.limitOrderProtocol),
            config.deployer
        );
        vm.stopBroadcast();
    }

    function _defineFeeTokens() internal {
        FEE_TOKEN[1] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // Mainnet (DAI)
        FEE_TOKEN[56] = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3; // BSC (DAI)
        FEE_TOKEN[137] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063; // Polygon (DAI)
        FEE_TOKEN[43114] = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70; // Avalanche (DAI)
        FEE_TOKEN[100] = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d; // Gnosis (wXDAI)
        FEE_TOKEN[42161] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // Arbitrum One (DAI)
        FEE_TOKEN[10] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // Optimism (DAI)
        FEE_TOKEN[8453] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // Base (DAI)
        FEE_TOKEN[59144] = 0x4AF15ec2A0BD43Db75dd04E62FAA3B8EF36b00d5; // Linea (DAI)
        FEE_TOKEN[146] = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894; // Sonic (USDC)
        FEE_TOKEN[130] = 0x20CAb320A855b39F724131C69424240519573f81; // Unichain (DAI)
        FEE_TOKEN[31337] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // Localhost (DAI)
    }
}