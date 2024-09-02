// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { EscrowFactoryZkSync } from "contracts/zkSync/EscrowFactoryZkSync.sol";

// solhint-disable no-console
import { console } from "forge-std/console.sol";

contract DeployEscrowFactoryZkSync is Script {
    uint32 public constant RESCUE_DELAY = 691200; // 8 days
    address public constant LOP = 0x6fd4383cB451173D5f9304F041C7BCBf27d561fF;
    IERC20 public constant ACCESS_TOKEN = IERC20(0xC2c4fE863EC835D7DdbFE91Fe33cf1C7Df45Fa7C);
    IERC20 public constant FEE_TOKEN = IERC20(0x4B9eb6c0b6ea15176BBF62841C6B2A8a398cb656); // DAI
    
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address feeBankOwner = deployer;

        vm.startBroadcast();
        EscrowFactoryZkSync escrowFactory = new EscrowFactoryZkSync(
            LOP,
            FEE_TOKEN,
            ACCESS_TOKEN,
            feeBankOwner,
            RESCUE_DELAY,
            RESCUE_DELAY
        );
        vm.stopBroadcast();

        console.log("Escrow Factory deployed at: ", address(escrowFactory));
        console.log("EscrowSrcZkSync deployed at: ", escrowFactory.ESCROW_SRC_IMPLEMENTATION());
        console.log("EscrowSrcZkSync deployed at: ", escrowFactory.ESCROW_DST_IMPLEMENTATION());
    }
}
// solhint-enable no-console
