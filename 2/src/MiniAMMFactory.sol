// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IMiniAMMFactory} from "./IMiniAMMFactory.sol";
import {MiniAMM} from "./MiniAMM.sol";

// Add as many variables or functions as you would like
// for the implementation. The goal is to pass `forge test`.
contract MiniAMMFactory is IMiniAMMFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 pairNumber);

    constructor() {}

    // implement
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    // implement
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "Identical addresses");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");

        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(getPair[t0][t1] == address(0), "Pair exists");

        MiniAMM newPair = new MiniAMM(t0, t1);
        pair = address(newPair);

        getPair[t0][t1] = pair;
        getPair[t1][t0] = pair;

        allPairs.push(pair);
        emit PairCreated(t0, t1, pair, allPairs.length);
    }
}
