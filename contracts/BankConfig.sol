// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./interface/IBankConfig.sol";

contract BankConfig is IBankConfig {
    uint interestRateFact;
    uint reserveBps;
    uint liquidateBps;

    function setInterestRateFact(uint _interestRateFact) public {
        interestRateFact = _interestRateFact;
    }

    function setReserveBps(uint _reserveBps) public {
        reserveBps = _reserveBps;
    }

    function setLiquidateBps(uint _liquidateBps) public {
        liquidateBps = _liquidateBps;
    }

    function getInterestRate(uint256 debt, uint256 floating) public override view returns (uint256) {
        return interestRateFact;
    }

    function getReserveBps() public override view returns (uint256) {
        return reserveBps;
    }

    function getLiquidateBps() public override view returns (uint256) {
        return liquidateBps;
    }

}