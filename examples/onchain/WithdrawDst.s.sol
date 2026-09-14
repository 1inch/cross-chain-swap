// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { IResolverExample } from "contracts/interfaces/IResolverExample.sol";
import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

import { FeeCalcLib } from "test/utils/libraries/FeeCalcLib.sol";

contract WithdrawDst is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
        IResolverExample resolver = IResolverExample(vm.envAddress("RESOLVER"));
        address dstToken = address(0); // ETH
        bytes32 orderHash = vm.envBytes32("ORDER_HASH");
        Timelocks timelocks = Timelocks.wrap(vm.envUint("TIMELOCKS"));
        uint256 deployedAt = vm.envUint("DEPLOYED_AT");
        address protocolFeeRecipient = vm.envAddress("PROTOCOL_FEE_RECIPIENT");
        address integratorFeeRecipient = vm.envAddress("INTEGRATOR_FEE_RECIPIENT");
        uint256 protocolFee = vm.envUint("PROTOCOL_FEE");
        uint256 integratorFee = vm.envUint("INTEGRATOR_FEE");
        uint256 integratorShare = vm.envUint("INTEGRATOR_SHARE");

        timelocks = TimelocksLib.setDeployedAt(timelocks, deployedAt);
        bytes32 secret = keccak256(abi.encodePacked("secret"));
        bytes32 hashlock = keccak256(abi.encode(secret));
        uint256 dstAmount = 1; // 1 USDC
        uint256 safetyDeposit = 1;

        (uint256 integratorFeeAmount, uint256 protocolFeeAmount) = FeeCalcLib.getFeeAmounts(
            dstAmount,
            protocolFee,
            integratorFee,
            integratorShare
        );

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            amount: dstAmount,
            maker: Address.wrap(uint160(deployer)),
            taker: Address.wrap(uint160(address(resolver))),
            token: Address.wrap(uint160(dstToken)),
            hashlock: hashlock,
            safetyDeposit: safetyDeposit,
            timelocks: timelocks,
            parameters: abi.encode(
                protocolFeeAmount,
                integratorFeeAmount,
                Address.wrap(uint160(protocolFeeRecipient)),
                Address.wrap(uint160(integratorFeeRecipient))
            )
        });

        address escrow = vm.envAddress("ESCROW_DST");
        // address escrow = IEscrowFactory(escrowFactory).addressOfEscrowDst(immutables);

        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = escrow;
        data[0] = abi.encodeWithSelector(IBaseEscrow(escrow).withdraw.selector, secret, immutables);

        vm.startBroadcast(deployerPK);
        // IBaseEscrow(escrow).withdraw(secret, immutables);
        resolver.arbitraryCalls(targets, data);
        vm.stopBroadcast();
    }
}
