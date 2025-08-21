// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";

import { ICreate3Deployer } from "solidity-utils/contracts/interfaces/ICreate3Deployer.sol";

import { EscrowFactory } from "contracts/EscrowFactory.sol";

// solhint-disable no-console
import { console } from "forge-std/console.sol";

contract DeployEscrowFactory is Script {
    uint32 public constant RESCUE_DELAY = 691200; // 8 days
    bytes32 public constant CROSSCHAIN_SALT = keccak256("1inch EscrowFactory");
    
    address public constant LOP = 0x111111125421cA6dc452d289314280a0f8842A65; // All chains
    address public constant ACCESS_TOKEN = 0xACCe550000159e70908C0499a1119D04e7039C28; // All chains
    ICreate3Deployer public constant CREATE3_DEPLOYER = ICreate3Deployer(0x65B3Db8bAeF0215A1F9B14c506D2a3078b2C84AE); // All chains

    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address owner = deployer;

        vm.startBroadcast();
        address escrowFactory = CREATE3_DEPLOYER.deploy(
            CROSSCHAIN_SALT,
            abi.encodePacked(
                type(EscrowFactory).creationCode,
                abi.encode(LOP, ACCESS_TOKEN, owner, RESCUE_DELAY, RESCUE_DELAY)
            )
        );
        vm.stopBroadcast();

        console.log("Escrow Factory deployed at: ", escrowFactory);
    }
}
// solhint-enable no-console
