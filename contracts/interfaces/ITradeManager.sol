// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

interface ITradeManager {
    event SetLimitOrder(
        uint256 indexed tradeId,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    );
    event CancelLimitOrder(uint256 indexed tradeId);

    enum Status {
        OPEN,
        EXECUTED,
        CANCELLED
    }

    function trades(uint256 tradeId)
        external
        view
        returns (
            address operator,
            address tokenIn,
            address tokenOut,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            Status tradeStatus
        );

    struct LimitOrderParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice Creates a new limit order trade
    /// @param params The params necessary to set a limit order, encoded as `LimitOrderParams` in calldata
    /// @return tradeId The ID of the trade
    /// @return liquidity The amount of liquidity for this trade
    /// @return amount0 The amount of tokenIn
    /// @return amount1 The amount of tokenOut
    function set(LimitOrderParams calldata params)
        external
        payable
        returns (
            uint256 tradeId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Cancels limit order trade, which burns the liquidity
    /// @param tradeId The ID of the trade to be cancel
    /// @return amount0 The amount of tokenIn returned
    /// @return amount1 The amount of tokenOut returned
    function cancel(uint256 tradeId)
        external
        payable
        returns (uint256 amount0, uint256 amount1);
}
