// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./interface/IBank.sol";
import "./interface/ICToken.sol";
import "./library/SafeToken.sol";
import "./interface/ILendbridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract CLendbridge is ILendbridge, Ownable {
    using SafeToken for address;
    using SafeMath for uint256;

    IBank public bank;
    address rewardToken;
    address claimContract;

    mapping(address => ICToken) cTokens;

    modifier onlyBank() {
        require(msg.sender == address(bank), 'only bank');
        _;
    }

    constructor(IBank _bank, address _rewardToken, address _claimContract) public {
        bank = _bank;
        rewardToken = _rewardToken;
        claimContract = _claimContract;
    }

    function setCToken(address erc20, ICToken _cToken) public onlyOwner {
        cTokens[erc20] = _cToken;
    }

    function loanAndDeposit(address erc20, uint amt) public override onlyBank {
        ICToken cToken = cTokens[erc20];
        require(address(cToken) != address(0), 'cToken not support');

        cToken.borrow(amt);

        uint erc20Amt = erc20.myBalance();
        require(erc20Amt >= amt, 'borrow from newland failed');
        if (erc20Amt > amt) {
            erc20.safeTransfer(owner(), erc20Amt - amt);
        }

        erc20.safeApprove(address(cToken), amt);
        bank.deposit(erc20, amt);
    }

    function withdrawAndRepay(address erc20, address nErc20, uint nAmt) public override onlyBank {
        uint erc20Amt = erc20.myBalance();
        if (erc20Amt > 0) {
            erc20.safeTransfer(owner(), erc20Amt);
        }

        ICToken cToken = cTokens[erc20];
        if (address(cToken) != address(0)) {
            uint nErc20Amt = nErc20.myBalance();
            if (nAmt > nErc20Amt) {
                nAmt = nErc20Amt;
            }
            if (nAmt == 0) {
                return;
            }

            bank.withdraw(erc20, nAmt);
            cToken.repayBorrow(erc20.myBalance());
        }
    }

    function mintCollateral(address erc20, uint mintAmount) external onlyOwner {
        ICToken cToken = cTokens[erc20];
        require(address(cToken) != address(0), 'cToken not support');

        erc20.safeApprove(address(cToken), mintAmount);
        cToken.mint(mintAmount);
    }

    function getInterestRate(address erc20) public view override returns(uint) {
        ICToken cToken = cTokens[erc20];
        if (address(cToken) == address(0)) {
            return 0;
        }
        // todo
        return cToken.borrowRatePerBlock().div(3);
    }

    function claimable() public view override returns(bool) {
        return rewardToken != address(0) && claimContract != address(0);
    }

    function claim() public override returns(address, uint) {
        bytes4 methodId = bytes4(keccak256("claim(address)"));
        uint before = rewardToken.myBalance();
        (bool success,) = claimContract.call(abi.encodeWithSelector(methodId, rewardToken));
        require(success, 'claim CLendbridge failed');
        return (rewardToken, rewardToken.myBalance().sub(before));
    }
}