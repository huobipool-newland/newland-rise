// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardCounter is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct RewardInfo {
        uint256 rewardBalance;
        uint256 rewardTotal;
        uint accPerShare;
        uint chipTotal;
    }
    mapping(address => RewardInfo) rewardInfos;

    // Info of each user.
    struct UserInfo {
        uint256 chip;
        uint256 rewardDebt;
        uint holdReward;
    }
    mapping(address => mapping(address => UserInfo)) userInfos;

    function addReward(address token, uint reward) public onlyOwner {
        RewardInfo storage rewardInfo = rewardInfos[token];
        rewardInfo.rewardBalance = rewardInfo.rewardBalance.add(reward);
        rewardInfo.rewardTotal = rewardInfo.rewardTotal.add(reward);
        rewardInfo.accPerShare = rewardInfo.accPerShare.add(
            reward.mul(1e12).div(rewardInfo.chipTotal)
        );
    }

    function updateChip(address user, address token, uint chip) public onlyOwner {
        UserInfo storage userInfo = userInfos[user][token];
        RewardInfo storage rewardInfo = rewardInfos[token];
        if (userInfo.chip > 0) {
            uint256 pending =
            userInfo.chip.mul(rewardInfo.accPerShare).div(1e12).sub(
                userInfo.rewardDebt
            );
            userInfo.holdReward += pending;
            rewardInfo.rewardBalance = rewardInfo.rewardBalance.sub(pending);
        }

        if (userInfo.chip < chip) {
            rewardInfo.chipTotal = rewardInfo.chipTotal.add(chip - userInfo.chip);
        } else {
            rewardInfo.chipTotal = rewardInfo.chipTotal.sub(userInfo.chip - chip);
        }

        userInfo.chip = chip;
        userInfo.rewardDebt = userInfo.chip.mul(rewardInfo.accPerShare).div(1e12);
    }

    function claim(address user, address token) public onlyOwner {
        UserInfo storage userInfo = userInfos[user][token];
        userInfo.holdReward = 0;
    }
}