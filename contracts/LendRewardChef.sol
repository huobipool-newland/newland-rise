// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./library/TransferHelper.sol";
import "./interface/IStakingRewards.sol";
import "./Treasury.sol";
import "./AccessSetting.sol";
import "./interface/ILendbridge.sol";

contract LendRewardChef is AccessSetting,IStakingRewards {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many Stake tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewarded;
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 stake; // Address of Stake token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. HPTs to distribute per block.
        uint256 lastRewardBlock; // Last block number that HPTs distribution occurs.
        uint256 accRewardPerShare; // Accumulated HPTs per share, times 1e12. See below.
        uint256 stakeBalance;
        Treasury treasury;
    }

    Treasury rewardTreasury;

    IERC20 public rewardToken;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    uint256 public rewardBalance;
    uint256 public rewardTotal;
    uint256 one = 1e18;

    mapping(address => uint) poolLenMap;
    ILendbridge lendbridge;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address token, address indexed user, address to, uint amount);

    constructor(
        IERC20 _rewardToken,
        uint256 _startBlock,
        ILendbridge _lendbridge
    ) public {
        rewardToken = _rewardToken;
        startBlock = _startBlock;
        lendbridge = _lendbridge;

        rewardTreasury = new Treasury();
        rewardToken.approve(address(rewardTreasury), uint256(-1));
    }

    function addReward(uint amount) public onlyOps {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        for(uint i = 0; i< poolInfo.length; i++) {
            rewardTreasury.deposit(address(poolInfo[i].stake),
                address(rewardToken),
                amount.mul(poolInfo[i].allocPoint).div(totalAllocPoint));
        }
    }

    function getRewardToken() view external override returns(address) {
        return address(rewardToken);
    }

    function getPid(address stake) public view override returns(uint) {
        if (poolLenMap[stake] > 0) {
            return poolLenMap[stake] - 1;
        }
        return uint(-1);
    }

    function poolLength() external view override returns (uint256) {
        return poolInfo.length;
    }

    function revoke() public onlyOwner {
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }

    // Add a new stake to the pool. Can only be called by the owner.
    // XXX DO NOT add the same Stake token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _stake
    ) public onlyOwner {
        require(poolLenMap[address(_stake)] == 0, 'stake pool already exist');
        massUpdatePools();
        uint256 lastRewardBlock =
        block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        Treasury treasury= new Treasury();
        rewardToken.approve(address(treasury), uint256(-1));

        poolInfo.push(
            PoolInfo({
            stake: _stake,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accRewardPerShare: 0,
            stakeBalance: 0,
            treasury: treasury
            })
        );
        poolLenMap[address(_stake)] = poolInfo.length;
    }

    // Update the given pool's HPT allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint
    ) public onlyOwner {
        require(address(poolInfo[_pid].stake) != address(0), 'pid not exist');
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function userTotalReward(uint pid, address user) public view returns(uint) {
        return userInfo[pid][user].rewarded + _pendingReward(pid, user);
    }

    function pendingReward(uint256 _pid, address _user)
    external
    view
    returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        return _pendingReward(_pid, _user) + pool.treasury.userTokenAmt(_user, address(rewardToken));
    }

    // View function to see pending HPTs on frontend.
    function _pendingReward(uint256 _pid, address _user)
    internal
    view
    returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 stakeSupply = pool.stakeBalance;
        if (stakeSupply != 0) {
            uint reward = lendbridge.debtRewardPending(address(pool.stake), address(rewardToken));
            accRewardPerShare = pool.accRewardPerShare.add(
                reward.mul(1e12).div(stakeSupply)
            );
        }
        return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 stakeSupply = pool.stakeBalance;
        if (stakeSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint reward = rewardTreasury.userTokenAmt(address(pool.stake), address(rewardToken));
        rewardTreasury.withdraw(address(pool.stake), address(rewardToken), reward, address(this));
        rewardBalance = rewardBalance.add(reward);
        rewardTotal = rewardTotal.add(reward);
        pool.accRewardPerShare = pool.accRewardPerShare.add(
            reward.mul(1e12).div(stakeSupply)
        );

        pool.lastRewardBlock = block.number;
    }

    function updateAmount(uint256 _pid, uint256 deltaBefore, uint256 deltaAfter, address _user) public onlyOps {
        if (deltaAfter > deltaBefore) {
            deposit(_pid, deltaAfter - deltaBefore, _user);
        } else if (deltaBefore > deltaAfter) {
            withdraw(_pid, deltaAfter - deltaBefore, _user);
        }
    }

    // Deposit Stake tokens to MasterChef for HPT allocation.
    function deposit(uint256 _pid, uint256 _amount, address _user) public override onlyOps {
        PoolInfo storage pool = poolInfo[_pid];
        updatePool(_pid);

        UserInfo storage user = userInfo[_pid][_user];
        if (user.amount > 0) {
            uint256 rewardPending =
            user.amount.mul(pool.accRewardPerShare).div(1e12).sub(
                user.rewardDebt
            );
            safeRewardTransfer(_pid, pool, _user, rewardPending);
        }

        pool.stakeBalance = pool.stakeBalance.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw Stake tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount, address _user) public override onlyOps {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);

        {
            uint256 pending =
            user.amount.mul(pool.accRewardPerShare).div(1e12).sub(
                user.rewardDebt
            );
            safeRewardTransfer(_pid, pool, _user, pending);
        }

        pool.stakeBalance = pool.stakeBalance.sub(_amount);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function claim(uint _pid, address token, address _user, address to) public override onlyOps returns(uint) {
        PoolInfo storage pool = poolInfo[_pid];
        withdraw(_pid, 0, _user);
        uint amount = pool.treasury.userTokenAmt(_user, address(token));
        if (amount > 0) {
            pool.treasury.withdraw(_user, address(token), amount, to);
            emit Claim(token, _user, to, amount);
        }
        return amount;
    }

    function claimAll(uint _pid, address _user, address to) public override onlyOps {
        claim(_pid, address(rewardToken), _user, to);
    }

    function safeRewardTransfer(uint256 pid, PoolInfo memory pool, address _to, uint256 _amount) internal {
        rewardBalance = rewardBalance.sub(_amount);
        userInfo[pid][_to].rewarded += _amount;
        uint256 rewardBal = rewardToken.balanceOf(address(this));
        if (_amount > rewardBal) {
            _amount = rewardBal;
        }

        if (_amount > 0) {
            pool.treasury.deposit(_to, address(rewardToken), _amount);
        }
    }

fallback() external {}
receive() payable external {}
}