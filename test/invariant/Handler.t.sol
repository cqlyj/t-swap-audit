// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool pool;
    ERC20Mock mockWeth;
    ERC20Mock poolToken;

    int256 startingX;
    int256 startingY;

    int256 public expectDeltaX;
    int256 public expectDeltaY;

    int256 endingX;
    int256 endingY;

    int256 public actualDeltaX;
    int256 public actualDeltaY;

    address lp = makeAddr("liquidityProvider");
    address swapper = makeAddr("swapper");

    constructor(TSwapPool _pool) {
        pool = _pool;
        mockWeth = ERC20Mock(pool.getWeth());
        poolToken = ERC20Mock(pool.getPoolToken());
    }

    // we need pooltoken input and get weth output!
    // we want wethAmout output : deltaY pool.getInputAmountBasedOnOutput()
    // ∆x  = (x*outputAmount)/(y - outputAmount)
    function poolTokenSwapForWethBasedOnOutputAmount(
        uint256 wethAmountOutput
    ) public {
        // determine the wethamount not more than in pools
        wethAmountOutput = bound(
            wethAmountOutput,
            pool.getMinimumWethDepositAmount(),
            mockWeth.balanceOf(address(pool))
        );

        if (wethAmountOutput >= mockWeth.balanceOf(address(pool))) {
            return;
        }

        // determine how many pooltoken amount we needed
        //getInputAmountBasedOnOutput(outputAmount, inputReserves, outputReserves)
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            wethAmountOutput,
            poolToken.balanceOf(address(pool)),
            mockWeth.balanceOf(address(pool))
        );
        if (poolTokenAmount >= type(uint64).max) {
            return;
        }

        startingY = int256(mockWeth.balanceOf(address(pool)));
        startingX = int256(poolToken.balanceOf(address(pool)));

        expectDeltaY = int256(-1) * int256(wethAmountOutput);
        expectDeltaX = int256(poolTokenAmount);

        // then we need a swapper to swap!
        // swapper must have enough balance！
        if (poolToken.balanceOf(swapper) < uint256(expectDeltaX)) {
            poolToken.mint(
                swapper,
                uint256(expectDeltaX) - poolToken.balanceOf(swapper) + 1
            );
        }
        // Start Swap
        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(
            poolToken,
            mockWeth,
            wethAmountOutput,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // check 2 assets in pool
        endingX = int256(poolToken.balanceOf(address(pool)));
        endingY = int256(mockWeth.balanceOf(address(pool)));

        actualDeltaX = endingX - startingX;
        actualDeltaY = endingY - startingY;
    }

    //q Handler should do what functions to do?
    // deposit, swap, withdraw,

    function deposit(uint256 wethAmount) public {
        wethAmount = bound(
            wethAmount,
            pool.getMinimumWethDepositAmount(),
            type(uint64).max
        );

        startingX = int256(poolToken.balanceOf(address(pool)));
        startingY = int256(mockWeth.balanceOf(address(pool)));

        expectDeltaX = int256(
            pool.getPoolTokensToDepositBasedOnWeth(wethAmount)
        );
        expectDeltaY = int256(wethAmount);

        // Prank a liquidityProvider to mint
        vm.startPrank(lp);
        mockWeth.mint(lp, wethAmount);
        poolToken.mint(lp, uint256(expectDeltaX));

        mockWeth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(
            wethAmount,
            pool.getMinimumWethDepositAmount(),
            uint256(expectDeltaX),
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // check the actual deltaX & deltaY
        endingX = int256(poolToken.balanceOf(address(pool)));
        endingY = int256(mockWeth.balanceOf(address(pool)));

        actualDeltaX = endingX - startingX;
        actualDeltaY = endingY - startingY;
    }
}
