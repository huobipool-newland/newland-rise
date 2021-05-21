// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./interface/InterestModel.sol";
import "./interface/ILendbridge.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract CLendInterestModel is InterestModel {
    using SafeMath for uint256;

    ILendbridge public lendbridge;
    uint addInterestRateYear;

    constructor(ILendbridge _lendbridge, uint _addInterestRateYear) public {
        lendbridge = _lendbridge;
        addInterestRateYear = _addInterestRateYear;
    }

    function getInterestRate(address token, uint256 debt, uint256 floating) external override view returns (uint256) {
        uint rate = lendbridge.getInterestRate(token);
        if (rate == 0) {
            rate = _getInterestRate(debt, floating);
        } else {
            rate = rate + (addInterestRateYear / 365 days);
        }
        return rate;
    }

    function _getInterestRate(uint256 debt, uint256 floating) internal pure returns (uint256) {
        uint256 total = debt.add(floating);
        uint256 utilization = total == 0? 0: debt.mul(10000).div(total);
        if (utilization < 5000) {
            // Less than 50% utilization - 10% APY
            return uint256(10e16) / 365 days;
        } else if (utilization < 9500) {
            // Between 50% and 95% - 10%-25% APY
            return (10e16 + utilization.sub(5000).mul(15e16).div(10000)) / 365 days;
        } else if (utilization < 10000) {
            // Between 95% and 100% - 25%-100% APY
            return (25e16 + utilization.sub(7500).mul(75e16).div(10000)) / 365 days;
        } else {
            // Not possible, but just in case - 100% APY
            return uint256(100e16) / 365 days;
        }
    }
}