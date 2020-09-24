// SPDX-License-Identifier: SimPL-2.0
pragma solidity =0.6.9;

import "./interfaces/IMiniswapV2Migrator.sol";
import "./interfaces/V1/IMiniswapV1Factory.sol";
import "./interfaces/V1/IMiniswapV1Pair.sol";
import "./interfaces/IMiniswapV2Factory.sol";
import "./interfaces/IMiniswapV2Pair.sol";

contract MiniswapMigrator is IMiniswapMigrator {
    address public factoryV1;
    IMiniswapV2Factory public factoryV2;

    constructor(address _factoryV1, address _factoryV2) public {
        factoryV1 = _factoryV1;
        factoryV2 = IMiniswapV2Factory(_factoryV2);
    }

    function migrate(IMiniswapV1Pair pairV1) external override {
        require(pairV1.factory() == factoryV1, "not from v1 factory");
        address token0 = pairV1.token0();
        address token1 = pairV1.token1();
        IMiniswapV2Pair pairV2 = IMiniswapV2Pair(factoryV2.getPair(token0, token1));
        if (pairV2 == IMiniswapV2Pair(address(0))) {
            pairV2 = IMiniswapV2Pair(factoryV2.createPair(token0, token1));
        }

        uint256 lp = pairV1.balanceOf(msg.sender);
        if (lp == 0) return;

        pairV1.transferFrom(msg.sender, address(pairV1), lp);
        pairV1.burn(address(pairV2));
        pairV2.mint(msg.sender);
    }
}
