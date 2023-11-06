// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console2} from "forge-std/Test.sol";

import "../src/simple-perpetual-exchange.sol";

contract TestWithdraw is Test {

    using SafeERC20 for IERC20;

    perpetual public PURPetual;

    IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address WBTCPriceFeedAddress = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

    uint256 WBTCAmount = 5e8;

    function setUp() public {
        PURPetual = new perpetual(address(WBTC), address(USDC), WBTCPriceFeedAddress);

        // give tokens to this test contract
        deal(address(WBTC), address(this), WBTCAmount);

        // approve the exchange to spend WBTC
        WBTC.safeIncreaseAllowance(address(PURPetual), WBTCAmount);

        // add liquidity
        PURPetual.depositLiquidity(WBTCAmount);

        // check that the exchange has the WBTC
        assertEq(WBTC.balanceOf(address(PURPetual)), WBTCAmount);

        // check that the mapping is updated
        assertEq(PURPetual.userDeposit(address(this)), WBTCAmount);
    }

    function testWithdraw() public {
        // withdraw liquidity
        PURPetual.withdrawLiquidity(WBTCAmount);

        // check that the exchange has the WBTC
        assertEq(WBTC.balanceOf(address(PURPetual)), 0);

        // check that the mapping is updated
        assertEq(PURPetual.userDeposit(address(this)), 0);
    }
}