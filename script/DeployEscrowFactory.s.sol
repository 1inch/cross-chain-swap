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

    mapping(uint256 => address) public FEE_TOKEN; // solhint-disable-line var-name-mixedcase
    
    function run() external {
        FEE_TOKEN[1] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // Mainnet (DAI)
        FEE_TOKEN[56] = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3; // BSC (DAI)
        FEE_TOKEN[137] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063; // Polygon (DAI)
        FEE_TOKEN[43114] = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70; // Avalanche (DAI)
        FEE_TOKEN[100] = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d; // Gnosis (wXDAI)
        FEE_TOKEN[42161] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // Arbitrum One (DAI)
        FEE_TOKEN[10] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // Optimism (DAI)
        FEE_TOKEN[8453] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // Base (DAI)

        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address feeBankOwner = deployer;
        address feeToken = FEE_TOKEN[block.chainid];

        vm.startBroadcast();
        address escrowFactory = CREATE3_DEPLOYER.deploy(
            CROSSCHAIN_SALT,
            abi.encodePacked(
                type(EscrowFactory).creationCode,
                abi.encode(LOP, feeToken, ACCESS_TOKEN, feeBankOwner, RESCUE_DELAY, RESCUE_DELAY)
            )
        );
        vm.stopBroadcast();

        console.log("Escrow Factory deployed at: ", escrowFactory);
    }
}
// solhint-enable no-console
