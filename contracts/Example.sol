// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @title Example contract
 * @author ZumZoom
 * @notice Example contract without any meaningful functionality.
 */
contract Example {
    /**
     * @notice Example event
     * @param a Value to log
     */
    event Log(uint256 a);

    /**
     * @notice Example function that is present just to have any function at all.
     * @param a Value that will be logged
     */
    function func(uint256 a) public {
        emit Log(a);
    }
}
