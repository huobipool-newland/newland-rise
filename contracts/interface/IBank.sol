// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IBank {

    function deposit(address token, uint256 amount) external payable;

    function withdraw(address token, uint256 pAmount) external;

}
