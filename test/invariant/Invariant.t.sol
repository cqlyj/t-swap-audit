// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant_test is StdInvariant, Test {
    // one pool has two asset
    ERC20Mock mockWeth;
    ERC20Mock poolToken;
    // needed contract
    PoolFactory poolFactory;
    TSwapPool tswapPool; // pooltoken / mockWeth

    Handler handler;

    int256 public constant STARTING_X = 100 ether;
    int256 public constant STARTING_Y = 50 ether;

    function setUp() public {
        mockWeth = new ERC20Mock();
        poolToken = new ERC20Mock();
        poolFactory = new PoolFactory(address(mockWeth));
        tswapPool = TSwapPool(poolFactory.createPool(address(poolToken)));

        // now needs some x & y balance
        mockWeth.mint(address(this), uint256(STARTING_Y));
        poolToken.mint(address(this), uint256(STARTING_X));

        mockWeth.approve(address(tswapPool), type(uint256).max);
        poolToken.approve(address(tswapPool), type(uint256).max);

        // now needes deposit into pool
        tswapPool.deposit(
            uint256(STARTING_Y),
            uint256(STARTING_Y),
            uint256(STARTING_X),
            uint64(block.timestamp)
        );

        handler = new Handler(tswapPool);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.poolTokenSwapForWethBasedOnOutputAmount.selector;
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
        targetContract(address(handler));
    }

    function statefulFuzz_constantProductFormulaStayTheSameX() public view {
        assertEq(handler.expectDeltaX(), handler.actualDeltaX());
    }

    function statefulFuzz_constantProductFormulaStayTheSameY() public view {
        assertEq(handler.expectDeltaY(), handler.actualDeltaY());
    }
}
