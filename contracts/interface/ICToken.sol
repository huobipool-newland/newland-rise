// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface ICToken {

    function borrow(uint borrowAmount) external returns (uint);

    function repayBorrow(uint repayAmount) external returns (uint);

    function borrowRatePerBlock() external view returns (uint);

    function mint(uint mintAmount) external returns (uint);

    function redeem(uint redeemTokens) external returns (uint);
}
