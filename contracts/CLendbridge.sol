// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./interface/IBank.sol";
import "./interface/ICToken.sol";
import "./library/SafeToken.sol";
import "./interface/ILendbridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./library/StrUtil.sol";

contract CLendbridge is ILendbridge, Ownable {
    using SafeToken for address;
    using SafeMath for uint256;

    IBank public bank;
    address public rewardToken;
    address public claimContract;
    address public HPT;

    mapping(address => address) cTokens;
    mapping(address => address) erc20s;

    modifier onlyBank() {
        require(msg.sender == address(bank), 'only bank');
        _;
    }

    constructor(IBank _bank, address _rewardToken, address _claimContract, address _hpt) public {
        bank = _bank;
        rewardToken = _rewardToken;
        claimContract = _claimContract;
        HPT = _hpt;
    }

    function setCToken(address erc20, address _cToken) public onlyOwner {
        cTokens[erc20] = _cToken;
        erc20s[_cToken] = erc20;
    }

    function loanAndDeposit(address erc20, uint amt) public override onlyBank {
        ICToken cToken = ICToken(cTokens[erc20]);
        require(address(cToken) != address(0), 'cToken not support');

        uint error = cToken.borrow(amt);
        require(error == 0, string(abi.encodePacked('newland.borrow failed ', StrUtil.uint2str(error))));

        uint erc20Amt = erc20.myBalance();
        require(erc20Amt >= amt, 'newland.borrow failed');
        if (erc20Amt > amt) {
            erc20.safeTransfer(owner(), erc20Amt - amt);
        }

        erc20.safeApprove(address(bank), amt);
        bank.deposit(erc20, amt);
    }

    function withdrawAndRepay(address erc20, address nErc20, uint nAmt) public override onlyBank {
        uint erc20Amt = erc20.myBalance();
        if (erc20Amt > 0) {
            erc20.safeTransfer(owner(), erc20Amt);
        }

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
            erc20.safeApprove(address(cToken), repayAmt);
            uint error = cToken.repayBorrow(repayAmt);
            require(error == 0, string(abi.encodePacked('newland.repayBorrow failed ', StrUtil.uint2str(error))));
        }
    }

    function mintCollateral(address erc20, uint mintAmount) external onlyOwner {
        ICToken cToken = ICToken(cTokens[erc20]);
        require(address(cToken) != address(0), 'cToken not support');

        uint eBalance = erc20.myBalance();
        if (mintAmount > eBalance) {
            mintAmount = eBalance;
        }

        erc20.safeApprove(address(cToken), mintAmount);
        uint error = cToken.mint(mintAmount);
        require(error == 0, string(abi.encodePacked('newland.mint failed ', StrUtil.uint2str(error))));
    }

    function redeemCollateral(address cToken, uint cAmt) external onlyOwner {
        uint cBalance = cToken.myBalance();
        if (cAmt > cBalance) {
            cAmt = cBalance;
        }
        uint error = ICToken(cToken).redeem(cAmt);
        require(error == 0, string(abi.encodePacked('newland.redeem failed ', StrUtil.uint2str(error))));

        erc20s[cToken].safeTransfer(owner(), erc20s[cToken].myBalance());
    }

    function getInterestRate(address erc20) public view override returns(uint) {
        ICToken cToken = ICToken(cTokens[erc20]);
        if (address(cToken) == address(0)) {
            return 0;
        }
        // todo
        return cToken.borrowRatePerBlock().div(3);
    }

    function claimable() public view override returns(bool) {
        return rewardToken != address(0) && claimContract != address(0);
    }

    // claim dep
    function claim() public override onlyBank returns(address, uint) {
        bytes4 methodId = bytes4(keccak256("claim(address)"));
        (bool success,) = claimContract.call(abi.encodeWithSelector(methodId, address(this)));
        require(success, 'claim CLendbridge failed');
        uint rewardAmt = rewardToken.myBalance();
        rewardToken.safeTransfer(address(bank), rewardAmt);
        return (rewardToken, rewardAmt);
    }

    function withdrawHpt() public onlyOwner {
        HPT.safeTransfer(owner(), HPT.myBalance());
    }
}