// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";

import { Timelocks } from "contracts/libraries/TimelocksLib.sol";
import { IResolverExample } from "contracts/interfaces/IResolverExample.sol";

import { CrossChainTestLib } from "test/utils/libraries/CrossChainTestLib.sol";
import { TimelocksSettersLib } from "test/utils/libraries/TimelocksSettersLib.sol";

contract DeployEscrowSrc is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
        IResolverExample resolver = IResolverExample(vm.envAddress("RESOLVER"));
        address escrowFactory = vm.envAddress("ESCROW_FACTORY");
        IOrderMixin limitOrderProtocol = IOrderMixin(vm.envAddress("LOP"));
        uint40 nonce = uint40(vm.envUint("NONCE"));

        address srcToken = vm.envAddress("TOKEN_SRC");

        // Prepare data to deploy EscrowSrc
        address maker = deployer;
        address dstToken = address(0); // ETH
        uint256 srcAmount = 1; // USDC
        uint256 dstAmount = 1; // ETH
        uint256 safetyDeposit = 1;
        uint32 resolverFee = 0;
        bytes32 secret = keccak256(abi.encodePacked("secret"));
        bytes32 hashlock = keccak256(abi.encode(secret));
        CrossChainTestLib.SrcTimelocks memory srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: 300, // 5min finality lock
            publicWithdrawal: 600, // 5m for private withdrawal
            cancellation: 900, // 5m for public withdrawal
            publicCancellation: 1200 // 5m for private cancellation 
        });
        CrossChainTestLib.DstTimelocks memory dstTimelocks = CrossChainTestLib.DstTimelocks({
            withdrawal: 300, // 5min finality lock for test
            publicWithdrawal: 600, // 5m for private withdrawal
            cancellation: 900 // 5m for public withdrawal
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
        resolvers[0] = address(resolver);
        CrossChainTestLib.SwapData memory swapData = CrossChainTestLib.prepareDataSrc(
            CrossChainTestLib.OrderDetails({
                maker: maker,
                receiver: address(0),
                srcToken: srcToken,
                dstToken: dstToken,
                srcAmount: srcAmount,
                dstAmount: dstAmount,
                srcSafetyDeposit: safetyDeposit,
                dstSafetyDeposit: safetyDeposit,
                resolvers: resolvers,
                resolverFee: resolverFee,
                auctionDetails: CrossChainTestLib.buildAuctionDetails(
                    0, // gasBumpEstimate
                    0, // gasPriceEstimate
                    0, // startTime
                    0, // duration: 10 minutes
                    0, // delay
                    0, // initialRateBump
                    "" // auctionPoints
                ),
                nonce: nonce
            }),
            CrossChainTestLib.EscrowDetails({
                hashlock: hashlock,
                timelocks: timelocks,
                fakeOrder: false,
                allowMultipleFills: false
            }),
            escrowFactory,
            limitOrderProtocol
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPK, swapData.orderHash);
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
        
        vm.startBroadcast(deployerPK);
        IERC20(srcToken).approve(address(limitOrderProtocol), srcAmount);
        resolver.deploySrc(
            swapData.immutables,
            swapData.order,
            r,
            vs,
            srcAmount,
            takerTraits,
            args
        );
        vm.stopBroadcast();
    }
}
