// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface ILendbridge {

    function loanAndDeposit(address erc20, uint amt) external;

    function withdrawAndRepay(address erc20, address nErc20, uint nAmt) external;

    function getInterestRate(address erc20) external view returns(uint) ;

    function claimable() external view returns(bool);

    function claim(address debtToken) external returns(address, uint);

    function debtRewardPending(address debtToken, address _rewardToken) external view returns(uint);
}