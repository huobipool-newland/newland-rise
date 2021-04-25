// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Bank.sol";
import "./interface/IBankConfig.sol";
import "./interface/Goblin.sol";
import "./NTokenFactory.sol";

interface ChefLensInterface{

    function mdxRewardPerBlock(uint256 _pid) public view returns(uint256);
    function hptPerBlock() public view returns(uint256);
    function blocksPerYear() public view returns(uint256);
    function poolInfo(uint256 _pid) public view returns(address,uint256,uint256,uint256,uint256, uint256);
}


contract Lens {

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
        //uint256 priceInUsd;

    }

    struct ProductionMetadata {
        address coinToken;
        address currencyToken;
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
        address owner;
        uint256 productionId;
        uint256 debtShare;
    }


    function InfoAll(Bank bankContract) public view returns(BankTokenMetadata[] memory, ProductionMetadata[] memory){

        address[] memory tokensAddr = bankContract.getBankTokens();
        uint tokenCount = tokensAddr.length;
        
        BankTokenMetadata[] memory banks = new BankTokenMetadata[](tokenCount);
        for(uint i = 0; i < tokenCount; i++){
            banks[i] = bankTokenMetadata(bankContract,tokensAddr[i]);
        }

        ProductionMetadata[] memory prods = new ProductionMetadata[](bankContract.currentPid());
        for(uint i = 0; i <bankContract.currentPid(); i++){
            prods[i] = prodMetadata(bankContract,i+1);
        }

        return (banks,prods);
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
            usage: usage

        });

    }

    function prodsMetadata(Bank bankContract,uint pid) public view returns (ProductionMetadata memory) {

        (
            address coinToken,
            address currencyToken,
            address borrowToken,
            bool isOpen,
            bool canBorrow,
            address goblin,
            uint256 minDebt,
            uint256 openFactor,
            uint256 liquidateFactor
        ) = bankContract.productions(pid);

        IStakingRewards chef = Goblin(goblin).staking();
        uint256 stakingPid = Goblin(goblin).stakingPid();

        ChefLensInterface chefLens = ChefLensInterface(address(chef));
        uint256 hptPerBlock = chefLens.hptPerBlock();
        uint256 mdxPerBlock = chefLens.mdxRewardPerBlock(stakingPid);
        uint256 blocksPerYear = chefLens.blocksPerYear();
        (address lpToken,,,,,,uint256 poolLpBalance) = chefLens.poolInfo(stakingPid); //?

        uint256 mdxInUsd = 30000000; //3U
        uint256 hptInUsd = 1500000; //0.15U
        uint256 poolValueLocked = getLpValue(lpToken,poolLpBalance);
        uint256 baseYield = mdxPerBlock * blocksPerYear * mdxInUsd / poolValueLocked;
        uint256 hptYield = hptPerBlock * blocksPerYear * hptInUsd / poolValueLocked;


        return ProductionMetadata({
            coinToken: coinToken,
            currencyToken: currencyToken,
            borrowToken: borrowToken,
            isOpen: isOpen,
            canBorrow: canBorrow,
            goblin: goblin,
            minDebt: minDebt,
            openFactor: openFactor,
            liquidateFactor: liquidateFactor,
            baseYield: baseYield,
            hptYield: hptYield,
            poolValueLocked: poolValueLocked
        });
    }

    function getLpValue(address lpToken,uint256 lpBalance) internal returns(uint256){
        return uint(100);
    }

}

