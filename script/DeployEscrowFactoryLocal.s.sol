// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { EscrowFactory } from "contracts/EscrowFactory.sol";

// solhint-disable no-console
import { console } from "forge-std/console.sol";

contract DeployEscrowFactoryLocal is Script {
    uint32 public constant RESCUE_DELAY = 691200; // 8 days
    
    // These are the same addresses used in the original script
    address public constant LOP = 0x111111125421cA6dc452d289314280a0f8842A65; // All chains
    address public constant ACCESS_TOKEN = 0xACCe550000159e70908C0499a1119D04e7039C28; // All chains
    
    function run() external {
        // For Base mainnet fork
        address feeToken = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // Base (DAI)
        
        // Use the first Anvil account as deployer/owner
        address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        address feeBankOwner = deployer;

        vm.startBroadcast();
        
        // Direct deployment without CREATE3
        EscrowFactory escrowFactory = new EscrowFactory(
            LOP, 
            IERC20(feeToken), 
            IERC20(ACCESS_TOKEN), 
            feeBankOwner, 
            RESCUE_DELAY, 
            RESCUE_DELAY
        );
        
        vm.stopBroadcast();

        console.log("Escrow Factory deployed at: ", address(escrowFactory));
        console.log("Deployed by: ", deployer);
        console.log("Fee token: ", feeToken);
        console.log("Access token: ", ACCESS_TOKEN);
        console.log("LOP: ", LOP);
    }
}
// solhint-enable no-console