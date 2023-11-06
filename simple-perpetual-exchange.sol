// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// following functionalities & corresponding tests
// liquidity providers can deposit and withdraw liquidity
// a way to get the realtime price of the asset being traded
// traders can open aperpetual position for BTC, with a given size and collateral
// traders can increase the size of a perpetual position
// traders can increase the collateral of a perpetual position
// traders cannot utilize more than a configured percentage of the deposited liqudity
// liquidity providers cannot withdraw liquidity that is reserved for positions
// fees not required
// you are not tasked with implementing decreasing, closing, or liquidating positions — but it will be helpful to ponder what this might look like.

// USDC price hard coded

contract perpetual {

    using SafeERC20 for IERC20;
    AggregatorV3Interface immutable internal dataFeed;

    struct position {
        bool positionType; // true if long, false if short
        uint256 leverage; // amount of leverage, 1 decimal place 100 = 10x or 105 = 10.5x
        uint256 collateralAmount; // USDC
        uint256 borrowAmountUsd; // USD borrowed
        uint256 borrowAmountWbtc; // BTC borrowed
    }

    // WBTC address
    IERC20 public immutable WBTC; 
    IERC20 public immutable USDC;

    // Decimals constants
    uint256 constant USDC_DECIMALS = 1e6; // 6 decimal places
    uint256 constant WBTC_DECIMALS = 1e8; // 8 decimal places
    uint256 constant PRICE_FEED_DECIMALS = 1e8; // 8 decimal places for Chainlink price feed
    uint256 constant LEVERAGE_DECIMALS = 1e1; // 1 decimal place for leverage
    uint256 constant RATIO_DECIMALS = 1e4; // Used for ratios like collateral and reserve ratios

    // tracking only amount deposited, because fees are not required
    mapping(address => uint256) public userDeposit;

    mapping(address => position) public userPositions;
    
    uint256 public totalDeposited;
    uint256 public totalBorrowed;

    // constant
    // collateral must always be >1.5x the amount of borrowed
    uint256 constant MINIMUM_COLLATERAL_RATIO = 11_000; // 110.00% =  11,000
    uint256 constant MINIMUM_RESERVE_RATIO = 11_500; // 115.00% = 11,500

    // errors
    error ZeroAmount();
    error NotEnoughLiquidity();
    error PositionOpen();

    constructor(address _WBTC, address _USDC, address chainlinkPriceFeed){
        WBTC = IERC20(_WBTC);
        USDC = IERC20(_USDC);
        dataFeed = AggregatorV3Interface(chainlinkPriceFeed);
    }

    // deposit liquidity
    function depositLiquidity(uint256 _amount) public {
        if (_amount == 0) revert ZeroAmount();

        // update deposit balance
        userDeposit[msg.sender] += _amount;

        // update totalDeposited
        totalDeposited += _amount;

        //transfer the funds
        WBTC.safeTransferFrom(msg.sender, address(this), _amount);
    }

    // withdraw liquidity
    function withdrawLiquidity(uint256 _amount) public {
        if (_amount == 0) revert ZeroAmount();

        checkLiquidityWithdraw(_amount);

        userDeposit[msg.sender] -= _amount;

        totalDeposited -= _amount;

        WBTC.safeTransfer(msg.sender, _amount);

    }
    

    // get price 3505489359000 
    function getWBTCPrice() public view returns (uint256){
        (,int256 answer,,,) = dataFeed.latestRoundData();
        return uint256(answer);
    }

    // open position
    function openPosition(
        bool _positionType, 
        uint256 _leverage,
        uint256 _collateralAmountUsd)
        public {
        if(_leverage == 0 || _collateralAmountUsd == 0) revert ZeroAmount();
        if(userPositions[msg.sender].borrowAmountUsd > 0) revert PositionOpen();

        // get wbtc price
        uint256 wbtcPrice_ = getWBTCPrice();

        // get borrowed amount in USD
        uint256 borrowAmountUsd_ = _collateralAmountUsd * _leverage / LEVERAGE_DECIMALS;

        // get borrowed amount in WBTC, with price scaling adjustment
        uint256 borrowAmountWbtc_ = (_collateralAmountUsd * USDC_DECIMALS * WBTC_DECIMALS) / (wbtcPrice_ * PRICE_FEED_DECIMALS);

        checkLiquidityBorrow(borrowAmountWbtc_);

        userPositions[msg.sender] = position(
            _positionType,
            _leverage,
            _collateralAmountUsd,
            borrowAmountUsd_,
            borrowAmountWbtc_
        );

        totalBorrowed += borrowAmountWbtc_;

        USDC.safeTransferFrom(msg.sender, address(this), _collateralAmountUsd);
        
    }

    // increase size of position
    function increasePosition(uint256 _collateralAmountUsd) public {
        if (_collateralAmountUsd == 0) revert ZeroAmount();

        position storage userPosition_ = userPositions[msg.sender];

        uint256 wbtcPrice_ = getWBTCPrice();

        uint256 borrowAmountUsd_ = _collateralAmountUsd * userPosition_.leverage / LEVERAGE_DECIMALS;

        uint256 borrowAmountWbtc_ = (_collateralAmountUsd * USDC_DECIMALS * WBTC_DECIMALS) / (wbtcPrice_ * PRICE_FEED_DECIMALS);

        checkLiquidityBorrow(borrowAmountWbtc_);

        userPosition_.borrowAmountUsd = borrowAmountUsd_;
        userPosition_.borrowAmountWbtc = borrowAmountWbtc_;

        totalBorrowed += borrowAmountWbtc_;

        USDC.safeTransferFrom(msg.sender, address(this), _collateralAmountUsd);
        
    }

    // increase collateral
    function increaseCollateral(uint256 _collateralAmountUsd) public {
        if (_collateralAmountUsd == 0) revert ZeroAmount();

        userPositions[msg.sender].collateralAmount += _collateralAmountUsd;

        USDC.safeTransferFrom(msg.sender, address(this), _collateralAmountUsd);

    }
    
    // check available liquidity when borrowing
    function checkLiquidityBorrow(uint256 _amount) public view {
        uint256 netBorrow = totalBorrowed + _amount;

        uint256 liquidityRatioAfter = (totalDeposited * WBTC_DECIMALS) / netBorrow;

        if (liquidityRatioAfter < MINIMUM_RESERVE_RATIO * RATIO_DECIMALS / WBTC_DECIMALS) revert NotEnoughLiquidity();
    }

    // check available liquidity when withdrawing
    function checkLiquidityWithdraw(uint256 _amount) public view {
        uint256 netSupply = (totalDeposited - _amount);

        uint256 liquidityRatioAfter = (netSupply * WBTC_DECIMALS) / totalBorrowed;

        if (liquidityRatioAfter < MINIMUM_RESERVE_RATIO * RATIO_DECIMALS / WBTC_DECIMALS) revert NotEnoughLiquidity();
    }

}
