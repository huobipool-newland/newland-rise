// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./interface/IBankConfig.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/InterestModel.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract BankConfig is IBankConfig, Ownable {
    using SafeMath for uint256;

    uint256 public addInterestRateYear;
    uint256 public getReserveBps;
    InterestModel public interestModel;

    function setParams(uint256 _getReserveBps, uint256 _getLiquidateBps, InterestModel _interestModel, uint _addInterestRateYear) public onlyOwner {
        getReserveBps = _getReserveBps;
        getLiquidateBps = _getLiquidateBps;
        interestModel = _interestModel;
        addInterestRateYear = _addInterestRateYear;
    }

    function getInterestRate(address token, uint256 debt, uint256 floating) external override view returns (uint256) {
        return interestModel.getInterestRate(token, debt, floating, addInterestRateYear);
    }

    function getDyReserveBps(uint rate) public view override returns(uint256) {
        uint extRate = addInterestRateYear / 365 days;
        uint bps = getReserveBps;
        if (extRate > 0) {
            bps = getReserveBps.mul(extRate).div(rate);
        }
        return bps;
    }

    uint256 public override getLiquidateBps;
}