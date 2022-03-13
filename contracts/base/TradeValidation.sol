// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

abstract contract TradeValidation {
    /// @dev returns true if current tick is out of range
    function checkTickRange(
        IUniswapV3Pool pool,
        address tokenIn,
        address tokenOut,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (bool) {
        (, int24 tick, , , , , ) = pool.slot0();

        if (tokenIn < tokenOut) {
            // for a token0->token1 order, return true if current tick is above range
            return tick > tickUpper;
        } else {
            // for a token1->token0 order, return true if current tick is below range
            return tick < tickLower;
        }
    }
}
