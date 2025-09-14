// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IMiniAMM, IMiniAMMEvents} from "./IMiniAMM.sol";
import {MiniAMMLP} from "./MiniAMMLP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Add as many variables or functions as you would like
// for the implementation. The goal is to pass `forge test`.
contract MiniAMM is IMiniAMM, IMiniAMMEvents, MiniAMMLP {
    uint256 public k = 0;
    uint256 public xReserve = 0;
    uint256 public yReserve = 0;

    address public tokenX;
    address public tokenY;

    // implement constructor
    constructor(address _tokenX, address _tokenY) MiniAMMLP(_tokenX, _tokenY) {
        require(_tokenX != address(0), "tokenX cannot be zero address");
        require(_tokenY != address(0), "tokenY cannot be zero address");
        require(_tokenX != _tokenY, "Tokens must be different");

        if(_tokenX < _tokenY) {
            tokenX = _tokenX;
            tokenY = _tokenY;
        } else {
            tokenX = _tokenY;
            tokenY = _tokenX;
        }

        k = 0;
        xReserve = 0;
        yReserve = 0;
    }

    // Helper function to calculate square root
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    // add parameters and implement function.
    // this function will determine the 'k'.
    function _addLiquidityFirstTime(uint256 xAmountIn, uint256 yAmountIn) internal returns (uint256 lpMinted) {
        // xReserve = xExisting , xAmountIn = xIn
        // yReserve = yExisting , yAmountIn = yIn
        require(xAmountIn > 0 && yAmountIn > 0, "Zero amount");

        IERC20(tokenX).transferFrom(msg.sender, address(this), xAmountIn);
        IERC20(tokenY).transferFrom(msg.sender, address(this), yAmountIn);

        lpMinted = sqrt(xAmountIn * yAmountIn);
        _mintLP(msg.sender, lpMinted);

        xReserve = xAmountIn;
        yReserve = yAmountIn;
        k = xReserve * yReserve;

        emit AddLiquidity(xAmountIn, yAmountIn);
    }

    // add parameters and implement function.
    // this function will increase the 'k'
    // because it is transferring liquidity from users to this contract.
    function _addLiquidityNotFirstTime(uint256 xAmountIn, uint256 yAmountIn, uint256 xUsed, uint256 yUsed) internal returns (uint256 lpMinted) {
        // xReserve = xExisting , xAmountIn = xIn
        // yReserve = yExisting , yAmountIn = yIn

        // lpmint 공식
        // lpmint = xIn / xExisting * supply

        require(xReserve > 0 && yReserve > 0, "No liquidity");
        uint256 supply = totalSupply();

        // yRequired = xIn / xExisting * yExisting 수식은 이게 맞지만 solidity는 정수만 다루기 때문에 아래처럼 적음(소수점 내림)
        uint256 yRequired = (xAmountIn * yReserve) / xReserve;

        // 입력 비율 보정: 더 적은 쪽에 맞춰 사용량 결정
        if(yRequired <= yAmountIn){
            xUsed = xAmountIn;
            yUsed = yRequired;
        } else {
            uint256 xRequired = (yAmountIn * xReserve) / yReserve;
            require(xRequired <= xAmountIn, "Insufficient X");
            xUsed = xRequired;
            yUsed = yAmountIn;
        }

        IERC20(tokenX).transferFrom(msg.sender, address(this), xUsed);
        IERC20(tokenY).transferFrom(msg.sender, address(this), yUsed);

        uint256 lpByX = (xUsed * supply) / xReserve;
        uint256 lpByY = (yUsed * supply) / yReserve;
        uint256 liquidity = lpByX < lpByY ? lpByX : lpByY;
        require(liquidity > 0, "Insufficient liquidity minted");

        _mintLP(msg.sender, liquidity);
        lpMinted = liquidity;

        xReserve = xReserve + xUsed;
        yReserve = yReserve + yUsed;
        k = xReserve * yReserve;

        emit AddLiquidity(xUsed, yUsed);

    }

    // complete the function. Should transfer LP token to the user.
    function addLiquidity(uint256 xAmountIn, uint256 yAmountIn) external returns (uint256 lpMinted) {
        if( totalSupply() == 0){
            return _addLiquidityFirstTime(xAmountIn, yAmountIn);
        } else {
            return _addLiquidityNotFirstTime(xAmountIn, yAmountIn, 0, 0);
        }
    }

    // Remove liquidity by burning LP tokens
    function removeLiquidity(uint256 lpAmount) external returns (uint256 xAmount, uint256 yAmount) {
        require(lpAmount > 0, "Invalid LP amount");

        uint256 supply = totalSupply();
        xAmount = (xReserve * lpAmount) / supply;
        yAmount = (yReserve * lpAmount) / supply;

        _burnLP(msg.sender, lpAmount);

        xReserve = xReserve - xAmount;
        yReserve = yReserve - yAmount;
        k = xReserve * yReserve;

        IERC20(tokenX).transfer(msg.sender, xAmount);
        IERC20(tokenY).transfer(msg.sender, yAmount);
    }

    // complete the function
    function swap(uint256 xAmountIn, uint256 yAmountIn) external {
        require(!(xAmountIn > 0 && yAmountIn > 0), "Can only swap one direction at a time");
        require(xAmountIn > 0 || yAmountIn > 0, "Must swap at least one token");
        require(k > 0 && xReserve > 0 && yReserve > 0, "No liquidity in pool");

        uint256 feeDen = 1000;
        uint256 feemul = 997;

        if(xAmountIn > 0) {
            require(xAmountIn <= xReserve, "Insufficient liquidity");

            IERC20(tokenX).transferFrom(msg.sender, address(this), xAmountIn);
            uint256 amountInWithFee = xAmountIn * feemul / feeDen;
            uint256 yOut = (amountInWithFee * yReserve) / (xReserve + amountInWithFee);


            IERC20(tokenY).transfer(msg.sender, yOut);

            xReserve = xReserve + xAmountIn;
            yReserve = yReserve - yOut;
            k = xReserve * yReserve;

            emit Swap(xAmountIn, 0, 0, yOut);
        } else {
        require(yAmountIn <= yReserve, "Insufficient liquidity");

        IERC20(tokenY).transferFrom(msg.sender, address(this), yAmountIn);
        uint256 amountInWithFee = yAmountIn * feemul / feeDen;
        uint256 xOut = (amountInWithFee * xReserve) / (yReserve + amountInWithFee);

        IERC20(tokenX).transfer(msg.sender, xOut);

        xReserve = xReserve - xOut;
        yReserve = yReserve + yAmountIn;
        k = xReserve * yReserve;

        emit Swap(0, yAmountIn, xOut, 0);
        }
    }
}