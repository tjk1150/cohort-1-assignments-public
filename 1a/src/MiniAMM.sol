// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30; // 13 으로 변경?

import {IMiniAMM, IMiniAMMEvents} from "./IMiniAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MiniAMM
/// @notice 간단한 상수곱 자동화 마켓 메이커(AMM) 구현체
/// @dev
///  - 두 토큰 간 유동성 풀을 관리하며 x*y=k invariant를 유지한다.
///  - 첫 유동성 추가 시 비율 제약 없이 k를 초기화한다.
///  - 이후 유동성 추가는 기존 비율을 반드시 유지해야 한다.
///  - 스왑은 수수료 0%의 순수 상수곱 공식으로 계산된다.
///  - 모든 함수는 forge 테스트(`MiniAMMTest`)를 통과하도록 설계되어야 한다.
contract MiniAMM is IMiniAMM, IMiniAMMEvents {
    /// @notice 상수곱 인버리언트 값 k = xReserve * yReserve
    uint256 public k = 0;

    /// @notice 현재 풀에 예치된 tokenX의 리저브 양
    uint256 public xReserve = 0;

    /// @notice 현재 풀에 예치된 tokenY의 리저브 양
    uint256 public yReserve = 0;

    /// @notice 풀에서 작은 주소값을 가진 토큰 (주소 정렬 결과)
    address public tokenX;

    /// @notice 풀에서 큰 주소값을 가진 토큰 (주소 정렬 결과)
    address public tokenY;

    /// @notice AMM을 생성한다.
    /// @dev
    ///  - 두 입력 토큰 주소가 동일하면 안 되며,
    ///  - 각 주소가 0주소여서도 안 된다.
    ///  - 내부적으로 두 주소를 비교하여 작은 주소를 tokenX, 큰 주소를 tokenY로 저장한다.
    /// @param _tokenX 유동성 풀에 참여할 첫 번째 토큰 주소
    /// @param _tokenY 유동성 풀에 참여할 두 번째 토큰 주소
    constructor(address _tokenX, address _tokenY) {
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
        // 초기 상태
        k = 0;
        xReserve = 0;
        yReserve = 0;
    }

    /// @notice 최초 유동성 추가 로직을 처리한다.
    /// @dev
    ///  - k==0 상태에서만 호출된다.
    ///  - 공급자가 넣은 xAmount, yAmount를 그대로 리저브로 세팅한다.
    ///  - k = xAmount * yAmount 로 초기화한다.
    ///  - AddLiquidity 이벤트를 발행한다.
    function _addLiquidityFirstTime(uint256 xAmount, uint256 yAmount) internal {
        require(IERC20(tokenX).transferFrom(msg.sender, address(this), xAmount), "Transfer failed");
        require(IERC20(tokenY).transferFrom(msg.sender, address(this), yAmount), "Transfer failed");

        xReserve = xAmount;
        yReserve = yAmount;
        k = xAmount * yAmount;

        emit AddLiquidity(xAmount, yAmount);
    }

    /// @notice 두 번째 이후 유동성 추가 로직을 처리한다.
    /// @dev
    ///  - k>0 상태에서 호출된다.
    ///  - 기존 비율(xReserve : yReserve)을 유지해야 한다.
    ///  - 정확히 xAmount, yAmount 만큼만 전송 받아야 한다.
    ///  - 리저브와 k를 갱신하고 AddLiquidity 이벤트를 발행한다.
    function _addLiquidityNotFirstTime(uint256 xAmount, uint256 yAmount) internal {
        require(k > 0, "k must be greater than 0");
        require(xAmount > 0 && yAmount > 0, "Amounts must be greater than 0");

        uint256 yRequired = (xAmount * yReserve) / xReserve;
        require(yAmount == yRequired, "Invalid ratio");

        require(IERC20(tokenX).transferFrom(msg.sender, address(this), xAmount), "Transfer failed");
        require(IERC20(tokenY).transferFrom(msg.sender, address(this), yAmount), "Transfer failed");

        xReserve += xAmount;
        yReserve += yAmount;
        k = xReserve * yReserve;

        emit AddLiquidity(xAmount, yAmount);
    }

    /// @notice 유동성을 풀에 추가한다.
    /// @dev
    ///  - xAmountIn, yAmountIn 중 하나라도 0이면 revert ("Amounts must be greater than 0").
    ///  - k==0이면 `_addLiquidityFirstTime` 호출, 아니면 `_addLiquidityNotFirstTime` 호출.
    /// @param xAmountIn 공급자가 예치할 tokenX 수량
    /// @param yAmountIn 공급자가 예치할 tokenY 수량
    function addLiquidity(uint256 xAmountIn, uint256 yAmountIn) external {
        require(xAmountIn > 0 && yAmountIn > 0, "Amounts must be greater than 0");

        if (k == 0) {
            // 첫 유동성 추가 로직
            _addLiquidityFirstTime(xAmountIn, yAmountIn);
        } else {
            // 이후 유동성 추가 로직
            _addLiquidityNotFirstTime(xAmountIn, yAmountIn);
        }
    }

    /// @notice 토큰을 교환(swap)한다.
    /// @dev
    ///  - 반드시 한 방향(xIn>0,yIn=0 또는 xIn=0,yIn>0)으로만 가능.
    ///  - xIn과 yIn이 동시에 0이면 revert ("Must swap at least one token").
    ///  - 풀에 유동성이 없으면 revert ("No liquidity in pool").
    ///  - 입력량이 리저브를 초과하면 revert ("Insufficient liquidity").
    ///  - 상수곱 공식을 이용해 수취량을 계산하고,
    ///    입력 토큰은 AMM으로 전송받고 출력 토큰은 호출자에게 전송한다.
    ///  - Swap 이벤트를 발행한다.
    /// @param xAmountIn 교환에 사용될 tokenX 입력량 (yAmountIn은 반드시 0이어야 함)
    /// @param yAmountIn 교환에 사용될 tokenY 입력량 (xAmountIn은 반드시 0이어야 함)
    function swap(uint256 xAmountIn, uint256 yAmountIn) external {
        require(k > 0, "No liquidity in pool");
        require(!(xAmountIn > 0 && yAmountIn > 0), "Can only swap one direction at a time");
        require(xAmountIn > 0 || yAmountIn > 0, "Must swap at least one token");

        uint256 x = xReserve;
        uint256 y = yReserve;
        uint256 kLocal = x * y;

        if (xAmountIn > 0) {
            // x -> y
            require(xAmountIn <= xReserve, "Insufficient liquidity");

            // 입력 선 수령
            require(IERC20(tokenX).transferFrom(msg.sender, address(this), xAmountIn), "Transfer failed");

            // 출력 계산
            uint256 yOut = y - (kLocal / (x + xAmountIn));

            // 수취 전송
            require(IERC20(tokenY).transfer(msg.sender, yOut), "Transfer failed");

            // 리저브/ k 갱신
            xReserve = x + xAmountIn;
            yReserve = y - yOut;
            k = xReserve * yReserve;

            emit Swap(xAmountIn, yOut);
        } else if (yAmountIn > 0) {
            // y -> x
            require(yAmountIn <= yReserve, "Insufficient liquidity");

            // 입력 선 수령
            require(IERC20(tokenY).transferFrom(msg.sender, address(this), yAmountIn), "Transfer failed");

            // 출력 계산
            uint256 xOut = x - (kLocal / (y + yAmountIn));

            // 수취 전송
            require(IERC20(tokenX).transfer(msg.sender, xOut), "Transfer failed");

            // 리저브/ k 갱신
            xReserve = x - xOut;
            yReserve = y + yAmountIn;
            k = xReserve * yReserve;

            emit Swap(xOut, yAmountIn);
        }
    }
}
