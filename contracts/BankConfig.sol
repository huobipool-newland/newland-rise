// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./interface/IBankConfig.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/InterestModel.sol";

contract BankConfig is IBankConfig, Ownable {
    uint256 public override getReserveBps;
    uint256 public override getLiquidateBps;
    InterestModel public interestModel;

    function setParams(uint256 _getReserveBps, uint256 _getLiquidateBps, InterestModel _interestModel) public onlyOwner {
        getReserveBps = _getReserveBps;
        getLiquidateBps = _getLiquidateBps;
        interestModel = _interestModel;
    }

    function getInterestRate(uint256 debt, uint256 floating) external override view returns (uint256) {
        return interestModel.getInterestRate(debt, floating);
    }
}