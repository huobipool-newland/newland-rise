// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface InterestModel {
    function getInterestRate(address token, uint256 debt, uint256 floating, uint addInterestRateYear) external view returns (uint256);
}