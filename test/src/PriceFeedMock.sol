// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PriceFeedMock {
    // 1 Euro = 10 Wei
    function getLatestPrice() external pure returns (uint256) {
        return 10; 
    }
}