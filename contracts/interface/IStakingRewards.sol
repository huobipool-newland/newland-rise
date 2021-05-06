// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IStakingRewards {

    function deposit(uint256 _pid, uint256 amount, address user) external;

    function withdraw(uint256 _pid, uint256 amount, address user) external;

    function claim(uint _pid, address token, address _user, address to) external returns(uint);

    function claimAll(uint _pid, address _user, address to) external;

    function getPid(address stakingToken) external returns(uint);

    function getRewardToken() external returns(address);
}
