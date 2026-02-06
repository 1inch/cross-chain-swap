// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { EscrowFactory } from "contracts/EscrowFactory.sol";

import { Config } from "./utils/Config.sol";

// solhint-disable no-console
import { console2 } from "forge-std/console2.sol";

contract DeployEscrowFactoryZkSync is Script {
    using Config for *;
    uint32 public constant RESCUE_DELAY = 691200; // 8 days

    function run() external {
        (
            address lopAddress, 
            address accessToken, , , 
            address factoryOwner
        ) = vm.readEscrowFactoryParameters(false);

        vm.startBroadcast();
        EscrowFactory escrowFactory = new EscrowFactory(
            lopAddress,
            IERC20(accessToken),
            factoryOwner,
            RESCUE_DELAY,
            RESCUE_DELAY
        );

        // No need to deploy a separate factory for zkSync, as zkSync can use now regular solc compiled contracts.
        // EscrowFactoryZkSync escrowFactory = new EscrowFactoryZkSync(
        //     lopAddress,
        //     IERC20(accessToken),
        //     factoryOwner,
        //     RESCUE_DELAY,
        //     RESCUE_DELAY
        // );
        vm.stopBroadcast();

        console2.log("Escrow Factory deployed at: ", address(escrowFactory));
    }
}
// solhint-enable no-console
