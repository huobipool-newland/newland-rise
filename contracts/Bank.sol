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

contract Bank is NTokenFactory, Ownable, ReentrancyGuard, IBank {
    using SafeToken for address;
    using SafeMath for uint256;

    event OpPosition(uint256 indexed id, uint256 debt, uint back);
    event Liquidate(uint256 indexed id, address indexed killer, uint256 prize, uint256 left);

    struct TokenBank {
        address tokenAddr;
        address nTokenAddr;
        bool isOpen;
        bool canDeposit;
        bool canWithdraw;
        uint256 totalVal;
        uint256 totalDebt;
        uint256 totalDebtShare;
        uint256 totalReserve;
        uint256 lastInterestTime;
    }

    struct Production {
        address borrowToken;
        bool isOpen;
        bool canBorrow;
        address goblin;
        uint256 minDebt;
        uint256 openFactor;
        uint256 liquidateFactor;
        uint group;
        bool liqVerifyOracle;
    }

    struct Position {
        address owner;
        uint256 productionId;
        uint256 debtShare;
    }

    IBankConfig public config;
    ILendbridge public lendbridge;

    mapping(address => TokenBank) public banks;
    address[] public bankTokens;

    mapping(uint256 => Production) public productions;
    uint256 public currentPid = 1;

    mapping(uint256 => Position) public positions;
    uint256 public currentPos = 1;

    mapping(address => uint[]) public userPositions;

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

    /// write
    function deposit(address token, uint256 amount) external payable override nonReentrant {
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

    function withdraw(address token, uint256 pAmount) external override nonReentrant {
        TokenBank storage bank = banks[token];
        require(bank.isOpen && bank.canWithdraw, 'Token not exist or cannot withdraw');

        calInterest(token);

        uint256 amount = pAmount.mul(totalToken(token)).div(NToken(bank.nTokenAddr).totalSupply());
        bank.totalVal = bank.totalVal.sub(amount);

        NToken(bank.nTokenAddr).burn(msg.sender, pAmount);
        opTransfer(token, msg.sender, amount);
    }

    function opPosition(uint256 posId, uint256 pid, uint256 borrow, bytes calldata data)
    external payable onlyEOA nonReentrant {
        _opPosition(posId, pid, borrow, data);
    }

    function reInvest(uint256 claimPosId, address toToken, uint256 posId, uint256 pid, uint256 borrow, bytes calldata data)external payable onlyEOA nonReentrant  {
        Position storage pos = positions[claimPosId];
        require(msg.sender == pos.owner, "not position owner");
        Production storage production = productions[pos.productionId];

        Goblin(production.goblin).claimAndSwap(toToken, pos.owner, pos.owner);
        _opPosition(posId, pid, borrow, data);
    }

    function _opPosition(uint256 posId, uint256 pid, uint256 borrow, bytes calldata data) internal {
        if (posId == 0) {
            posId = currentPos;
            currentPos ++;
            positions[posId].owner = msg.sender;
            positions[posId].productionId = pid;

            userPositions[msg.sender].push(posId);
        } else {
            require(posId < currentPos, "bad position id");
            require(positions[posId].owner == msg.sender, "not position owner");

            pid = positions[posId].productionId;
        }

        Production storage production = productions[pid];
        require(production.isOpen, 'Production not exists');

        require(borrow == 0 || production.canBorrow, "Production can not borrow");
        calInterest(production.borrowToken);

        uint256 debt = _removeDebt(positions[posId], production).add(borrow);
        bool isBorrowHt = production.borrowToken == address(0);

        uint256 sendHT = msg.value;
        uint256 beforeToken = 0;
        if (isBorrowHt) {
            sendHT = sendHT.add(borrow);
            require(sendHT <= address(this).balance && debt <= banks[production.borrowToken].totalVal, "insufficient HT in the bank");
            beforeToken = address(this).balance.sub(sendHT);
        } else {
            beforeToken = SafeToken.myBalance(production.borrowToken);
            bool pass = borrow <= beforeToken && debt <= banks[production.borrowToken].totalVal;
            if (!pass && address(lendbridge) != address(0)) {
                lendbridge.loanAndDeposit(production.borrowToken, borrow);
                beforeToken = SafeToken.myBalance(production.borrowToken);
                pass = borrow <= beforeToken && debt <= banks[production.borrowToken].totalVal;
            }
            require(pass, "insufficient borrowToken in the bank");
            beforeToken = beforeToken.sub(borrow);
            SafeToken.safeApprove(production.borrowToken, production.goblin, borrow);
        }

        Goblin(production.goblin).work{value: sendHT}(posId, msg.sender, production.borrowToken, borrow, debt, data);

        uint256 backToken = isBorrowHt? (address(this).balance.sub(beforeToken)) :
        SafeToken.myBalance(production.borrowToken).sub(beforeToken);

        if(backToken > debt) { //没有借款, 有剩余退款
            backToken = backToken.sub(debt);
            debt = 0;

            isBorrowHt? SafeToken.safeTransferETH(msg.sender, backToken):
            SafeToken.safeTransfer(production.borrowToken, msg.sender, backToken);
        } else if (debt > backToken) { //有借款
            debt = debt.sub(backToken);
            backToken = 0;

            require(debt >= production.minDebt, "too small debt size");
            uint256 health = Goblin(production.goblin).health(posId, production.borrowToken);
            require(health.mul(production.openFactor) >= debt.mul(10000), "bad work factor");

            _addDebt(positions[posId], production, debt);
        }
        repayLendbridge(production);
        emit OpPosition(posId, debt, backToken);
    }

    function repayLendbridge(Production memory production) internal {
        if (address(lendbridge) == address(0)) {
            return;
        }
        bool isBorrowHt = production.borrowToken == address(0);
        if (!isBorrowHt) {
            TokenBank storage borrowBank = banks[production.borrowToken];
            uint256 total = totalToken(production.borrowToken);
            uint256 nTotal = NToken(borrowBank.nTokenAddr).totalSupply();
            uint borrowBankAmt = SafeToken.myBalance(production.borrowToken);
            uint nAmount = (total == 0 || nTotal == 0) ? borrowBankAmt: borrowBankAmt.mul(nTotal).div(total);
            lendbridge.withdrawAndRepay(production.borrowToken, borrowBank.nTokenAddr, nAmount);
        }
    }

    function liquidate(uint256 posId) external payable onlyEOA nonReentrant {
        Position storage pos = positions[posId];
        require(pos.debtShare > 0, "no debt");
        Production storage production = productions[pos.productionId];

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
        repayLendbridge(production);
        emit Liquidate(posId, msg.sender, prize, left);
    }

    function claim(uint256 posId) external onlyEOA nonReentrant {
        Position storage pos = positions[posId];
        require(msg.sender == pos.owner, "not position owner");
        Production storage production = productions[pos.productionId];

        Goblin(production.goblin).claim(pos.owner, pos.owner);
    }

    function claimWithGoblins(address[] memory goblins) external onlyEOA nonReentrant {
        for(uint i = 0; i< goblins.length; i++) {
            Goblin(goblins[i]).claim(msg.sender, msg.sender);
        }
    }

    function claimAll() external onlyEOA nonReentrant {
        uint[] memory ps = userPositions[msg.sender];
        for(uint i = 0; i< ps.length; i++) {
            address goblin = productions[positions[ps[i]].productionId].goblin;
            Goblin(goblin).claim(msg.sender, msg.sender);
        }
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

    function updateConfig(IBankConfig _config) external onlyOwner {
        config = _config;
    }

    function updateLendbridge(ILendbridge _lendbridge) external onlyOwner {
        lendbridge = _lendbridge;
    }

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

    function calInterest(address token) public {
        TokenBank storage bank = banks[token];
        require(bank.isOpen, 'token not exists');

        if (now > bank.lastInterestTime) {
            uint256 timePast = now.sub(bank.lastInterestTime);
            uint256 totalDebt = bank.totalDebt;
            uint256 totalBalance = totalToken(token);

            uint256 ratePerSec = config.getInterestRate(totalDebt, totalBalance);
            uint256 interest = ratePerSec.mul(timePast).mul(totalDebt).div(1e18);

            uint256 toReserve = interest.mul(config.getReserveBps()).div(10000);
            bank.totalReserve = bank.totalReserve.add(toReserve);
            bank.totalDebt = bank.totalDebt.add(interest);
            bank.lastInterestTime = now;
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

        opTransfer(token, to, value);
    }

    function opTransfer(address token, address to, uint value) internal {
        if (token == address(0)) {
            SafeToken.safeTransferETH(to, value);
        } else {
            SafeToken.safeTransfer(token, to, value);
        }
    }

fallback() external {}
receive() payable external {}
}