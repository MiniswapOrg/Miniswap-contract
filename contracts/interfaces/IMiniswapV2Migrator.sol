// SPDX-License-Identifier: SimPL-2.0
pragma solidity =0.6.9;
import "./V1/IMiniswapV1Pair.sol";

interface IMiniswapMigrator {
    function migrate(IMiniswapV1Pair pairV1) external;
}
