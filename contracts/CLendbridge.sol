// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./interface/IBank.sol";
import "./interface/ICToken.sol";
import "./library/SafeToken.sol";
import "./interface/ILendbridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./library/StrUtil.sol";
import "./Treasury.sol";

interface LendRewardLens {
    function pending(address _holder, address _market, address _token) external view returns (uint256 amount);
}

interface ClaimContract {
    function claimAll(address holder, address[] memory markets) external;
    function enterMarkets(address[] memory cTokens) external returns (uint[] memory);
    function checkMembership(address account, address cToken) external view returns (bool);
}

contract CLendbridge is ILendbridge, Ownable {
    using SafeToken for address;
    using SafeMath for uint256;

    IBank public bank;
    address public rewardToken;
    address public claimContract;
    address public HPT;

    mapping(address => address) public  cTokens;
    mapping(address => address) public erc20s;
    address[] public claimCTokens;

    LendRewardLens public lendRewardLens;
    Treasury public treasury;

    modifier onlyBank() {
        require(msg.sender == address(bank), 'only bank');
        _;
    }

    constructor(IBank _bank, address _rewardToken,
        address _claimContract, address _hpt,
        LendRewardLens _lendRewardLens) public {
        bank = _bank;
        rewardToken = _rewardToken;
        claimContract = _claimContract;
        HPT = _hpt;

        lendRewardLens = _lendRewardLens;
        treasury= new Treasury();
    }

    function setClaimCTokens(address[] memory _claimCTokens) public onlyOwner {
        claimCTokens = _claimCTokens;
    }

    function getClaimCTokens() public view returns(address[] memory) {
        return claimCTokens;
    }

    function setCToken(address erc20, address _cToken) public onlyOwner {
        require(erc20 != address(0) && _cToken != address(0), 'invalid address');
        require(ICToken(_cToken).underlying() == erc20 && erc20s[erc20] == address(0) && cTokens[_cToken] == address(0), 'invalid cToken');

        cTokens[erc20] = _cToken;
        erc20s[_cToken] = erc20;

        erc20.safeApprove(address(treasury), 0);
        erc20.safeApprove(address(treasury), uint256(-1));
    }

    function loanAndDeposit(address erc20, uint amt) public override onlyBank {
        ICToken cToken = ICToken(cTokens[erc20]);
        require(address(cToken) != address(0), 'cToken not support');

        uint error = cToken.borrow(amt);
        require(error == 0, string(abi.encodePacked('newland.borrow failed ', StrUtil.uint2str(error))));

        uint erc20Amt = erc20.myBalance();
        require(erc20Amt >= amt, 'newland.borrow failed');
        erc20.safeApprove(address(bank), 0);
        erc20.safeApprove(address(bank), amt);
        bank.deposit(erc20, amt);

        erc20Amt = erc20.myBalance();
        if (erc20Amt > 0) {
            treasury.deposit(address(this), erc20, erc20Amt);
        }
    }

    function withdrawAndRepay(address erc20, address nErc20, uint nAmt) public override onlyBank {
        ICToken cToken = ICToken(cTokens[erc20]);
        if (address(cToken) != address(0)) {
            uint nErc20Amt = nErc20.myBalance();
            if (nAmt > nErc20Amt) {
                nAmt = nErc20Amt;
            }
            if (nAmt == 0) {
                return;
            }

            bank.withdraw(erc20, nAmt);
            uint repayAmt = erc20.myBalance();
            uint debt = cToken.borrowBalanceStored(address(this));
            if (repayAmt > debt) {
                repayAmt = debt;
            }

            erc20.safeApprove(address(cToken), 0);
            erc20.safeApprove(address(cToken), repayAmt);
            uint error = cToken.repayBorrow(repayAmt);
            require(error == 0, string(abi.encodePacked('newland.repayBorrow failed ', StrUtil.uint2str(error))));
        }

        uint erc20Amt = erc20.myBalance();
        if (erc20Amt > 0) {
            treasury.deposit(address(this), erc20, erc20Amt);
        }
    }

    function manualRepay(address erc20) public onlyOwner {
        uint amount = treasury.userTokenAmt(address(this), erc20);
        treasury.withdraw(address(this), erc20, amount, address(this));

        ICToken cToken = ICToken(cTokens[erc20]);
        require(address(cToken) != address(0), 'cToken not support');

        uint repayAmt = erc20.myBalance();
        uint debt = cToken.borrowBalanceStored(address(this));
        if (repayAmt > debt) {
            repayAmt = debt;
        }

        if (repayAmt > 0) {
            erc20.safeApprove(address(cToken), 0);
            erc20.safeApprove(address(cToken), repayAmt);
            uint error = cToken.repayBorrow(repayAmt);
            require(error == 0, string(abi.encodePacked('manual newland.repayBorrow failed ', StrUtil.uint2str(error))));
        }

        uint erc20Amt = erc20.myBalance();
        if (erc20Amt > 0) {
            erc20.safeTransfer(owner(), erc20Amt);
        }
    }

    function mintCollateral(address erc20, uint mintAmount) external onlyOwner {
        ICToken cToken = ICToken(cTokens[erc20]);
        require(address(cToken) != address(0), 'cToken not support');

        uint eBalance = erc20.myBalance();
        if (mintAmount > eBalance) {
            mintAmount = eBalance;
        }

        erc20.safeApprove(address(cToken), 0);
        erc20.safeApprove(address(cToken), mintAmount);
        uint error = cToken.mint(mintAmount);
        require(error == 0, string(abi.encodePacked('newland.mint failed ', StrUtil.uint2str(error))));


        if (!ClaimContract(claimContract).checkMembership(address(this), address(cToken))) {
            address[] memory enterTokens = new address[](1);
            enterTokens[0] = address(cToken);
            ClaimContract(claimContract).enterMarkets(enterTokens);
        }
    }

    function redeemCollateral(address cToken, uint cAmt) external onlyOwner {
        address erc20 = erc20s[cToken];
        require(erc20 != address(0), 'cToken not support');

        uint cBalance = cToken.myBalance();
        if (cAmt > cBalance) {
            cAmt = cBalance;
        }
        if (cAmt > 0) {
            uint error = ICToken(cToken).redeem(cAmt);
            require(error == 0, string(abi.encodePacked('newland.redeem failed ', StrUtil.uint2str(error))));
        }

        erc20s[cToken].safeTransfer(owner(), erc20s[cToken].myBalance());
    }

    function getInterestRate(address erc20) public view override returns(uint) {
        ICToken cToken = ICToken(cTokens[erc20]);
        if (address(cToken) == address(0)) {
            return 0;
        }
        return cToken.borrowRatePerBlock().div(3);
    }

    function claimable() public view override returns(bool) {
        return rewardToken != address(0) && claimContract != address(0);
    }

    // claim dep
    function claim() public override onlyBank returns(address, uint) {
        ClaimContract(claimContract).claimAll(address(this), claimCTokens);
        uint rewardAmt = rewardToken.myBalance();
        rewardToken.safeTransfer(address(bank), rewardAmt);
        return (rewardToken, rewardAmt);
    }

    function withdrawHpt() public onlyOwner {
        HPT.safeTransfer(owner(), HPT.myBalance());
    }

    function debtRewardPending(address debtToken, address _rewardToken) public override view returns(uint) {
        if (address(lendRewardLens) == address(0)) {
            return 0;
        }
        return lendRewardLens.pending(address(this), cTokens[debtToken], _rewardToken);
    }
}