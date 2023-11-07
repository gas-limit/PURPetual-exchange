// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/simple-perpetual-exchange.sol";

contract TestBorrow is Test {

    struct position {
        bool positionType; // true if long, false if short
        uint256 leverage; // amount of leverage, 10 = 10x, 2 = 2x
        uint256 collateralAmount; // USDC
        uint256 borrowAmountUsdc; // USDC borrowed
        uint256 borrowAmountWbtc; // WBTC borrowed
    }

    using SafeERC20 for IERC20;

    perpetual public PURPetual;

    IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address WBTCPriceFeedAddress = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

    uint256 WBTCAmount = 5e8;

    uint256 USDCCollateralMin = 10e6;

    function setUp() public {
        PURPetual = new perpetual(address(WBTC), address(USDC), WBTCPriceFeedAddress);

        // give tokens to this test contract
        deal(address(WBTC), address(this), WBTCAmount);
        deal(address(USDC), address(this), USDCCollateralMin);

        // approve the exchange to spend WBTC
        WBTC.safeIncreaseAllowance(address(PURPetual), WBTCAmount);
        // approve the exchange to spend USDC
        USDC.safeIncreaseAllowance(address(PURPetual), USDCCollateralMin);

        // add liquidity
        PURPetual.depositLiquidity(WBTCAmount);

        // check that the exchange has the WBTC
        assertEq(WBTC.balanceOf(address(PURPetual)), WBTCAmount);

        // check that the mapping is updated
        assertEq(PURPetual.userDeposit(address(this)), WBTCAmount);
    }

    function testOpenPosition() public {
        // open a position
        PURPetual.openPosition(true, 10, USDCCollateralMin);

        // (bool positionType,
        // uint256 leverage,
        // uint256 collateralAmount,
        // uint256 borrowAmountUsdc,
        // uint256 borrowAmountWbtc) = PURPetual.userPositions(address(this));
        
        // console.log("positionType: ", positionType);
        // console.log("leverage: ", leverage);
        // console.log("collateralAmount: ", collateralAmount);
        // console.log("borrowAmountUsdc: ", borrowAmountUsdc);
        // console.log("borrowAmountWbtc: ", borrowAmountWbtc);


    }



}