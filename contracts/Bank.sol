// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./library/SafeToken.sol";
import "./interface/IBankConfig.sol";
import "./interface/Goblin.sol";
import "./NTokenFactory.sol";
import "./interface/ILendbridge.sol";
import "./interface/IBank.sol";
import "./interface/IStakingRewards.sol";

interface ILendRewardChef {
    function updateAmount(uint256 _pid, uint256 deltaBefore, uint256 deltaAfter, address _user) external;
    function addReward(address debtToken, uint amount) external;
    function poolInfo(uint256 _pid) external view returns (address, uint256, uint256, uint256, address);
}

contract Bank is NTokenFactory, Ownable, ReentrancyGuard, IBank {
    using SafeToken for address;
    using SafeMath for uint256;

    event OpPosition(uint256 indexed id, uint256 debt, uint back);
    event Liquidate(uint256 indexed id, address indexed killer, uint256 prize, uint256 left);

    struct TokenBank {
        address tokenAddr;   //支持存借的币种地址
        address nTokenAddr;  //对应的凭证币种地址
        bool isOpen;         //是否开启
        bool canDeposit;     //是否支持存入
        bool canWithdraw;    //是否支持借出
        uint256 totalVal;    //总数量
        uint256 totalDebt;   //总借出
        uint256 totalDebtShare;  //总的借出份额,用以计算利息
        uint256 totalReserve;    //累计利润
        uint256 lastInterestTime;  //上次计息时间
    }

    struct Production {
        address borrowToken;   //支持的可借币种
        bool isOpen;           //是否开启
        bool canBorrow;        //是否可借
        address goblin;        //挖矿功能的具体实现合约
        uint256 minDebt;       //最小可借的债务
        uint256 openFactor;    //开仓的最大倍数
        uint256 liquidateFactor;  //清算系数
        uint group;             //分组,用以页面展现
        bool liqVerifyOracle;   //是否启用外部预言机进行校验清算
    }

    struct Position {
        address owner;       //仓位持有人的地址
        uint256 productionId;   //仓位对应的产品编号
        uint256 debtShare;     //债务份额,可以换算出实际欠款
    }

    //参数配置
    IBankConfig public config;
    //借款桥
    ILendbridge public lendbridge;
    //挖矿奖励池
    IStakingRewards public lendRewardChef;

    //保存支持的存借币种
    mapping(address => TokenBank) public banks;
    address[] public bankTokens;

    //保存支持的挖矿交易对及对应配置
    mapping(uint256 => Production) public productions;
    uint256 public currentPid = 1;

    //保存用户持仓信息
    mapping(uint256 => Position) public positions;
    uint256 public currentPos = 1;

    mapping(address => uint[]) public userPositions;

    mapping(string => bool) enterLocks;

    modifier enterLock(string memory lock) {
        require(!enterLocks[lock], string(abi.encodePacked('enterLock reject ', lock)));
        enterLocks[lock] = true;
        _;
        enterLocks[lock] = false;
    }

    modifier onlyLendbridge() {
        require(address(lendbridge) == msg.sender, 'only lendbridge');
        _;
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "not eoa");
        _;
    }

    /// read
    function getBankTokens() external view returns(address[] memory) {
        return bankTokens;
    }

    function getUserPositions(address userAddr) external view returns(uint[] memory) {
        return userPositions[userAddr];
    }

    function positionInfo(uint256 posId) external view returns (uint256, uint256, uint256, address) {
        Position storage pos = positions[posId];
        Production storage prod = productions[pos.productionId];

        return (pos.productionId, Goblin(prod.goblin).health(posId, prod.borrowToken),
        debtShareToVal(prod.borrowToken, pos.debtShare), pos.owner);
    }

    function totalToken(address token) public view returns (uint256) {
        TokenBank storage bank = banks[token];
        require(bank.isOpen, 'token not exists');

        uint balance = token == address(0)? address(this).balance: SafeToken.myBalance(token);
        balance = bank.totalVal < balance? bank.totalVal: balance;

        return balance.add(bank.totalDebt).sub(bank.totalReserve);
    }

    function debtShareToVal(address token, uint256 debtShare) public view returns (uint256) {
        TokenBank storage bank = banks[token];
        require(bank.isOpen, 'token not exists');

        if (bank.totalDebtShare == 0) return debtShare;
        return debtShare.mul(bank.totalDebt).div(bank.totalDebtShare);
    }

    function debtValToShare(address token, uint256 debtVal) public view returns (uint256) {
        TokenBank storage bank = banks[token];
        require(bank.isOpen, 'token not exists');

        if (bank.totalDebt == 0) return debtVal;
        return debtVal.mul(bank.totalDebtShare).div(bank.totalDebt);
    }

    /// 存入bank，同时生成对应的nToken作为凭证
    function deposit(address token, uint256 amount) external payable override enterLock('daw') onlyLendbridge {
        TokenBank storage bank = banks[token];
        require(bank.isOpen && bank.canDeposit, 'Token not exist or cannot deposit');

        calInterest(token);

        if (token == address(0)) {//HT
            amount = msg.value;
        } else {
            SafeToken.safeTransferFrom(token, msg.sender, address(this), amount);
        }

        bank.totalVal = bank.totalVal.add(amount);
        uint256 total = totalToken(token).sub(amount);
        uint256 pTotal = NToken(bank.nTokenAddr).totalSupply();

        uint256 pAmount = (total == 0 || pTotal == 0) ? amount: amount.mul(pTotal).div(total);
        NToken(bank.nTokenAddr).mint(msg.sender, pAmount);
    }

    //还款，输入nToken数量，返还存款
    function withdraw(address token, uint256 pAmount) external override enterLock('daw') onlyLendbridge {
        TokenBank storage bank = banks[token];
        require(bank.isOpen && bank.canWithdraw, 'Token not exist or cannot withdraw');

        calInterest(token);

        uint256 amount = pAmount.mul(totalToken(token)).div(NToken(bank.nTokenAddr).totalSupply());
        bank.totalVal = bank.totalVal.sub(amount);

        NToken(bank.nTokenAddr).burn(msg.sender, pAmount);
        token.opTransfer(msg.sender, amount);
    }

    /// @dev Work on the given position. Must be called by the EOA.
    /// @param posId The position ID to work on,if equal to zero means new position.
    /// @param pid The production ID to work on
    /// @param borrow The amount user borrow form bank.
    /// @param data The encoded data, consisting of strategy address and bytes to strategy.
    function opPosition(uint256 posId, uint256 pid, uint256 borrow, bytes calldata data)
    external payable onlyEOA nonReentrant {
        _opPosition(posId, pid, borrow, data);
    }

    //复投，先领取收益再对指定仓位进行加仓
    function reInvest(uint256 claimPosId, address toToken, uint256 posId, uint256 pid, address token0, address token1, address addStrategy)external payable onlyEOA nonReentrant  {
        Position storage pos = positions[claimPosId];
        require(msg.sender == pos.owner, "not position owner");
        Production storage production = productions[pos.productionId];
        bytes memory data = Goblin(production.goblin).reInvestData(pos.owner, toToken, token0, token1, addStrategy);
        _opPosition(posId, pid, 0, data);
    }

    function _opPosition(uint256 posId, uint256 pid, uint256 borrow, bytes memory data) internal {
        bool isNewPos = false;
        if (posId == 0) {
            posId = currentPos;
            currentPos ++;
            positions[posId].owner = msg.sender;
            positions[posId].productionId = pid;
            isNewPos = true;
            userPositions[msg.sender].push(posId);
        } else {
            require(posId < currentPos, "bad position id");
            require(positions[posId].owner == msg.sender, "not position owner");
            isNewPos = false;
            pid = positions[posId].productionId;
        }

        Production storage production = productions[pid];
        require(production.isOpen, 'Production not exists');

        require(borrow == 0 || production.canBorrow, "Production can not borrow");
        borrowLendbridge(borrow, production);
        calInterest(production.borrowToken);

        uint dsBefore = positions[posId].debtShare;
        uint256 debt = _removeDebt(positions[posId], production).add(borrow);

        uint256 sendHT = msg.value;
        uint256 beforeToken = 0;
        if (production.borrowToken == address(0)) {
            sendHT = sendHT.add(borrow);
            require(sendHT <= address(this).balance && debt <= banks[production.borrowToken].totalVal, "insufficient HT in the bank");
            beforeToken = address(this).balance.sub(sendHT);
        } else {
            beforeToken = SafeToken.myBalance(production.borrowToken);
            require(borrow <= beforeToken && debt <= banks[production.borrowToken].totalVal, "insufficient borrowToken in the bank");
            beforeToken = beforeToken.sub(borrow);
            SafeToken.safeApprove(production.borrowToken, production.goblin, 0);
            SafeToken.safeApprove(production.borrowToken, production.goblin, borrow);
        }

        Goblin(production.goblin).work{value: sendHT}(posId, msg.sender, production.borrowToken, borrow, debt, data);

        uint256 backToken = production.borrowToken == address(0) ? (address(this).balance.sub(beforeToken)) :
        SafeToken.myBalance(production.borrowToken).sub(beforeToken);

        if(backToken > debt) { //没有借款, 有剩余退款
            backToken = backToken.sub(debt);
            debt = 0;

            production.borrowToken == address(0) ? SafeToken.safeTransferETH(msg.sender, backToken):
            SafeToken.safeTransfer(production.borrowToken, msg.sender, backToken);
        } else if (debt > backToken) { //有借款
            debt = debt.sub(backToken);
            backToken = 0;

            require(debt >= production.minDebt, "too small debt size");

            uint256 health = Goblin(production.goblin).health(posId, production.borrowToken);
            if(isNewPos || health == 0){
                require(health.mul(production.openFactor) >= debt.mul(10000), "bad work factor");
            }
            
            _addDebt(positions[posId], production, debt);
        }
        updateLendChef(positions[posId], production, dsBefore);
        repayLendbridge(production);
        emit OpPosition(posId, debt, backToken);
    }

    function borrowLendbridge(uint borrow, Production memory production) internal {
        uint balance = production.borrowToken.opBalance();
        if (production.borrowToken == address(0)) {
            balance = balance - msg.value;
        }
        if (borrow > balance) {
            lendbridge.loanAndDeposit(production.borrowToken, borrow - balance);
        }
    }
    //从借款桥发起还款
    function repayLendbridge(Production memory production) internal {
        if (address(lendbridge) == address(0)) {
            return;
        }
        TokenBank storage borrowBank = banks[production.borrowToken];
        uint256 total = totalToken(production.borrowToken);
        uint256 nTotal = NToken(borrowBank.nTokenAddr).totalSupply();
        uint borrowBankAmt = production.borrowToken.opBalance();
        if (borrowBankAmt > borrowBank.totalReserve) {
            borrowBankAmt = borrowBankAmt - borrowBank.totalReserve;
            uint nAmount = (total == 0 || nTotal == 0) ? borrowBankAmt: borrowBankAmt.mul(nTotal).div(total);
            lendbridge.withdrawAndRepay(production.borrowToken, borrowBank.nTokenAddr, nAmount);
        }
    }

    //清算
    function liquidate(uint256 posId) external payable onlyEOA nonReentrant {
        Position storage pos = positions[posId];
        require(pos.debtShare > 0, "no debt");
        Production storage production = productions[pos.productionId];

        calInterest(production.borrowToken);
        uint dsBefore = pos.debtShare;
        uint256 debt = _removeDebt(pos, production);

        uint256 health = Goblin(production.goblin).health(posId, production.borrowToken);
        require(health.mul(production.liquidateFactor) < debt.mul(10000), "health: can't liquidate");

        if (production.liqVerifyOracle) {
            uint256 healthOracle = Goblin(production.goblin).healthOracle(posId, production.borrowToken);
            require(healthOracle.mul(production.liquidateFactor) < debt.mul(10000), "healthOracle: can't liquidate");
        }

        bool isHT = production.borrowToken == address(0);
        uint256 before = isHT? address(this).balance: SafeToken.myBalance(production.borrowToken);

        Goblin(production.goblin).liquidate(posId, pos.owner, production.borrowToken);

        uint256 back = isHT? address(this).balance: SafeToken.myBalance(production.borrowToken);
        back = back.sub(before);

        uint256 prize = back.mul(config.getLiquidateBps()).div(10000);
        uint256 rest = back.sub(prize);
        uint256 left = 0;

        if (prize > 0) {
            isHT? SafeToken.safeTransferETH(msg.sender, prize): SafeToken.safeTransfer(production.borrowToken, msg.sender, prize);
        }
        if (rest > debt) {
            left = rest.sub(debt);
            isHT? SafeToken.safeTransferETH(pos.owner, left): SafeToken.safeTransfer(production.borrowToken, pos.owner, left);
        } else {
            banks[production.borrowToken].totalVal = banks[production.borrowToken].totalVal.sub(debt).add(rest);
        }
        updateLendChef(positions[posId], production, dsBefore);
        repayLendbridge(production);
        emit Liquidate(posId, msg.sender, prize, left);
    }

    //领取所有
    function claimWithGoblins(address[] memory goblins, bool claimLendReward) external onlyEOA nonReentrant {
        for(uint i = 0; i< goblins.length; i++) {
            Goblin(goblins[i]).claim(msg.sender, msg.sender);
        }
        if (claimLendReward) {
            claimLendbridge();
        }
        calInterstAll();
    }

    function _addDebt(Position storage pos, Production storage production, uint256 debtVal) internal {
        if (debtVal == 0) {
            return;
        }

        TokenBank storage bank = banks[production.borrowToken];

        uint256 debtShare = debtValToShare(production.borrowToken, debtVal);
        pos.debtShare = pos.debtShare.add(debtShare);

        bank.totalVal = bank.totalVal.sub(debtVal);
        bank.totalDebtShare = bank.totalDebtShare.add(debtShare);
        bank.totalDebt = bank.totalDebt.add(debtVal);
    }

    function _removeDebt(Position storage pos, Production storage production) internal returns (uint256) {
        TokenBank storage bank = banks[production.borrowToken];

        uint256 debtShare = pos.debtShare;
        if (debtShare > 0) {
            uint256 debtVal = debtShareToVal(production.borrowToken, debtShare);
            pos.debtShare = 0;

            bank.totalVal = bank.totalVal.add(debtVal);
            bank.totalDebtShare = bank.totalDebtShare.sub(debtShare);
            bank.totalDebt = bank.totalDebt.sub(debtVal);
            return debtVal;
        } else {
            return 0;
        }
    }

    //刷新借款补贴
    function updateLendChef(Position storage pos, Production storage production, uint dsBefore) internal {
        if (address(lendbridge) != address(0) && lendbridge.claimable()) {
            _claimLendbridge(production.borrowToken);
        }
        if (address(lendRewardChef) != address(0)) {
            uint lendChefPid = lendRewardChef.getPid(production.borrowToken);
            if (lendChefPid < uint(-1)) {
                ILendRewardChef(address(lendRewardChef)).updateAmount(lendChefPid, dsBefore, pos.debtShare, pos.owner);
            }
        }
    }

    function updateConfig(IBankConfig _config) external onlyOwner {
        config = _config;
    }

    function updateLendbridge(ILendbridge _lendbridge) external onlyOwner {
        lendbridge = _lendbridge;
    }

    function updateLendRewardChef(IStakingRewards _lendRewardChef) external onlyOwner {
        lendRewardChef = _lendRewardChef;
    }

    //添加bank中支持的币种
    function addToken(address token, string calldata _symbol) external onlyOwner {
        TokenBank storage bank = banks[token];
        require(!bank.isOpen, 'token already exists');

        bank.isOpen = true;
        address nToken = genNToken(_symbol);
        bank.tokenAddr = token;
        bank.nTokenAddr = nToken;
        bank.canDeposit = true;
        bank.canWithdraw = true;
        bank.totalVal = 0;
        bank.totalDebt = 0;
        bank.totalDebtShare = 0;
        bank.totalReserve = 0;
        bank.lastInterestTime = now;

        bankTokens.push(token);
    }

    function updateToken(address token, bool canDeposit, bool canWithdraw) external onlyOwner {
        TokenBank storage bank = banks[token];
        require(bank.isOpen, 'token not exists');

        bank.canDeposit = canDeposit;
        bank.canWithdraw = canWithdraw;
    }

    //添加产品
    function opProduction(uint256 pid, bool isOpen, bool canBorrow, address borrowToken, address goblin,
        uint256 minDebt, uint256 openFactor, uint256 liquidateFactor, uint group, bool liqVerifyOracle) external onlyOwner {

        if(pid == 0){
            pid = currentPid;
            currentPid ++;
        } else {
            require(pid < currentPid, "bad production id");
        }

        Production storage production = productions[pid];
        production.isOpen = isOpen;
        production.canBorrow = canBorrow;
        // 地址一旦设置, 就不要再改, 可以添加新币对!
        production.borrowToken = borrowToken;
        production.goblin = goblin;

        production.minDebt = minDebt;
        production.openFactor = openFactor;
        production.liquidateFactor = liquidateFactor;
        production.group = group;
        production.liqVerifyOracle = liqVerifyOracle;
    }

    //刷新收益
    function calInterest(address token) public {
        TokenBank storage bank = banks[token];
        require(bank.isOpen, 'token not exists');

        if (now > bank.lastInterestTime) {
            uint256 timePast = now.sub(bank.lastInterestTime);
            uint256 totalDebt = bank.totalDebt;
            uint256 totalBalance = totalToken(token);

            uint256 ratePerSec = config.getInterestRate(token, totalDebt, totalBalance);
            uint256 interest = ratePerSec.mul(timePast).mul(totalDebt).div(1e18);

            uint256 toReserve = interest.mul(config.getDyReserveBps(ratePerSec)).div(10000);
            bank.totalReserve = bank.totalReserve.add(toReserve);
            bank.totalDebt = bank.totalDebt.add(interest);
            bank.lastInterestTime = now;
        }
    }

    function calInterstAll() public {
        for(uint i = 0; i<bankTokens.length;i++) {
            address token = bankTokens[i];
            TokenBank storage bank = banks[token];
            if (bank.isOpen) {
                calInterest(token);
            }
        }
    }

    function withdrawReserve(address token, address to, uint256 value) external onlyOwner nonReentrant {
        TokenBank storage bank = banks[token];
        require(bank.isOpen, 'token not exists');

        uint balance = token == address(0)? address(this).balance: SafeToken.myBalance(token);
        if(balance >= bank.totalVal.add(value)) {
            //非deposit存入
        } else {
            bank.totalReserve = bank.totalReserve.sub(value);
            bank.totalVal = bank.totalVal.sub(value);
        }

        token.opTransfer(to, value);
    }

    function claimLendbridge() public {
        if (address(lendbridge) != address(0) && lendbridge.claimable()) {
            for(uint i = 0; i<lendRewardChef.poolLength(); i++) {
                (address token,,,,) = ILendRewardChef(address(lendRewardChef)).poolInfo(i);
                _claimLendbridge(token);
                lendRewardChef.claimAll(i, msg.sender, msg.sender);
            }
        }
    }

    function _claimLendbridge(address debtToken) internal returns(address, uint){
        (address token, uint claimAmt) = lendbridge.claim(debtToken);
        if (claimAmt <= 0) {
            return (token, 0);
        }
        token.safeApprove(address(lendRewardChef), 0);
        token.safeApprove(address(lendRewardChef), claimAmt);
        ILendRewardChef(address(lendRewardChef)).addReward(debtToken, claimAmt);
        return (token, claimAmt);
    }

fallback() external {}
receive() payable external {}
}