// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}
