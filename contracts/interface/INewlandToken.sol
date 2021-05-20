// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface INewlandToken {

    function borrow(uint borrowAmount) external returns (uint);

    function repayBorrow(uint repayAmount) external returns (uint);

    function getInterestRate() external view returns (uint);
}
