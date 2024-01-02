// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";

import { TokenCustomDecimalsMock } from "solidity-utils/contracts/mocks/TokenCustomDecimalsMock.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";

import { Escrow, IEscrow } from "../../contracts/Escrow.sol";
import { EscrowFactory, IEscrowFactory } from "../../contracts/EscrowFactory.sol";

import { Utils } from "./Utils.sol";

contract BaseSetup is Test {
    /* solhint-disable private-vars-leading-underscore */
    bytes32 internal constant SECRET = keccak256(abi.encodePacked("secret"));
    uint256 internal constant TAKING_AMOUNT = 0.5 ether;
    uint256 internal constant SAFETY_DEPOSIT = 0.05 ether;

    Utils internal utils;
    address payable[] internal users;

    address internal alice;
    address internal bob;

    TokenMock internal dai;
    TokenCustomDecimalsMock internal usdc;

    address internal limitOrderProtocol;
    EscrowFactory internal escrowFactory;
    Escrow internal escrow;

    IEscrow.SrcTimelocks internal srcTimelocks = IEscrow.SrcTimelocks({
        finality: 120,
        publicUnlock: 900
    });
    IEscrow.DstTimelocks internal dstTimelocks = IEscrow.DstTimelocks({
        finality: 300,
        unlock: 240,
        publicUnlock: 360
    });
    /* solhint-enable private-vars-leading-underscore */

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(2);

        alice = users[0];
        vm.label(alice, "Alice");
        bob = users[1];
        vm.label(bob, "Bob");

        _deployTokens();
        dai.mint(bob, 1000 ether);
        usdc.mint(alice, 1000 ether);

        _deployContracts();

        vm.prank(bob);
        dai.approve(address(escrowFactory), 1000 ether);
        vm.prank(alice);
        usdc.approve(address(escrowFactory), 1000 ether);
    }

    function _deployTokens() internal {
        dai = new TokenMock("DAI", "DAI");
        vm.label(address(dai), "DAI");
        usdc = new TokenCustomDecimalsMock("USDC", "USDC", 1000 ether, 6);
        vm.label(address(usdc), "USDC");
    }

    function _deployContracts() internal {
        limitOrderProtocol = address(this);
        escrow = new Escrow();
        vm.label(address(escrow), "Escrow");
        escrowFactory = new EscrowFactory(address(escrow), limitOrderProtocol);
        vm.label(address(escrowFactory), "EscrowFactory");
    }

    function _prepareDataDst(bytes32 secret, uint256 amount) internal view returns (
        IEscrowFactory.DstEscrowImmutablesCreation memory,
        Escrow
    ) {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory escrowImmutables,
            bytes memory data
        ) = _buildDstEscrowImmutables(secret, amount);
        address msgSender = bob;
        uint256 deployedAt = block.timestamp;
        bytes32 salt = keccak256(abi.encodePacked(deployedAt, data, msgSender));
        Escrow dstClone = Escrow(escrowFactory.addressOfEscrow(salt));
        return (escrowImmutables, dstClone);
    }

    function _buildDstEscrowImmutables(bytes32 secret, uint256 amount) internal view returns(
        IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
        bytes memory data
    ) {
        uint256 hashlock = uint256(keccak256(abi.encodePacked(secret)));
        uint256 safetyDeposit = amount * 10 / 100;
        uint256 srcCancellationTimestamp = block.timestamp + srcTimelocks.finality + srcTimelocks.publicUnlock;
        immutables = IEscrowFactory.DstEscrowImmutablesCreation({
            hashlock: hashlock,
            maker: alice,
            taker: bob,
            token: address(dai),
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: dstTimelocks,
            srcCancellationTimestamp: srcCancellationTimestamp
        });
        data = abi.encode(
            hashlock,
            alice,
            bob,
            block.chainid,
            address(dai),
            amount,
            safetyDeposit,
            dstTimelocks.finality,
            dstTimelocks.unlock,
            dstTimelocks.publicUnlock
        );
    }
}
