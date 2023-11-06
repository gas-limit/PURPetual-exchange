// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
        uint256 leverage; // amount of leverage, 10 = 10x, 2 = 2x
        uint256 collateralAmount; // USDC
        uint256 borrowAmountUsdc; // USDC borrowed
        uint256 borrowAmountWbtc; // WBTC borrowed
    }

    // WBTC address
    IERC20 public immutable WBTC; 
    IERC20 public immutable USDC;

    // tracking only amount deposited, because fees are not required
    mapping(address => uint256) public userDeposit;

    mapping(address => position) public userPositions;
    
    uint256 public totalDeposited;
    uint256 public totalBorrowed;

    // constants
    // no liquidations so don't need minimum collateral
    // uint256 constant MINIMUM_COLLATERAL_RATIO = 11_000; // 110.00% =  11,000
    // 10 USDC minimum to borrow
    uint256 constant MINIMUM_COLLATERAL = 10_000_000;
    // collateral must always be >1.50x the amount of borrowed
    uint256 constant MINIMUM_RESERVE_RATIO = 15_000; // 150.00% = 15,000
    uint256 constant WBTC_DIVISION_SCALE = 1e18;
    uint256 constant WBTC_ACTUAL_SCALE = 1e8;
    uint256 constant LIQUIDITY_SCALE = 1e4;


    event LiquidityDeposited(address indexed user, uint256 amount);
    event LiquidityWithdrawn(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user, 
        bool positionType, 
        uint256 leverage, 
        uint256 collateralAmountUsdc,
        uint256 borrowAmountUsdc,
        uint256 borrowAmountWbtc
    );
    event PositionIncreased(
        address indexed user, 
        uint256 additionalCollateralAmountUsdc,
        uint256 newborrowAmountUsdc,
        uint256 newBorrowAmountWbtc
    );
    event CollateralIncreased(
        address indexed user, 
        uint256 additionalCollateralAmountUsdc
    );

    // errors
    error ZeroAmount();
    error NotEnoughLiquidity();
    error PositionOpen();
    error NotEnoughCollateral();

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

        emit LiquidityDeposited(msg.sender, _amount);
    }

    // withdraw liquidity
    function withdrawLiquidity(uint256 _amount) public {
        if (_amount == 0) revert ZeroAmount();

        checkLiquidityWithdraw(_amount);

        userDeposit[msg.sender] -= _amount;

        totalDeposited -= _amount;

        WBTC.safeTransfer(msg.sender, _amount);

        emit LiquidityWithdrawn(msg.sender, _amount);

    }
    

    function getWBTCPrice() public view returns (uint256){
        (,int256 answer,,,) = dataFeed.latestRoundData();
        return uint256(answer);
    }

    // open position
    function openPosition(
        bool _positionType, 
        uint256 _leverage,
        uint256 _collateralAmountUsdc)
        public {
        if(_leverage == 0 || _collateralAmountUsdc == 0) revert ZeroAmount();
        if(userPositions[msg.sender].borrowAmountUsdc > 0) revert PositionOpen();
        if(_collateralAmountUsdc < MINIMUM_COLLATERAL) revert NotEnoughCollateral();

        // get wbtc price
        uint256 wbtcPrice_ = getWBTCPrice();

        // get borrowed amount in USD
        uint256 borrowAmountUsdc_ = _collateralAmountUsdc * _leverage;

        uint256 borrowAmountWbtc_ = (borrowAmountUsdc_ *  WBTC_DIVISION_SCALE) / wbtcPrice_;

        borrowAmountWbtc_ / LIQUIDITY_SCALE;

        checkLiquidityBorrow(borrowAmountWbtc_);

        userPositions[msg.sender] = position(
            _positionType,
            _leverage,
            _collateralAmountUsdc,
            borrowAmountUsdc_,
            borrowAmountWbtc_
        );

        totalBorrowed += borrowAmountWbtc_;

        USDC.safeTransferFrom(msg.sender, address(this), _collateralAmountUsdc);

        emit PositionOpened(
            msg.sender, 
            _positionType, 
            _leverage, 
            _collateralAmountUsdc,
            borrowAmountUsdc_,
            borrowAmountWbtc_
        );
        
    }

    // increase size of position
    function increasePosition(uint256 _collateralAmountUsdc) public {
        if (_collateralAmountUsdc == 0) revert ZeroAmount();
        if(_collateralAmountUsdc < MINIMUM_COLLATERAL) revert NotEnoughCollateral();

        position storage userPosition_ = userPositions[msg.sender];

        uint256 wbtcPrice_ = getWBTCPrice();

        uint256 borrowAmountUsdc_ = _collateralAmountUsdc * userPosition_.leverage;

        uint256 borrowAmountWbtc_ = (_collateralAmountUsdc * WBTC_DIVISION_SCALE) / (wbtcPrice_);

        borrowAmountWbtc_ / LIQUIDITY_SCALE;

        checkLiquidityBorrow(borrowAmountWbtc_);

        userPosition_.borrowAmountUsdc += borrowAmountUsdc_;
        userPosition_.borrowAmountWbtc += borrowAmountWbtc_;

        totalBorrowed += borrowAmountWbtc_;

        USDC.safeTransferFrom(msg.sender, address(this), _collateralAmountUsdc);

        emit PositionIncreased(
            msg.sender, 
            _collateralAmountUsdc,
            userPosition_.borrowAmountUsdc,
            userPosition_.borrowAmountWbtc
        );
        
    }

    // increase collateral
    function increaseCollateral(uint256 _collateralAmountUsdc) public {
        if (_collateralAmountUsdc == 0) revert ZeroAmount();

        userPositions[msg.sender].collateralAmount += _collateralAmountUsdc;

        USDC.safeTransferFrom(msg.sender, address(this), _collateralAmountUsdc);

        emit CollateralIncreased(msg.sender, _collateralAmountUsdc);
    }
    
    // check available liquidity when borrowing
    function checkLiquidityBorrow(uint256 _amount) public view {
        uint256 netBorrow = totalBorrowed + _amount;

        uint256 liquidityRatioAfter = (totalDeposited * LIQUIDITY_SCALE) / netBorrow;

        if (liquidityRatioAfter < MINIMUM_RESERVE_RATIO) revert NotEnoughLiquidity();
    }

    // check available liquidity when withdrawing
    function checkLiquidityWithdraw(uint256 _amount) public view {
        uint256 netSupply = (totalDeposited - _amount);

        uint256 liquidityRatioAfter = (netSupply * LIQUIDITY_SCALE) / totalBorrowed;

        if (liquidityRatioAfter < MINIMUM_RESERVE_RATIO) revert NotEnoughLiquidity();
    }

}
