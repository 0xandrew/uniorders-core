// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./base/LiquidityManagement.sol";
import "./base/TradeValidation.sol";
import "./interfaces/ITradeManager.sol";
import "./libraries/PoolAddress.sol";
import "./libraries/TransferHelper.sol";

abstract contract TradeManager is
    ITradeManager,
    LiquidityManagement,
    TradeValidation
{
    // Uniswap V3 factory
    address public immutable factory;

    // initial trade id. Skips 0
    uint256 private _tradeId = 1;

    // details about trade
    struct Trade {
        // address of spender which is approved for spending tokenIn
        address operator;
        // token to be swapped
        address tokenIn;
        // token to be released after execution of trade
        address tokenOut;
        // tick range of the trade
        int24 tickLower;
        int24 tickUpper;
        // liquidity of trade
        uint128 liquidity;
        // last status of trade
        Status tradeStatus;
    }

    /// @dev trade info by tradeId
    mapping(uint256 => Trade) public _trades;

    constructor(address _factory) {
        factory = _factory;
    }

    /// @inheritdoc ITradeManager
    function trades(uint256 tradeId)
        external
        view
        override
        returns (
            address operator,
            address tokenIn,
            address tokenOut,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            Status tradeStatus
        )
    {
        Trade memory trade = _trades[tradeId];
        require(trade.tradeId != 0, "Invalid trade ID");
        return (
            trade.operator,
            trade.tokenIn,
            trade.tokenOut,
            trade.tickLower,
            trade.tickUpper,
            trade.liquidity,
            trade.tradeStatus
        );
    }

    /// @inheritdoc ITradeManager
    function set(LimitOrderParams calldata params)
        external
        payable
        returns (
            uint256 tradeId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // fetch pool
        IUniswapV3Pool pool;
        (pool) = getPool(factory, params.tokenIn, params.tokenOut, params.fee);

        // check if current tick is in range
        require(
            checkTickRange(pool, params.tickLower, params.tickUpper),
            "TICK_IN_RANGE"
        );

        // Add liquidity
        (liquidity, amount0, amount1, ) = addLiquidity(
            AddLiquidityParams({
                token0: params.tokenIn,
                token1: params.tokenOut,
                fee: params.fee,
                recipient: address(this),
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        tradeId = _tradeId++;

        _trades[tradeId] = Trade({
            operator: msg.sender,
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity,
            tradeStatus: Status.OPEN
        });

        emit SetLimitOrder(
            tradeId,
            params.tickLower,
            params.tickUpper,
            amount0,
            amount1
        );
    }

    /// @inheritdoc ITradeManager
    function cancel(uint256 tradeId)
        external
        override
        returns (uint256 amount0, uint256 amount1)
    {
        Trade storage trade = _trades[tradeId];

        require(msg.sender == trade.operator, "NA");
        require(trade.tradeStatus == Status.OPEN, "TEC"); // trade already executed or cancelled

        IUniswapV3Pool pool;
        (pool) = getPool(factory, trade.tokenIn, trade.tokenOut, trade.fee);

        burnAndCollect(pool, trade.tickLower, trade.tickUpper, address(this));

        trade.tradeStatus = Status.CANCELLED;
    }

    function execute(uint256 tradeId) external {
        Trade storage trade = _trades[tradeId];

        require(msg.sender == trade.operator, "NA");
        require(trade.tradeStatus == Status.OPEN, "TEC"); // trade already executed or cancelled

        IUniswapV3Pool pool;
        (pool) = getPool(factory, trade.tokenIn, trade.tokenOut, trade.fee);

        if (
            checkTickRange(
                pool,
                trade.tokenIn,
                trade.tokenOut,
                trade.tickLower,
                trade.tickUpper
            )
        ) {
            uint256 tokenOutOwed;

            burnAndCollect(
                pool,
                trade.tickLower,
                trade.tickUpper,
                address(this)
            );

            (_liquidity, , , , ) = pool.positions(
                PositionKey.compute(address(this), tickLower, tickUpper)
            );

            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(
                trade.tickLower
            );
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(
                trade.tickUpper
            );

            if (trade.tokenIn < trade.tokenOut) {
                tokenOutOwed = LiquidityAmounts.getAmount1ForLiquidity(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    _liquidity
                );
            } else {
                tokenOutOwed = LiquidityAmounts.getAmount0ForLiquidity(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    _liquidity
                );
            }

            // transfer the amounts to owner
            TransferHelper.safeTransfer(
                trade.tokenOut,
                trade.operator,
                tokenOutOwed
            );

            trade.tradeStatus = Status.EXECUTED;
        }
    }
}
