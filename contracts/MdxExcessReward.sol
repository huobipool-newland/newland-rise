// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "./interface/ISwapMining.sol";
import "./library/SafeToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MdxExcessReward is Ownable, ReentrancyGuard {
    using SafeToken for address;

    /// @param minter The address of MDex SwapMining contract.
    /// @param pid pid of pair in SwapMining config.
    function getSwapReward(address minter, uint256 pid) public view returns (uint256, uint256) {
        ISwapMining swapMining = ISwapMining(minter);
        return swapMining.getUserReward(pid);
    }

    /// @param minter The address of MDex SwapMining contract.
    /// @param token Token of reward. Result of pairOfPid(lpTokenAddress)
    function swapMiningReward(address minter, address token) external onlyOwner{
        ISwapMining swapMining = ISwapMining(minter);
        swapMining.takerWithdraw();
        token.safeTransfer(msg.sender, token.myBalance());
    }

    /// @dev Recover ERC20 tokens that were accidentally sent to this smart contract.
    /// @param token The token contract. Can be anything. This contract should not hold ERC20 tokens.
    /// @param to The address to send the tokens to.
    function recover(address token, address to) external onlyOwner nonReentrant {
        token.safeTransfer(to, token.myBalance());

        uint cb = address(this).balance;
        if (cb > 0) {
            msg.sender.transfer(cb);
        }
    }
}