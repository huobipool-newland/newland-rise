// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Bank.sol";
import "./interface/IBankConfig.sol";
import "./interface/Goblin.sol";
import "./interface/IMdexPair.sol";
import "./interface/IStakingRewards.sol";


interface ChefLensInterface{

    function mdxRewardPerBlock(uint256 _pid) external view returns(uint256);
    function hptPerBlock() external view returns(uint256);
    function blocksPerYear() external view returns(uint256);
    function mdx() external view returns(address);
    function hpt() external view returns(address);

    function poolInfo(uint256 _pid) external view returns(address,uint256,uint256,uint256,uint256, uint256);
    function pendingHpt(uint256 _pid, address _user) external view returns (uint256);
    function pendingMdx(uint256 _pid, address _user) external view returns (uint256);

}

interface GoblinLensInterface{

    function token0() external view returns(address);
    function token1() external view returns(address);
    function lpToken() external view returns(address);
    function staking() external view returns(address);
    function stakingPid() external view returns(uint256);
    function posLPAmount(uint256 _posId) external view returns(uint256);
}


contract Lens {

    using SafeMath for uint256;

    struct BankTokenMetadata {
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

        string symbol;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 usage;
        uint256 priceInUsd;

    }

    struct ProductionMetadata {
        address lpToken;
        address token0;
        address token1;
        address borrowToken;
        bool isOpen;
        bool canBorrow;

        uint256 minDebt;   //最小借款额
        uint256 openFactor;   //最高开仓倍数
        uint256 liquidateFactor;  //清算限额

        uint256 baseYield; //基础收益率,单利
        uint256 hptYield;  //HPT补贴收益,单利
        uint256 poolValueLocked;  //挖矿池锁仓额
    }

    struct PositionInfo {
        uint256 posId;
        uint256 prodId;
        address owner;
        address borrowToken;
        uint256 debtValue;
        uint256 healthAmount;
        uint256 lpAmount;
        uint256 lpValue;
        uint256 risk;
        uint256 mdxReward;
        uint256 hptReward;
    }


    function infoAll(Bank bankContract) public view returns(BankTokenMetadata[] memory, ProductionMetadata[] memory){

        address[] memory tokensAddr = bankContract.getBankTokens();
        uint tokenCount = tokensAddr.length;
        
        BankTokenMetadata[] memory banks = new BankTokenMetadata[](tokenCount);
        for(uint i = 0; i < tokenCount; i++){
            banks[i] = bankTokenMetadata(bankContract,tokensAddr[i]);
        }

        ProductionMetadata[] memory prods = new ProductionMetadata[](bankContract.currentPid());
        for(uint i = 0; i <bankContract.currentPid(); i++){
            prods[i] = prodsMetadata(bankContract,i+1);
        }

        return (banks,prods);
    }

    function userPostion(address userAddr, Bank bankContract) public view returns(PositionInfo[] memory){

        IBankConfig config = bankContract.config();
        uint256 liqBps = config.getLiquidateBps();

        uint[] memory positions = bankContract.getUserPositions(userAddr);
        uint positionsCount = positions.length;

        PositionInfo[] memory info = new PositionInfo[](positionsCount);
        for(uint i = 0; i < positionsCount; i++){
            
            (uint256 prodId, uint256 healthAmount, uint256 debtValue,address owner) = bankContract.positionInfo(positions[i]);
            (address borrowToken,,,address goblin,,,) = bankContract.productions(prodId);

            GoblinLensInterface goblinLens = GoblinLensInterface(goblin);
            uint256 lpAmount = goblinLens.posLPAmount(positions[i]);
            uint256 lpValue = getLpValue(goblinLens.lpToken(),lpAmount);

            address chef = goblinLens.staking();
            uint256 stakingPid = goblinLens.stakingPid();

            ChefLensInterface chefLens = ChefLensInterface(address(chef));
            uint256 mdxReward = chefLens.pendingMdx(stakingPid,userAddr);
            uint256 hptReward = chefLens.pendingHpt(stakingPid,userAddr);

            info[i] = PositionInfo({
                posId: positions[i],
                prodId: prodId,
                owner: owner,
                borrowToken: borrowToken,
                debtValue:debtValue,
                healthAmount: healthAmount,
                lpAmount: lpAmount,
                lpValue: lpValue,
                risk: calculateRisk(liqBps,debtValue,lpValue),
                mdxReward: mdxReward,
                hptReward: hptReward
            });
        }

        return info;

    }

    function bankTokenMetadata(Bank bankContract, address bankToken) public view returns (BankTokenMetadata memory) {

        (
            address tokenAddr,
            address nTokenAddr,
            bool isOpen,
            bool canDeposit,
            bool canWithdraw,
            uint256 totalVal,
            uint256 totalDebt,
            uint256 totalDebtShare,
            uint256 totalReserve,
            uint256 lastInterestTime   
        ) = bankContract.banks(bankToken);

        string memory symbol = ERC20(bankToken).symbol();
        IBankConfig config = bankContract.config();
        uint256 interestRate = config.getInterestRate(totalDebt,totalVal);
        uint256 usage = totalDebt / totalVal ;
        uint256 priceInUsd = getPriceInUsd(bankToken);

        return BankTokenMetadata({

            tokenAddr: tokenAddr,
            nTokenAddr: nTokenAddr,
            isOpen: isOpen,
            canDeposit: canDeposit,
            canWithdraw: canWithdraw,
            totalVal: totalVal,
            totalDebt: totalDebt,
            totalDebtShare: totalDebtShare,
            totalReserve: totalReserve,
            lastInterestTime: lastInterestTime,
            symbol: symbol,
            supplyRate: interestRate,
            borrowRate: interestRate,
            usage: usage,
            priceInUsd: priceInUsd
        });

    }

    function prodsMetadata(Bank bankContract,uint pid) public view returns (ProductionMetadata memory) {

        (
            address borrowTokenAddr,
            bool isOpen,
            bool canBorrow,
            address goblin,
            uint256 minDebt,
            uint256 openFactor,
            uint256 liquidateFactor
        ) = bankContract.productions(pid);

        GoblinLensInterface goblinLens = GoblinLensInterface(goblin);
        address chef = goblinLens.staking();
        uint256 stakingPid = goblinLens.stakingPid();

        ChefLensInterface chefLens = ChefLensInterface(address(chef));
        uint256 hptPerBlock = chefLens.hptPerBlock();
        uint256 mdxPerBlock = chefLens.mdxRewardPerBlock(stakingPid);
        uint256 blocksPerYear = chefLens.blocksPerYear();
        (address lpToken,,,,,uint256 poolLpBalance) = chefLens.poolInfo(stakingPid); //?

        uint256 mdxInUsd = getPriceInUsd(chefLens.mdx());
        uint256 hptInUsd = getPriceInUsd(chefLens.hpt());
        uint256 poolValueLocked = getLpValue(lpToken,poolLpBalance);
        // uint256 baseYield = ;
        // uint256 hptYield = ;


        return ProductionMetadata({
            lpToken: lpToken,
            token0: goblinLens.token0(),
            token1: goblinLens.token1(),
            borrowToken: borrowTokenAddr,
            isOpen: isOpen,
            canBorrow: canBorrow,
            minDebt: minDebt,
            openFactor: openFactor,
            liquidateFactor: liquidateFactor,
            baseYield: mdxPerBlock * blocksPerYear * mdxInUsd / poolValueLocked,
            hptYield: hptPerBlock * blocksPerYear * hptInUsd / poolValueLocked,
            poolValueLocked: poolValueLocked
        });
    }




    function getLpValue(address lpToken,uint256 lpBalance) internal view returns(uint256){

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

        return userToken0.mul(priceToken0).add(userToken1.mul(priceToken1));
    }

    function calculateRisk(uint256 liqBps,uint256 debtValue, uint256 lpValue) public pure returns(uint256){
        
        //借贷率 = 借款/总资产
        //风险值 = 借贷率/0.85

        uint256 loanRate = debtValue.div(lpValue);
        uint256 risk = loanRate.div(liqBps);
        return risk;
    }

    function getPriceInUsd(address token) public pure returns(uint256){
        return uint(100);
    }

}

