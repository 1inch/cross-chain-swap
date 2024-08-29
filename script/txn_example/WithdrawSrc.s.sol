// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IResolverExample } from "contracts/interfaces/IResolverExample.sol";
import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

contract WithdrawSrc is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
        IResolverExample resolver = IResolverExample(vm.envAddress("RESOLVER"));
        address escrowFactory = vm.envAddress("ESCROW_FACTORY");
        address srcToken = vm.envAddress("TOKEN_SRC");
        bytes32 orderHash = vm.envBytes32("ORDER_HASH");
        Timelocks timelocks = Timelocks.wrap(vm.envUint("TIMELOCKS"));
        uint256 deployedAt = vm.envUint("DEPLOYED_AT");

        timelocks = TimelocksLib.setDeployedAt(timelocks, deployedAt);
        bytes32 secret = keccak256(abi.encodePacked("secret"));
        bytes32 hashlock = keccak256(abi.encode(secret));
        uint256 srcAmount = 1; // 1 USDC
        uint256 safetyDeposit = 1;

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            amount: srcAmount,
            maker: Address.wrap(uint160(deployer)),
            taker: Address.wrap(uint160(address(resolver))),
            token: Address.wrap(uint160(srcToken)),
            hashlock: hashlock,
            safetyDeposit: safetyDeposit,
            timelocks: timelocks
        });

        // address escrow = vm.envAddress("ESCROW_SRC");
        address escrow = IEscrowFactory(escrowFactory).addressOfEscrowSrc(immutables);

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
