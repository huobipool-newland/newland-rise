// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface ISwapMining {

    /// The user withdraws all the transaction rewards of the pool
    function takerWithdraw() external;

    /// Get rewards from users in the current pool
    /// @param pid pid of pair.
    function getUserReward(uint256 pid) external view returns (uint256, uint256);

}