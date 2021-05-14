// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Bank.sol";
import "./interface/IBankConfig.sol";
import "./interface/Goblin.sol";
import "./interface/IMdexPair.sol";
import "./PriceOracle.sol";
// import "hardhat/console.sol";


interface ChefLensInterface {

    function mdxRewardPerBlock(uint256 _pid) external view returns (uint256);

    function hptPerBlock() external view returns (uint256);

    function blocksPerYear() external view returns (uint256);

    function hptRewardTotal() external view returns (uint256);

    function mdxRewardTotal() external view returns (uint256);

    function mdx() external view returns (address);

    function hpt() external view returns (address);

    function poolInfo(uint256 _pid) external view returns (address, uint256, uint256, uint256, uint256, uint256);

    function pendingHpt(uint256 _pid, address _user) external view returns (uint256);

    function pendingMdx(uint256 _pid, address _user) external view returns (uint256);

}

interface GoblinLensInterface {

    function token0() external view returns (address);

    function token1() external view returns (address);

    function lpToken() external view returns (address);

    function staking() external view returns (address);

    function stakingPid() external view returns (uint256);

    function posLPAmount(uint256 _posId) external view returns (uint256);
}


contract Lens {

    using SafeMath for uint256;

    Bank bankContract;
    PriceOracle  priceOracle;
    uint public constant blocksPerYear = 10512000;

    struct BankTokenMetadata {
        address tokenAddr;
        address nTokenAddr;
        bool isOpen;
        bool canDeposit;
        bool canWithdraw;
        uint256 totalVal;
        uint256 totalDebt;
        uint256 totalDebtShare;

        string symbol;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 usage;
        uint256 priceInUsd;
    }

    struct ProductionMetadata {
        address lpToken;
        string lpSymbol;
        address token0;
        address token1;
        address borrowToken;
        bool isOpen;
        bool canBorrow;
        uint256 group;

        uint256 minDebt;   //最小借款额
        uint256 openFactor;   //最高开仓倍数
        uint256 liquidateFactor;  //清算限额

        uint256 baseYield; //基础收益率,单利
        uint256 hptYield;  //HPT补贴收益,单利
        uint256 poolValueLocked;  //挖矿池锁仓额
        uint256 totalAccuRewards; //挖矿累计收益
    }

    struct PositionInfo {
        uint256 posId;
        uint256 prodId;
        uint256 debtValue;
        uint256 healthAmount;
        uint256 lpAmount;
        uint256 lpValue;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 risk;
        uint256 mdxReward;
        uint256 hptReward;
    }

    struct DepositInfo {
        address tokenAddr;
        address nTokenAddr;
        string symbol;
        uint256 amount;
        uint256 value;
        uint256 reward;
    }

    constructor(Bank bank, PriceOracle oracle) public {
        bankContract = bank;
        priceOracle = oracle;
    }

    function infoAll() public view returns (BankTokenMetadata[] memory, ProductionMetadata[] memory){
        //console.log(address(bankContract));
        address[] memory tokensAddr = bankContract.getBankTokens();
        uint tokenCount = tokensAddr.length;
        //console.log(tokenCount);
        BankTokenMetadata[] memory banks = new BankTokenMetadata[](tokenCount);
        for (uint i = 0; i < tokenCount; i++) {
            banks[i] = bankTokenMetadata(tokensAddr[i]);
        }
        //console.log("currentPid: %s",bankContract.currentPid());
        ProductionMetadata[] memory prods = new ProductionMetadata[](bankContract.currentPid() - 1);
        for (uint i = 1; i < bankContract.currentPid(); i++) {
            prods[i - 1] = prodsMetadata(i);
        }

        return (banks, prods);
    }

    function userAll(address userAddr) public view returns (PositionInfo[] memory, DepositInfo[] memory){

        uint[] memory positions = bankContract.getUserPositions(userAddr);
        uint positionsCount = positions.length;

        PositionInfo[] memory positionInfos = new PositionInfo[](positionsCount);
        for (uint i = 0; i < positionsCount; i++) {
            positionInfos[i] = userPostions(positions[i]);
        }

        address[] memory tokensAddr = bankContract.getBankTokens();
        uint tokenCount = tokensAddr.length;
        DepositInfo[] memory depositInfos = new DepositInfo[](tokenCount);
        for (uint i = 0; i < tokenCount; i++) {
            depositInfos[i] = userDeposits(userAddr, tokensAddr[i]);
        }

        return (positionInfos, depositInfos);

    }


    function userPostions(uint posId) internal view returns (PositionInfo memory){


        (uint256 prodId, uint256 healthAmount, uint256 debtValue,address owner) = bankContract.positionInfo(posId);

        (,,,address goblin,,,,) = bankContract.productions(prodId);
        uint256 lpAmount = GoblinLensInterface(goblin).posLPAmount(posId);

        (uint256 lpValue,uint256 token0Amount,uint256 token1Amount) = getUserLpInfo(goblin, lpAmount);

        (uint256 mdxReward,uint256 hptReward) = getUserRewardInfo(goblin, owner);

        uint256 risk = calculateRisk(debtValue, lpValue);

        return PositionInfo({
            posId : posId,
            prodId : prodId,
            debtValue : debtValue,
            healthAmount : healthAmount,
            lpAmount : lpAmount,
            lpValue : lpValue,
            token0Amount : token0Amount,
            token1Amount : token1Amount,
            risk : risk,
            mdxReward : mdxReward,
            hptReward : hptReward
            });
    }

    function userDeposits(address userAddr, address bankToken) public view returns (DepositInfo memory){

        (
        address tokenAddr,
        address nTokenAddr,
        ,
        ,
        ,
        ,
        ,
        ,
        ,
        ) = bankContract.banks(bankToken);

        uint256 nTokenSupply;
        uint256 tokenAmount;
        uint256 value;

        uint256 nAmount = ERC20(nTokenAddr).balanceOf(userAddr);

        if (nAmount > 0) {
            nTokenSupply = ERC20(nTokenAddr).totalSupply();
            tokenAmount = nAmount.mul(bankContract.totalToken(tokenAddr)).div(nTokenSupply);
            value = tokenAmount.mul(getPriceInUsd(tokenAddr));
        }

        return DepositInfo({
            tokenAddr : tokenAddr,
            nTokenAddr : nTokenAddr,
            symbol : ERC20(bankToken).symbol(),
            amount : nAmount,
            value : value,
            reward : uint(0)
            });
    }

    function bankTokenMetadata(address bankToken) public view returns (BankTokenMetadata memory) {

        (
        address tokenAddr,
        address nTokenAddr,
        bool isOpen,
        bool canDeposit,
        bool canWithdraw,
        uint256 totalVal,
        uint256 totalDebt,
        uint256 totalDebtShare
        ,,
        ) = bankContract.banks(bankToken);

        string memory symbol = ERC20(bankToken).symbol();
        //console.log(symbol);
        uint256 interestRate = bankContract.config().getInterestRate(totalDebt, totalVal);
        //console.log(interestRate);
        uint256 priceInUsd = getPriceInUsd(bankToken);
        //console.log(priceInUsd);

        uint usage = 0;
        if (totalVal > 0) {
            usage = totalDebt.div(totalVal);
        }

        return BankTokenMetadata({

            tokenAddr : tokenAddr,
            nTokenAddr : nTokenAddr,
            isOpen : isOpen,
            canDeposit : canDeposit,
            canWithdraw : canWithdraw,
            totalVal : totalVal,
            totalDebt : totalDebt,
            totalDebtShare : totalDebtShare,
            symbol : symbol,
            supplyRate : interestRate,
            borrowRate : interestRate,
            usage : usage,
            priceInUsd : priceInUsd
            });

    }

    function prodsMetadata(uint pid) public view returns (ProductionMetadata memory) {

        (
        address borrowToken,
        bool isOpen,
        bool canBorrow,
        address goblin,
        uint256 minDebt,
        uint256 openFactor,
        uint256 liquidateFactor,
        uint256 group
        ) = bankContract.productions(pid);

        (
        address lpToken,
        uint256 poolValueLocked,

        uint256 baseYield,
        uint256 hptYield
        ) = getPoolRewardInfo(goblin);

        uint256 accuRewards = getTotalAccuRewards(goblin);

        return ProductionMetadata({
            lpToken : lpToken,
            lpSymbol : ERC20(lpToken).symbol(),
            token0 : GoblinLensInterface(goblin).token0(),
            token1 : GoblinLensInterface(goblin).token1(),
            borrowToken : borrowToken,
            isOpen : isOpen,
            canBorrow : canBorrow,
            group : group,
            minDebt : minDebt,
            openFactor : openFactor,
            liquidateFactor : liquidateFactor,
            baseYield : baseYield,
            hptYield : hptYield,
            poolValueLocked : poolValueLocked,
            totalAccuRewards : accuRewards
            });
    }


    function getPoolRewardInfo(address goblin) internal view returns (address, uint, uint, uint){
        address chef = GoblinLensInterface(goblin).staking();

        ChefLensInterface chefLens = ChefLensInterface(chef);
        uint256 hptPerBlock = chefLens.hptPerBlock();
        uint256 mdxPerBlock = chefLens.mdxRewardPerBlock(GoblinLensInterface(goblin).stakingPid());
        (address lpToken,,,,,uint256 poolLpBalance) = chefLens.poolInfo(GoblinLensInterface(goblin).stakingPid());

        uint256 mdxInUsd = getPriceInUsd(chefLens.mdx());
        uint256 hptInUsd = getPriceInUsd(chefLens.hpt());
        (uint256 poolValueLocked,,) = getLpValue(lpToken, poolLpBalance);

        uint256 baseYield = 0;
        uint256 hptYield = 0;
        if (poolValueLocked > 0) {
            baseYield = mdxPerBlock * blocksPerYear * mdxInUsd / poolValueLocked;
            hptYield = hptPerBlock * blocksPerYear * hptInUsd / poolValueLocked;
        }

        return (lpToken, poolValueLocked, baseYield, hptYield);
    }

    function getUserRewardInfo(address goblin, address owner) public view returns (uint, uint){

        ChefLensInterface chefLens = ChefLensInterface(address(GoblinLensInterface(goblin).staking()));
        uint256 mdxReward = chefLens.pendingMdx(GoblinLensInterface(goblin).stakingPid(), owner);
        uint256 hptReward = chefLens.pendingHpt(GoblinLensInterface(goblin).stakingPid(), owner);

        return (mdxReward, hptReward);
    }

    function getUserLpInfo(address goblin, uint lpAmount) public view returns (uint, uint, uint){

        (uint256 lpValue,uint256 token0Amount,uint256 token1Amount) = getLpValue(GoblinLensInterface(goblin).lpToken(), lpAmount);

        return (lpValue, token0Amount, token1Amount);
    }

    function getTotalAccuRewards(address goblin) internal view returns (uint256){

        address chef = GoblinLensInterface(goblin).staking();

        ChefLensInterface chefLens = ChefLensInterface(chef);

        address hpt = chefLens.hpt();
        address mdx = chefLens.mdx();

        uint256 hptRewardTotal = chefLens.hptRewardTotal();
        uint256 mdxRewardTotal = chefLens.mdxRewardTotal();

        uint256 totalAccuRewards = hptRewardTotal.mul(getPriceInUsd(hpt));
        totalAccuRewards = totalAccuRewards.add(mdxRewardTotal.mul(getPriceInUsd(mdx)));

        return totalAccuRewards;

    }

    function getLpValue(address lpToken, uint256 lpBalance) internal view returns (uint256, uint256, uint256){

        IMdexPair pair = IMdexPair(lpToken);
        // 1. Get the position's LP balance and LP total supply.
        uint256 lpSupply = pair.totalSupply();
        // Ignore pending mintFee as it is insignificant
        // 2. Get the pool's total supply of token0 and token1.
        (uint256 totalAmount0, uint256 totalAmount1,) = pair.getReserves();

        // 3. Convert the position's LP tokens to the underlying assets.
        uint256 userToken0 = lpBalance.mul(totalAmount0).div(lpSupply);
        uint256 priceToken0 = getPriceInUsd(pair.token0());
        uint256 userToken1 = lpBalance.mul(totalAmount1).div(lpSupply);
        uint256 priceToken1 = getPriceInUsd(pair.token1());

        uint256 lpValue = userToken0.mul(priceToken0).add(userToken1.mul(priceToken1));
        return (lpValue, userToken0, userToken1);
    }

    function calculateRisk(uint256 debtValue, uint256 lpValue) public view returns (uint256){

        //借贷率 = 借款/总资产
        //风险值 = 借贷率/0.85
        uint256 liqBps = bankContract.config().getLiquidateBps();
        uint256 loanRate = debtValue.div(lpValue);
        uint256 risk = loanRate.div(liqBps);
        return risk;
    }

    function getPriceInUsd(address token) public view returns (uint){
        (int price,) = priceOracle.getPrice(token);
        if (price > 0) {
            return uint(price);
        } else {
            return uint(0);
        }

    }

    function getAllUserPos() public view returns (PositionInfo[] memory){

        uint positionsCount = bankContract.currentPid() - 1;

        PositionInfo[] memory positionInfos = new PositionInfo[](positionsCount);
        for (uint i = 0; i < positionsCount; i++) {
            positionInfos[i] = userPostions(i + 1);
        }

        return positionInfos;

    }


    function getAllUserPosIds() public view returns (uint[] memory){
        uint positionsCount = bankContract.currentPid() - 1;

        uint[] memory positionInfos = new uint[](positionsCount);
        for (uint i = 0; i < positionsCount; i++) {
            PositionInfo info = userPostions(i + 1);
            (,,,,,,uint256 liquidateFactor,) = bankContract.productions(info.prodId);

            if (info.healthAmount.mul(liquidateFactor) < info.debtValue.mul(10000)) {
                positionInfos[i] = info.prodId;
            } else {
                positionInfos[i] = 0;
            }
        }
        return positionInfos;

    }
}

