// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { ICreate3Deployer } from "limit-order-settlement/contracts/interfaces/ICreate3Deployer.sol";

import { EscrowFactory } from "contracts/EscrowFactory.sol";
import { ResolverExample } from "contracts/mocks/ResolverExample.sol";
import { ERC20TrueBalance } from "contracts/mocks/ERC20TrueBalance.sol";

// solhint-disable no-console
import { console } from "forge-std/console.sol";

contract DeployEscrowFactory is Script {
    uint32 public constant RESCUE_DELAY = 691200; // 8 days
    bytes32 public constant CROSSCHAIN_SALT = keccak256("1inch Cross-Chain");
    
    address public constant LOP = 0x111111125421cA6dc452d289314280a0f8842A65; // All chains
    address public constant ACCESS_TOKEN = 0xACCE5500001E226153D70A6D014CE9ddDc100d42; // All chains
    ICreate3Deployer public constant CREATE3_DEPLOYER = ICreate3Deployer(0x65B3Db8bAeF0215A1F9B14c506D2a3078b2C84AE); // All chains

    mapping(uint256 => address) public FEE_TOKEN;
    
    function run() external {
        FEE_TOKEN[1] = 0x111111111117dC0aa78b770fA6A738034120C302; // Mainnet
        FEE_TOKEN[56] = 0x111111111117dC0aa78b770fA6A738034120C302; // BSC
        FEE_TOKEN[137] = 0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f; // Polygon
        FEE_TOKEN[43114] = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70; // Avalanche (DAI)
        FEE_TOKEN[100] = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d; // Gnosis (wXDAI)
        FEE_TOKEN[42161] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // Arbitrum One (DAI)
        FEE_TOKEN[10] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // Optimism (DAI)
        FEE_TOKEN[8453] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // Base (DAI)

        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address feeBankOwner = deployer;
        address feeToken = FEE_TOKEN[block.chainid];

        vm.startBroadcast(deployerPK);
        CREATE3_DEPLOYER.deploy(
            CROSSCHAIN_SALT,
            abi.encodePacked(
                type(EscrowFactory).creationCode,
                abi.encode(LOP, feeToken, ACCESS_TOKEN, feeBankOwner, RESCUE_DELAY, RESCUE_DELAY)
            )
        );
        vm.stopBroadcast();

        EscrowFactory escrowFactory = EscrowFactory(CREATE3_DEPLOYER.addressOf(CROSSCHAIN_SALT));
        console.log("Escrow Factory deployed at: ", address(escrowFactory));
    }
}
// solhint-enable no-console
