// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IEscrowDst } from "contracts/interfaces/IEscrowDst.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { ImmutablesLibProxy } from "../utils/ImmutablesLibProxy.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";

contract ImmutablesLibTest is BaseSetup {
    ImmutablesLibProxy internal _immutablesProxy;

    function setUp() public virtual override {
        BaseSetup.setUp();

        _immutablesProxy = new ImmutablesLibProxy();
    }

    /* solhint-disable func-name-mixedcase */
    function test_hashes() public {
        (IEscrowDst.ImmutablesDst memory immutablesDst,,) = _prepareDataDst();
        
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(false, false);
        IBaseEscrow.Immutables memory immutablesSrc = swapData.immutables;
        IBaseEscrow.Immutables memory immutablesSrcFromDst = IBaseEscrow.Immutables({
            orderHash: immutablesDst.orderHash,
            amount: immutablesDst.amount,
            maker: immutablesDst.maker,
            taker: immutablesDst.taker,
            token: immutablesDst.token,
            hashlock: immutablesDst.hashlock,
            safetyDeposit: immutablesDst.safetyDeposit,
            timelocks: immutablesDst.timelocks
        });

        (bytes32 hashSrc, bytes32 hashDst) = _immutablesProxy.hashes(immutablesSrcFromDst, immutablesDst);
        assertEq(hashSrc, hashDst);

        // comparing calldata hash() and hashMem()
        assertEq(_immutablesProxy.hash(immutablesDst), ImmutablesLib.hashMem(immutablesDst));
        assertEq(_immutablesProxy.hash(immutablesSrc), ImmutablesLib.hashMem(immutablesSrc));
    }

    /* solhint-enable func-name-mixedcase */
}