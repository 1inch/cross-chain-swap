// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";

import { Timelocks } from "contracts/libraries/TimelocksLib.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { IResolverExample } from "contracts/interfaces/IResolverExample.sol";

import { FeeCalcLib } from "test/utils/libraries/FeeCalcLib.sol";

import { CrossChainTestLib } from "test/utils/libraries/CrossChainTestLib.sol";

contract DeployEscrowDst is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
        IResolverExample resolver = IResolverExample(vm.envAddress("RESOLVER"));
        bytes32 orderHash = vm.envBytes32("ORDER_HASH");
        Timelocks timelocks = Timelocks.wrap(vm.envUint("TIMELOCKS"));
        address protocolFeeRecipient = vm.envAddress("PROTOCOL_FEE_RECIPIENT");
        address integratorFeeRecipient = vm.envAddress("INTEGRATOR_FEE_RECIPIENT");
        uint256 protocolFee = vm.envUint("PROTOCOL_FEE");
        uint256 integratorFee = vm.envUint("INTEGRATOR_FEE");
        uint256 integratorShare = vm.envUint("INTEGRATOR_SHARE");

        // Prepare data to deploy escrow
        address maker = deployer;
        address dstToken = address(0); // ETH
        uint256 dstAmount = 1; // ETH
        uint256 safetyDeposit = 1;
        bytes32 secret = keccak256(abi.encodePacked("secret"));
        bytes32 hashlock = keccak256(abi.encode(secret));

        (uint256 integratorFeeAmount, uint256 protocolFeeAmount) = FeeCalcLib.getFeeAmounts(
            dstAmount,
            protocolFee,
            integratorFee,
            integratorShare
        );

        IBaseEscrow.Immutables memory escrowImmutables = CrossChainTestLib.buildDstEscrowImmutables(
            orderHash,
            hashlock,
            dstAmount,
            maker,
            address(resolver),
            dstToken,
            safetyDeposit,
            timelocks,
            protocolFeeRecipient,
            integratorFeeRecipient,
            protocolFeeAmount,
            integratorFeeAmount
        );

        uint256 srcCancellationTimestamp = type(uint32).max;

        {
            vm.startBroadcast(deployerPK);
            resolver.deployDst{ value: dstAmount + safetyDeposit }(
                escrowImmutables,
                srcCancellationTimestamp
            );
            vm.stopBroadcast();
        }
    }
}
