// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

import "./interfaces/IERC20.sol";

contract TokenTemp {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    function sendTokenTo(address token,address to,uint amount) public{
        require(msg.sender == owner,"forbidden");
        IERC20(token).transfer(to,amount);
    }
}