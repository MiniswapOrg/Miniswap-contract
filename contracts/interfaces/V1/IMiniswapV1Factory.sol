// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

interface IMiniswapV1Factory {
    function getExchange(address) external view returns (address);
}
