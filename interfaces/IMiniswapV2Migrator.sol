// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

interface IMiniswapV2Migrator {
    function migrate(address token, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external;
}
