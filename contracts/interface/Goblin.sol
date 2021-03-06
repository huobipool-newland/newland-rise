// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface Goblin {

    /// @dev Work on a (potentially new) position. Optionally send surplus token back to Bank.
    function work(uint256 id, address user, address borrowToken, uint256 borrow, uint256 debt, bytes calldata data) external payable;

    /// @dev Return the amount of ETH wei to get back if we are to liquidate the position.
    function health(uint256 id, address borrowToken) external view returns (uint256);

    /// @dev Return the amount of ETH wei to get back if we are to liquidate the position.
    function healthOracle(uint256 id, address borrowToken) external view returns (uint256);

    /// @dev Liquidate the given position to token need. Send all ETH back to Bank.
    function liquidate(uint256 id, address user, address borrowToken) external;

    function reInvestData(address owner, address toToken, address token0, address token1, address addStrategy) external returns(bytes memory);

    function claim(address user, address to) external;
}