// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";

import { EscrowFactory } from "contracts/EscrowFactory.sol";
import { ResolverExample } from "contracts/mocks/ResolverExample.sol";
import { ERC20TrueBalance } from "contracts/mocks/ERC20TrueBalance.sol";

// solhint-disable no-console
import { console } from "forge-std/console.sol";

contract DeployEscrowFactory is Script {
    uint32 public constant RESCUE_DELAY = 0;

    function run() external {
        IOrderMixin limitOrderProtocol = IOrderMixin(vm.envAddress("LOP"));
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address feeBankOwner = deployer;

        vm.startBroadcast(deployerPK);
        IERC20 accessToken = IERC20(address(new ERC20TrueBalance()));
        IERC20 feeToken = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI Ethereum
        EscrowFactory escrowFactory = new EscrowFactory(
            address(limitOrderProtocol), feeToken, accessToken, feeBankOwner,  RESCUE_DELAY, RESCUE_DELAY
        );
        ResolverExample resolver = new ResolverExample(escrowFactory, limitOrderProtocol, deployer);
        vm.stopBroadcast();

        console.log("Access Token deployed at: ", address(accessToken));
        console.log("Escrow Factory deployed at: ", address(escrowFactory));
        console.log("Resolver deployed at: ", address(resolver));

    }
}
// solhint-enable no-console
