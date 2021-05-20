// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./interface/IBank.sol";
import "./interface/INewlandToken.sol";
import "./library/SafeToken.sol";
import "./interface/ILendbridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract NewlandLendbridge is ILendbridge, Ownable {
    using SafeToken for address;
    using SafeMath for uint256;

    IBank public bank;

    mapping(address => INewlandToken) newlandTokens;

    modifier onlyBank() {
        require(msg.sender == address(bank), 'only bank');
        _;
    }

    function setNewlandToken(address erc20, INewlandToken _newlandToken) public onlyOwner {
        newlandTokens[erc20] = _newlandToken;
    }

    function setBank(IBank _bank) public onlyOwner {
        bank = _bank;
    }

    function loanAndDeposit(address erc20, uint amt) public override onlyBank {
        INewlandToken newlandToken = newlandTokens[erc20];
        require(address(newlandToken) != address(0), 'newlandToken not support');

        newlandToken.borrow(amt);

        uint erc20Amt = erc20.myBalance();
        require(erc20Amt >= amt, 'borrow from newland failed');
        if (erc20Amt > amt) {
            erc20.safeTransfer(owner(), erc20Amt - amt);
        }

        erc20.safeApprove(address(newlandToken), amt);
        bank.deposit(erc20, amt);
    }

    function withdrawAndRepay(address erc20, address nErc20, uint nAmt) public override onlyBank {
        uint erc20Amt = erc20.myBalance();
        if (erc20Amt > 0) {
            erc20.safeTransfer(owner(), erc20Amt);
        }

        INewlandToken newlandToken = newlandTokens[erc20];
        require(address(newlandToken) != address(0), 'newlandToken not support');

        uint nErc20Amt = nErc20.myBalance();
        if (nAmt > nErc20Amt) {
            nAmt = nErc20Amt;
        }
        if (nAmt == 0) {
            return;
        }

        bank.withdraw(erc20, nAmt);
        newlandToken.repayBorrow(erc20.myBalance());
    }

    function mintCollateral(address erc20, uint mintAmount) external onlyOwner {
        INewlandToken newlandToken = newlandTokens[erc20];
        require(address(newlandToken) != address(0), 'newlandToken not support');

        erc20.safeApprove(address(newlandToken), mintAmount);
        newlandToken.mint(mintAmount);
    }

    function getInterestRate(address erc20) public view override returns(uint) {
        INewlandToken newlandToken = newlandTokens[erc20];
        require(address(newlandToken) != address(0), 'newlandToken not support');
        // todo
        return newlandToken.borrowRatePerBlock().div(3);
    }
}