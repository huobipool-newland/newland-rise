// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./library/SafeToken.sol";

contract Treasury is Ownable {
    using SafeToken for address;

    mapping(address => mapping(address => uint)) userTokenAmt;
    mapping(address => uint) tokenTotalAmt;

    function deposit(address user, address token, uint amt) public onlyOwner {
        token.safeTransferFrom(msg.sender, address(this), amt);
        userTokenAmt[user][token] += amt;
        tokenTotalAmt[token] += amt;
    }

    function withdraw(address user, address token, uint amt) public onlyOwner {
        require(userTokenAmt[user][token] > amt, "uane");
        require(tokenTotalAmt[token] > amt, "tane");

        userTokenAmt[user][token] -= amt;
        tokenTotalAmt[token] -= amt;
        uint bal = token.myBalance();
        if (amt > bal) {
            amt = bal;
        }
        token.safeTransfer(msg.sender, amt);
    }
}