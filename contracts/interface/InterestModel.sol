// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface InterestModel {
    function getInterestRate(uint256 debt, uint256 floating) external view returns (uint256);
}