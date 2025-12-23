// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleMath {
    // Simple function that adds two numbers
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }
    
    // Simple function that multiplies two numbers
    function multiply(uint256 a, uint256 b) public pure returns (uint256) {
        return a * b;
    }
    
    // Function with a require statement
    function divide(uint256 a, uint256 b) public pure returns (uint256) {
        require(b > 0, "Division by zero");
        return a / b;
    }
}