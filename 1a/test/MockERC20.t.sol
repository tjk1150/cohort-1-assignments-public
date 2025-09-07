// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract MockERC20Test is Test {
    MockERC20 public token;
    address public alice = address(0x1);
    address public bob = address(0x2);

    /// @notice 테스트 시작 전에 매번 실행되어 기본 상태를 세팅하는 함수
    ///         - MockERC20 토큰을 새로 배포
    function setUp() public {
        token = new MockERC20("Mock Token", "MTK");
    }

    /// @notice 토큰 배포(생성자) 시 설정값이 올바른지 확인하는 테스트
    ///         - 이름, 심볼, 소수점, 총 발행량(0) 검증
    function test_Constructor() public view {
        assertEq(token.name(), "Mock Token");
        assertEq(token.symbol(), "MTK");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }


    /// @notice freeMintTo() 함수를 이용해 특정 주소(alice)로 토큰을 민트하는 테스트
    ///         - 민트 전 잔액이 0인지 확인
    ///         - 민트 후 alice 잔액과 totalSupply가 증가했는지 확인
    function test_FreeMintTo() public {
        uint256 mintAmount = 1000 * 10 ** 18; // 1000 tokens

        // Initial balance should be 0
        assertEq(token.balanceOf(alice), 0);

        // Mint tokens to alice
        token.freeMintTo(mintAmount, alice);

        // Check that alice received the tokens
        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    /// @notice freeMintToSender() 함수를 이용해 msg.sender에게 토큰을 민트하는 테스트
    ///         - prank을 사용해 msg.sender를 alice로 변경
    ///         - 민트 전 alice 잔액이 0인지 확인
    ///         - 민트 후 alice 잔액과 totalSupply가 증가했는지 확인
    function test_FreeMintToSender() public {
        uint256 mintAmount = 2000 * 10 ** 18; // 2000 tokens

        // Start acting as alice
        vm.startPrank(alice);

        // Initial balance should be 0
        assertEq(token.balanceOf(alice), 0);

        // Mint tokens to sender (alice)
        token.freeMintToSender(mintAmount);

        // Check that alice received the tokens
        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalSupply(), mintAmount);

        vm.stopPrank();
    }
}
