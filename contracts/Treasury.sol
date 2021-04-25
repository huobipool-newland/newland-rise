// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./library/SafeToken.sol";

contract Treasury is Ownable {
    using SafeToken for address;

    mapping(address => mapping(address => uint)) public userTokenAmt;
    mapping(address => uint) public tokenTotalAmt;

    function deposit(address user, address token, uint amt) public onlyOwner returns(uint) {
        token.safeTransferFrom(msg.sender, address(this), amt);
        userTokenAmt[user][token] += amt;
        tokenTotalAmt[token] += amt;
        return amt;
    }

    function withdraw(address user, address token, uint amt, address to) public onlyOwner returns(uint) {
        require(userTokenAmt[user][token] > amt, "uane");

        userTokenAmt[user][token] -= amt;
        tokenTotalAmt[token] -= amt;
        uint bal = token.myBalance();
        if (amt > bal) {
            amt = bal;
        }
        token.safeTransfer(to, amt);
        return amt;
    }
}