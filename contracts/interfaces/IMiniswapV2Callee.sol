// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

interface IMiniswapV2Callee {
    function miniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
