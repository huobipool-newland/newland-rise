// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IWHT.sol";
import "./library/TransferHelper.sol";
import "./interface/IStakingRewards.sol";
import "./Treasury.sol";

contract NTokenStaking is Ownable,IStakingRewards {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many Stake tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 giftRewarded;
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 stake; // Address of Stake token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. HPTs to distribute per block.
        uint256 lastRewardBlock; // Last block number that HPTs distribution occurs.
        uint256 accGiftPerShare; // Accumulated HPTs per share, times 1e12. See below.
        uint256 stakeBalance;
        Treasury treasury;
    }

    struct OpInfo {
        address op;
        bool enable;
    }
    mapping(address => OpInfo) opInfoMap;

    // The HPT TOKEN!
    IERC20 public gift;
    // HPT tokens created per block.
    uint256 public giftPerBlock;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes Stake tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when HPT mining starts.
    uint256 public startBlock;
    uint256 public giftRewardBalance;
    uint256 public giftRewardTotal;
    address public factory;
    address public WHT;
    uint256 one = 1e18;

    mapping(address => uint) poolLenMap;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event Claim(address token, address indexed user, address to, uint amount);

    constructor(
        IERC20 _gift,
        uint256 _giftPerBlock,
        uint256 _startBlock,
        address _WHT
    ) public {
        gift = _gift;
        giftPerBlock = _giftPerBlock;
        startBlock = _startBlock;
        WHT = _WHT;
    }

    modifier checkOp() {
        require(opInfoMap[msg.sender].enable);
        _;
    }

    function getRewardToken() external override returns(address) {
        return address(gift);
    }

    function getPid(address stake) public override returns(uint) {
        if (poolLenMap[stake] > 0) {
            return poolLenMap[stake] - 1;
        }
        return uint(-1);
    }

    function setOps(address op, bool enable) public onlyOwner {
        if (opInfoMap[op].op == address(0)) {
            opInfoMap[op].op = op;
        }
        opInfoMap[op].enable = enable;
    }

    function setGiftPerBlock(uint _giftPerBlock) public onlyOwner {
        massUpdatePools();
        giftPerBlock = _giftPerBlock;
    }

    function giftRewardPerBlock(uint _pid) external view returns(uint)  {
        PoolInfo storage pool = poolInfo[_pid];
        return giftPerBlock.mul(pool.allocPoint).div(totalAllocPoint);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function revoke() public onlyOwner {
        gift.transfer(msg.sender, gift.balanceOf(address(this)));
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
        gift.approve(address(treasury), uint256(-1));

        poolInfo.push(
            PoolInfo({
            stake: _stake,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accGiftPerShare: 0,
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
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
    internal
    pure
    returns (uint256)
    {
        return _to.sub(_from);
    }

    function userTotalGiftReward(uint pid, address user) public view returns(uint) {
        return userInfo[pid][user].giftRewarded + _pendingGift(pid, user);
    }

    function pendingGift(uint256 _pid, address _user)
    external
    view
    returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        return _pendingGift(_pid, _user) + pool.treasury.userTokenAmt(_user, address(gift));
    }

    // View function to see pending HPTs on frontend.
    function _pendingGift(uint256 _pid, address _user)
    internal
    view
    returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accGiftPerShare = pool.accGiftPerShare;
        uint256 stakeSupply = pool.stakeBalance;
        if (block.number > pool.lastRewardBlock && stakeSupply != 0) {
            uint256 multiplier =
            getMultiplier(pool.lastRewardBlock, block.number);
            uint256 giftReward =
            multiplier.mul(giftPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
            accGiftPerShare = accGiftPerShare.add(
                giftReward.mul(1e12).div(stakeSupply)
            );
        }
        return user.amount.mul(accGiftPerShare).div(1e12).sub(user.rewardDebt);
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
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 giftReward =
        multiplier.mul(giftPerBlock).mul(pool.allocPoint).div(
            totalAllocPoint
        );
        giftRewardBalance = giftRewardBalance.add(giftReward);
        giftRewardTotal = giftRewardTotal.add(giftReward);
        pool.accGiftPerShare = pool.accGiftPerShare.add(
            giftReward.mul(1e12).div(stakeSupply)
        );

        pool.lastRewardBlock = block.number;
    }

    // Deposit Stake tokens to MasterChef for HPT allocation.
    function deposit(uint256 _pid, uint256 _amount, address _user) public override checkOp {
        PoolInfo storage pool = poolInfo[_pid];
        updatePool(_pid);

        UserInfo storage user = userInfo[_pid][_user];
        if (user.amount > 0) {
            // reward gift
            uint256 giftPending =
            user.amount.mul(pool.accGiftPerShare).div(1e12).sub(
                user.rewardDebt
            );
            safeGiftTransfer(_pid, pool, _user, giftPending);
        }

        pool.stake.safeTransferFrom(msg.sender, address(this), _amount);

        pool.stakeBalance = pool.stakeBalance.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accGiftPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw Stake tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount, address _user) public override checkOp {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);

        {
            // reward gift
            uint256 pending =
            user.amount.mul(pool.accGiftPerShare).div(1e12).sub(
                user.rewardDebt
            );
            safeGiftTransfer(_pid, pool, _user, pending);
        }

        pool.stakeBalance = pool.stakeBalance.sub(_amount);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accGiftPerShare).div(1e12);

        pool.stake.safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function claim(uint _pid, address token, address _user, address to) public override checkOp returns(uint) {
        PoolInfo storage pool = poolInfo[_pid];
        withdraw(_pid, 0, _user);
        uint amount = pool.treasury.userTokenAmt(_user, address(token));
        pool.treasury.withdraw(_user, address(token), amount, to);
        emit Claim(token, _user, to, amount);

        return amount;
    }

    function claimAll(uint _pid, address _user, address to) public override checkOp {
        claim(_pid, address(gift), _user, to);
    }

    function safeGiftTransfer(uint256 pid, PoolInfo memory pool, address _to, uint256 _amount) internal {
        giftRewardBalance = giftRewardBalance.sub(_amount);
        userInfo[pid][_to].giftRewarded += _amount;
        uint256 giftBal = gift.balanceOf(address(this));
        if (_amount > giftBal) {
            _amount = giftBal;
        }

        pool.treasury.deposit(_to, address(gift), _amount);
    }

fallback() external {}
receive() payable external {}
}