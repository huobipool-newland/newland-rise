// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IPriceOracle {

    function getPrice(address token) external view returns (int, uint);

}