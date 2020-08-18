// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

interface IMiniswapCallee {
    function miniswapCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
