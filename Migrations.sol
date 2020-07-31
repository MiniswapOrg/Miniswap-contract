// SPDX-License-Identifier: MIT
// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  constructor() public {
    owner = msg.sender;
  }

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }
}
