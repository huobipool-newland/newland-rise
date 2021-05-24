// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface ILendbridge {

    function loanAndDeposit(address erc20, uint amt) external;

    function withdrawAndRepay(address erc20, address nErc20, uint nAmt) external;

    function getInterestRate(address erc20) external view returns(uint) ;

    function claim() external returns(address, uint);
}