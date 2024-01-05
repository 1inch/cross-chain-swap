// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Escrow, IEscrow } from "contracts/Escrow.sol";
import { IEscrowFactory } from "contracts/EscrowFactory.sol";

import { BaseSetup, IOrderMixin, LimitOrderProtocol, TakerTraits } from "../../utils/BaseSetup.sol";

contract IntegrationEscrowFactoryTest is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMakerInt(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            Escrow srcClone
        ) = _prepareDataSrc(secret, srcAmount, dstAmount);

        // TODO: build args
        bytes memory args = "";

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        // TODO: build taker traits
        TakerTraits takerTraits = _buildTakerTraits();

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            srcAmount, // amount
            takerTraits,
            args
        );

        // TODO: This call reverts because the escrow is not deployed.
        // To fix this, correct args must be built and passed to fillOrderArgs.
        IEscrow.SrcEscrowImmutables memory returnedImmutables = srcClone.srcEscrowImmutables();
        // assertEq(returnedImmutables.extraDataParams.hashlock, uint256(keccak256(abi.encodePacked(secret))));
        // assertEq(returnedImmutables.interactionParams.srcAmount, srcAmount);
        // assertEq(returnedImmutables.extraDataParams.dstToken, address(dai));
    }

    /* solhint-enable func-name-mixedcase */
}
