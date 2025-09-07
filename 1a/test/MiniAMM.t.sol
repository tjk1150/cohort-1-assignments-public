// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MiniAMM} from "../src/MiniAMM.sol";
import {IMiniAMMEvents} from "../src/IMiniAMM.sol";
import {MockERC20} from "../src/MockERC20.sol";

/// @title MiniAMM 테스트 스위트
/// @notice MiniAMM의 핵심 기능(생성자, 유동성 추가, 스왑, 이벤트, 리버트 조건)을 상수곱 공식(x*y=k) 기준으로 검증한다.
/// @dev
///  - 풀은 두 토큰 주소를 입력받되, 내부적으로 주소가 작은 쪽을 tokenX, 큰 쪽을 tokenY로 강제 정렬해야 한다.
///  - 첫 유동성 추가 시에는 비율 제약 없이 (xReserve, yReserve, k=x*y)를 초기화한다.
///  - 두 번째 이후 유동성 추가는 기존 비율을 유지해야 하며, 정확히 들어온 수량만 이동해야 한다(초과/환불 처리 없음).
///  - 스왑은 수수료 0%의 순수 상수곱 공식으로 계산한다:
///      x→y: yOut = y - floor(k / (x + xIn))
///      y→x: xOut = x - floor(k / (y + yIn))
///  - 스왑/유동성 추가 시 컨트랙트 토큰 잔액과 내부 상태변수(xReserve, yReserve, k)가 동기화되어야 한다.
///  - 이벤트(AddLiquidity, Swap)는 테스트가 기대하는 시그니처/파라미터로 정확히 발행되어야 통과한다.
contract MiniAMMTest is Test {
    MiniAMM public miniAMM;
    MockERC20 public token0;
    MockERC20 public token1;

    address public alice = address(0x1);
    address public bob   = address(0x2);
    address public charlie = address(0x3);

    // 테스트가 기대하는 이벤트 시그니처(검증용)
    event AddLiquidity(uint256 xAmountIn, uint256 yAmountIn);
    event Swap(uint256 xAmountIn, uint256 yAmountIn);

    /// @notice 각 테스트 전에 공통 환경을 구성한다.
    /// @dev
    ///  1) 두 개의 MockERC20 토큰 배포 (TKA, TKB)
    ///  2) MiniAMM 배포(두 토큰 주소 전달)
    ///  3) alice/bob/charlie에게 각 토큰 10,000개(18 decimals)씩 무료 민팅
    ///  4) MiniAMM에 대한 무제한 approve (테스트 중 전송 한도 이슈 방지)
    function setUp() public {
        // 1) Mock 토큰 배포
        token0 = new MockERC20("Token A", "TKA");
        token1 = new MockERC20("Token B", "TKB");

        // 2) AMM 배포
        miniAMM = new MiniAMM(address(token0), address(token1));

        // 3) 잔액 세팅
        token0.freeMintTo(10000 * 10 ** 18, alice);
        token1.freeMintTo(10000 * 10 ** 18, alice);
        token0.freeMintTo(10000 * 10 ** 18, bob);
        token1.freeMintTo(10000 * 10 ** 18, bob);
        token0.freeMintTo(10000 * 10 ** 18, charlie);
        token1.freeMintTo(10000 * 10 ** 18, charlie);

        // 4) 승인 설정 (alice)
        vm.startPrank(alice);
        token0.approve(address(miniAMM), type(uint256).max);
        token1.approve(address(miniAMM), type(uint256).max);
        vm.stopPrank();

        // 승인 설정 (bob)
        vm.startPrank(bob);
        token0.approve(address(miniAMM), type(uint256).max);
        token1.approve(address(miniAMM), type(uint256).max);
        vm.stopPrank();

        // 승인 설정 (charlie)
        vm.startPrank(charlie);
        token0.approve(address(miniAMM), type(uint256).max);
        token1.approve(address(miniAMM), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice 생성자 이후 AMM의 초기 불변식이 올바른지 확인한다.
    /// @dev
    ///  - tokenX, tokenY는 우리가 배포한 두 토큰 주소 중 하나여야 하고 서로 달라야 한다.
    ///  - 초기에는 유동성이 없으므로 xReserve=0, yReserve=0, k=0이어야 한다.
    function test_Constructor() public view {
        // 토큰 주소 존재 및 상호 배타성
        assertTrue(miniAMM.tokenX() == address(token0) || miniAMM.tokenX() == address(token1));
        assertTrue(miniAMM.tokenY() == address(token0) || miniAMM.tokenY() == address(token1));
        assertTrue(miniAMM.tokenX() != miniAMM.tokenY());
        // 초기 리저브/곱
        assertEq(miniAMM.k(), 0);
        assertEq(miniAMM.xReserve(), 0);
        assertEq(miniAMM.yReserve(), 0);
    }

    /// @notice 생성자에서 토큰 주소가 항상 정렬(tokenX < tokenY)되는지 검증한다.
    /// @dev
    ///  - (tokenA, tokenB) 순서와 (tokenB, tokenA) 순서로 각각 배포하더라도
    ///    내부적으로 tokenX는 더 작은 주소, tokenY는 더 큰 주소가 되어야 한다.
    function test_ConstructorTokenOrdering() public {
        MockERC20 tokenA = new MockERC20("Token A", "TKA");
        MockERC20 tokenB = new MockERC20("Token B", "TKB");

        // 주소가 tokenA < tokenB인 경우
        MiniAMM amm1 = new MiniAMM(address(tokenA), address(tokenB));
        assertEq(amm1.tokenX(), address(tokenA));
        assertEq(amm1.tokenY(), address(tokenB));

        // 반대로 넣어도 내부적으로 정렬되어야 함
        MiniAMM amm2 = new MiniAMM(address(tokenB), address(tokenA));
        assertEq(amm2.tokenX(), address(tokenA));
        assertEq(amm2.tokenY(), address(tokenB));
    }

    /// @notice 생성자 입력 검증: 0주소 입력 시 반드시 revert 되어야 한다.
    /// @dev
    ///  - tokenX가 0주소면 "tokenX cannot be zero address"
    ///  - tokenY가 0주소면 "tokenY cannot be zero address"
    ///  문자열까지 정확히 일치해야 테스트를 통과한다.
    function test_ConstructorRevertZeroAddress() public {
        vm.expectRevert("tokenX cannot be zero address");
        new MiniAMM(address(0), address(token1));

        vm.expectRevert("tokenY cannot be zero address");
        new MiniAMM(address(token0), address(0));
    }

    /// @notice 생성자 입력 검증: 동일 토큰 주소를 두 번 넣으면 revert 되어야 한다.
    /// @dev
    ///  - tokenX == tokenY 인 경우 "Tokens must be different"로 revert
    function test_ConstructorRevertSameToken() public {
        vm.expectRevert("Tokens must be different");
        new MiniAMM(address(token0), address(token0));
    }

    /// @notice 첫 유동성 추가 시 토큰 이동/리저브/k 설정이 정확한지 검증한다.
    /// @dev
    ///  - 첫 addLiquidity(x,y)에서는 비율 제약 없이 그대로 (xReserve,yReserve)로 채택되고 k=x*y로 초기화된다.
    ///  - 실제로 MiniAMM이 내부에서 어떤 토큰을 tokenX/tokenY로 잡았는지에 따라,
    ///    검사할 때도 같은 매핑(token0Actual/token1Actual)으로 비교해야 한다.
    function test_AddLiquidityFirstTime() public {
        uint256 xAmount = 1000 * 10 ** 18;
        uint256 yAmount = 2000 * 10 ** 18;

        vm.startPrank(alice);

        // MiniAMM 관점에서의 X/Y 실제 토큰 찾기 (주소 정렬 때문)
        address actualToken0 = miniAMM.tokenX();
        address actualToken1 = miniAMM.tokenY();
        MockERC20 token0Actual = actualToken0 == address(token0) ? token0 : token1;
        MockERC20 token1Actual = actualToken1 == address(token1) ? token1 : token0;

        uint256 aliceToken0Before = token0Actual.balanceOf(alice);
        uint256 aliceToken1Before = token1Actual.balanceOf(alice);

        // 첫 유동성 추가
        miniAMM.addLiquidity(xAmount, yAmount);

        // 공급자 -> AMM로 정확한 양이 이동했는지
        assertEq(token0Actual.balanceOf(alice), aliceToken0Before - xAmount);
        assertEq(token1Actual.balanceOf(alice), aliceToken1Before - yAmount);
        assertEq(token0Actual.balanceOf(address(miniAMM)), xAmount);
        assertEq(token1Actual.balanceOf(address(miniAMM)), yAmount);

        // 내부 상태 및 k 설정
        assertEq(miniAMM.xReserve(), xAmount);
        assertEq(miniAMM.yReserve(), yAmount);
        assertEq(miniAMM.k(), xAmount * yAmount);

        vm.stopPrank();
    }

    /// @notice 두 번째 이후 유동성 추가 시 기존 비율을 유지해야 함을 검증한다.
    /// @dev
    ///  - 최초 (x0=1000, y0=2000)으로 1:2 비율을 만든 뒤,
    ///    xDelta=500을 추가할 경우 yRequired = (xDelta * y0) / x0 = 1000이어야 한다.
    ///  - 공급자는 정확히 (xDelta, yRequired)을 잃고, AMM은 그만큼 얻는다.
    ///  - 최종 리저브는 (x0+xDelta, y0+yRequired), k도 그 곱으로 갱신되어야 한다.
    function test_AddLiquidityNotFirstTime() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        // 초기 유동성
        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        // 비율 유지 추가
        uint256 xDelta = 500 * 10 ** 18;
        uint256 yRequired = (xDelta * yInitial) / xInitial; // 1000e18

        vm.startPrank(bob);

        // MiniAMM 관점의 X/Y 실제 토큰
        address actualToken0 = miniAMM.tokenX();
        address actualToken1 = miniAMM.tokenY();
        MockERC20 token0Actual = actualToken0 == address(token0) ? token0 : token1;
        MockERC20 token1Actual = actualToken1 == address(token1) ? token1 : token0;

        uint256 bobToken0Before = token0Actual.balanceOf(bob);
        uint256 bobToken1Before = token1Actual.balanceOf(bob);

        miniAMM.addLiquidity(xDelta, yRequired);

        // 정확한 양 이동 확인
        assertEq(token0Actual.balanceOf(bob), bobToken0Before - xDelta);
        assertEq(token1Actual.balanceOf(bob), bobToken1Before - yRequired);

        // 리저브/곱 갱신 확인
        assertEq(miniAMM.xReserve(), xInitial + xDelta);
        assertEq(miniAMM.yReserve(), yInitial + yRequired);
        assertEq(miniAMM.k(), (xInitial + xDelta) * (yInitial + yRequired));

        vm.stopPrank();
    }

    /// @notice 두 번째 이후 유동성 추가에서 정확히 필요한 양을 입력하면 초과/환불 없이 그대로 반영되어야 한다.
    /// @dev
    ///  - xDelta=500, yRequired=1000을 정확히 넣었을 때,
    ///    공급자 잔액은 정확히 그만큼만 줄어들어야 한다(불필요한 보정/환불 없음).
    function test_AddLiquidityNotFirstTimeExactAmount() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        uint256 xDelta = 500 * 10 ** 18;
        uint256 yRequired = (xDelta * yInitial) / xInitial; // 1000 tokens

        vm.startPrank(bob);

        address actualToken0 = miniAMM.tokenX();
        address actualToken1 = miniAMM.tokenY();
        MockERC20 token0Actual = actualToken0 == address(token0) ? token0 : token1;
        MockERC20 token1Actual = actualToken1 == address(token1) ? token1 : token0;

        uint256 bobToken0Before = token0Actual.balanceOf(bob);
        uint256 bobToken1Before = token1Actual.balanceOf(bob);

        miniAMM.addLiquidity(xDelta, yRequired);

        // 정확히 입력만큼만 이동했는지(초과 없음)
        assertEq(token0Actual.balanceOf(bob), bobToken0Before - xDelta);
        assertEq(token1Actual.balanceOf(bob), bobToken1Before - yRequired);

        vm.stopPrank();
    }

    /// @notice addLiquidity에서 0 금액이 들어오면 반드시 실패해야 한다.
    /// @dev
    ///  - x=0 또는 y=0이면 "Amounts must be greater than 0"로 revert 되어야 한다.
    ///  - revert 메시지까지 정확히 일치해야 테스트 통과.
    function test_AddLiquidityRevertZeroAmount() public {
        vm.expectRevert("Amounts must be greater than 0");
        vm.prank(alice);
        miniAMM.addLiquidity(0, 1000 * 10 ** 18);

        vm.expectRevert("Amounts must be greater than 0");
        vm.prank(alice);
        miniAMM.addLiquidity(1000 * 10 ** 18, 0);
    }

    /// @notice tokenX를 tokenY로 교환할 때 상수곱 공식(x*y=k)이 정확히 적용되는지 검증한다.
    /// @dev
    ///  - 초기 유동성 (x0=1000, y0=2000) → k=x0*y0
    ///  - bob이 xSwap=100을 넣으면 새 x는 (x0 + xSwap)
    ///  - yOut = y0 - floor(k / (x0 + xSwap))
    ///  - bob: tokenX 100 감소, tokenY yOut 증가
    ///  - AMM: xReserve = x0 + xSwap, yReserve = y0 - yOut 로 정확히 갱신
    function test_SwapToken0ForToken1() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        uint256 xSwap = 100 * 10 ** 18;

        vm.startPrank(bob);

        address actualToken0 = miniAMM.tokenX();
        address actualToken1 = miniAMM.tokenY();
        MockERC20 token0Actual = actualToken0 == address(token0) ? token0 : token1;
        MockERC20 token1Actual = actualToken1 == address(token1) ? token1 : token0;

        uint256 bobToken0Before = token0Actual.balanceOf(bob);
        uint256 bobToken1Before = token1Actual.balanceOf(bob);

        miniAMM.swap(xSwap, 0);

        // 입력 토큰 정확히 차감
        assertEq(token0Actual.balanceOf(bob), bobToken0Before - xSwap);

        // 기대 yOut 계산(테스트 시점의 k 사용)
        uint256 k = miniAMM.k();
        uint256 expectedYOut = yInitial - (k / (xInitial + xSwap));

        // 수취 토큰 정확히 증가
        assertEq(token1Actual.balanceOf(bob), bobToken1Before + expectedYOut);

        // 리저브 동기화
        assertEq(miniAMM.xReserve(), xInitial + xSwap);
        assertEq(miniAMM.yReserve(), yInitial - expectedYOut);

        vm.stopPrank();
    }

    /// @notice tokenY를 tokenX로 교환할 때 상수곱 공식(x*y=k)이 정확히 적용되는지 검증한다.
    /// @dev
    ///  - 초기 유동성 (x0=1000, y0=2000) → k=x0*y0
    ///  - bob이 ySwap=200을 넣으면 새 y는 (y0 + ySwap)
    ///  - xOut = x0 - floor(k / (y0 + ySwap))
    ///  - bob: tokenY 200 감소, tokenX xOut 증가
    ///  - AMM: xReserve = x0 - xOut, yReserve = y0 + ySwap 로 정확히 갱신
    function test_SwapToken1ForToken0() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        uint256 ySwap = 200 * 10 ** 18;

        vm.startPrank(bob);

        address actualToken0 = miniAMM.tokenX();
        address actualToken1 = miniAMM.tokenY();
        MockERC20 token0Actual = actualToken0 == address(token0) ? token0 : token1;
        MockERC20 token1Actual = actualToken1 == address(token1) ? token1 : token0;

        uint256 bobToken0Before = token0Actual.balanceOf(bob);
        uint256 bobToken1Before = token1Actual.balanceOf(bob);

        miniAMM.swap(0, ySwap);

        // 입력 토큰 정확히 차감
        assertEq(token1Actual.balanceOf(bob), bobToken1Before - ySwap);

        // 기대 xOut 계산
        uint256 k = miniAMM.k();
        uint256 expectedXOut = xInitial - (k / (yInitial + ySwap));

        // 수취 토큰 정확히 증가
        assertEq(token0Actual.balanceOf(bob), bobToken0Before + expectedXOut);

        // 리저브 동기화
        assertEq(miniAMM.xReserve(), xInitial - expectedXOut);
        assertEq(miniAMM.yReserve(), yInitial + ySwap);

        vm.stopPrank();
    }

    /// @notice 유동성(리저브)이 0인 상태에서 스왑을 시도하면 실패해야 한다.
    /// @dev
    ///  - "No liquidity in pool"로 revert 되어야 한다(메시지 일치 필수).
    function test_SwapRevertNoLiquidity() public {
        vm.expectRevert("No liquidity in pool");
        vm.prank(alice);
        miniAMM.swap(100 * 10 ** 18, 0);
    }

    /// @notice 하나의 스왑 호출에서 양방향 입력(tokenX와 tokenY)을 동시에 넣으면 실패해야 한다.
    /// @dev
    ///  - "Can only swap one direction at a time"로 revert 되어야 한다(메시지 일치 필수).
    function test_SwapRevertBothDirections() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        vm.expectRevert("Can only swap one direction at a time");
        vm.prank(bob);
        miniAMM.swap(100 * 10 ** 18, 100 * 10 ** 18);
    }

    /// @notice 스왑 호출에서 입력값이 모두 0이면 실패해야 한다.
    /// @dev
    ///  - "Must swap at least one token"으로 revert (메시지 일치 필수).
    function test_SwapRevertZeroAmount() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        vm.expectRevert("Must swap at least one token");
        vm.prank(bob);
        miniAMM.swap(0, 0);
    }

    /// @notice 리저브보다 큰 양의 입력으로 스왑을 시도하면 실패해야 한다(테스트 정책).
    /// @dev
    ///  - 본 테스트 스펙에서는 "입력량이 리저브 초과면 금지"로 가정하고,
    ///    "Insufficient liquidity" 메시지로 revert 되어야 한다.
    function test_SwapRevertInsufficientLiquidity() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        vm.expectRevert("Insufficient liquidity");
        vm.prank(bob);
        miniAMM.swap(xInitial + 1, 0); // 리저브 초과 입력 시도
    }

    /// @notice 큰 스왑이 작은 스왑보다 더 불리한 평균 단가(슬리피지)를 가지는지 검증한다.
    /// @dev
    ///  - 동일한 풀에서 작은 입력(10)과 큰 입력(100)을 각각 스왑했을 때,
    ///    (수취량/입력량) 기준의 평균 단가는 큰 입력 쪽이 작아야 한다.
    ///  - 중간에 bob이 받은 token1을 AMM 주소로 다시 transfer하여 잔액을 리셋하는데,
    ///    이는 컨트랙트 외부 잔액만 조정할 뿐 내부 리저브는 스왑 로직에서만 갱신되어야 한다는 전제를 따른다.
    function test_SwapPriceImpact() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        // MiniAMM 관점의 X/Y 실제 토큰
        address actualToken0 = miniAMM.tokenX();
        address actualToken1 = miniAMM.tokenY();
        MockERC20 token0Actual = actualToken0 == address(token0) ? token0 : token1;
        MockERC20 token1Actual = actualToken1 == address(token1) ? token1 : token0;

        // 작은 스왑: 10
        vm.startPrank(bob);
        miniAMM.swap(10 * 10 ** 18, 0);
        uint256 smallSwapOutput = token1Actual.balanceOf(bob);

        // bob의 token1을 다시 AMM으로 보내 잔액만 초기화(내부 리저브는 스왑으로만 변해야 함)
        uint256 bobToken1Balance = token1Actual.balanceOf(bob);
        token1Actual.transfer(address(miniAMM), bobToken1Balance);

        // 큰 스왑: 100
        miniAMM.swap(100 * 10 ** 18, 0);
        uint256 largeSwapOutput = token1Actual.balanceOf(bob);

        // 평균 단가 비교: largeSwap의 1토큰당 효율이 더 낮아야 함
        uint256 smallSwapPricePerToken = smallSwapOutput * 10 ** 18 / (10 * 10 ** 18);
        uint256 largeSwapPricePerToken = largeSwapOutput * 10 ** 18 / (100 * 10 ** 18);
        assertLt(largeSwapPricePerToken, smallSwapPricePerToken);

        vm.stopPrank();
    }

    /// @notice addLiquidity 호출 시 AMM이 AddLiquidity 이벤트를 정확히 발행하는지 검증한다.
    /// @dev
    ///  - vm.expectEmit 이후 동일 파라미터(xAmount,yAmount)로 이벤트가 1회 발생해야 한다.
    function test_AddLiquidityEvent() public {
        uint256 xAmount = 1000 * 10 ** 18;
        uint256 yAmount = 2000 * 10 ** 18;

        vm.expectEmit(true, true, true, true);
        emit AddLiquidity(xAmount, yAmount);

        vm.prank(alice);
        miniAMM.addLiquidity(xAmount, yAmount);
    }

    /// @notice swap 호출 시 AMM이 Swap 이벤트를 정확히 발행하는지 검증한다.
    /// @dev
    ///  - yOut은 스왑 직전의 (x0,y0,k)로부터 yOut = y0 - floor(k/(x0+xIn))으로 계산한다.
    ///  - vm.expectEmit 이후 (xIn, yOut)으로 이벤트가 1회 발생해야 한다.
    function test_SwapEvent() public {
        uint256 xInitial = 1000 * 10 ** 18;
        uint256 yInitial = 2000 * 10 ** 18;

        vm.prank(alice);
        miniAMM.addLiquidity(xInitial, yInitial);

        uint256 xSwap = 100 * 10 ** 18;

        // 기대 yOut 계산 (이벤트 파라미터 일치 검증용)
        uint256 k = miniAMM.k();
        uint256 expectedYOut = yInitial - (k / (xInitial + xSwap));

        vm.expectEmit(true, true, true, true);
        emit Swap(xSwap, expectedYOut);

        vm.prank(bob);
        miniAMM.swap(xSwap, 0);
    }
}
