// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IBankConfig {

    function getInterestRate(address token, uint256 debt, uint256 floating) external view returns (uint256);

    function getDyReserveBps(uint rate) external view returns (uint256);

    function getLiquidateBps() external view returns (uint256);
}