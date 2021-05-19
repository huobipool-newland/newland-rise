// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./interface/IBank.sol";
import "./interface/INewlandToken.sol";
import "./library/SafeToken.sol";
import "./interface/ILoanPlat.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NewlandLoanPlat is ILoanPlat, Ownable {
    using SafeToken for address;

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

        uint erc20Before = erc20.myBalance();
        newlandToken.borrow(amt);
        uint erc20Now = erc20.myBalance();

        require(erc20Now >= erc20Before, 'borrow from newland failed');

        uint erc20Amt = erc20Now - erc20Before;
        require(erc20Amt >= amt, 'borrow from newland failed');

        erc20.safeApprove(address(newlandToken), erc20Amt);
        bank.deposit(erc20, erc20Amt);
    }

    function withdrawAndRepay(address erc20, address nErc20, uint nAmt) public override onlyBank {
        INewlandToken newlandToken = newlandTokens[erc20];
        require(address(newlandToken) != address(0), 'newlandToken not support');

        uint nErc20Amt = nErc20.myBalance();
        if (nAmt > nErc20Amt) {
            nAmt = nErc20Amt;
        }

        uint erc20Before = erc20.myBalance();
        bank.withdraw(erc20, nAmt);
        uint erc20Now = erc20.myBalance();

        require(erc20Now >= erc20Before, 'withdraw from bank failed');

        uint erc20Amt = erc20Now - erc20Before;

        newlandToken.repayBorrow(erc20Amt);
    }
}