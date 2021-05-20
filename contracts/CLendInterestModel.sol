// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./interface/InterestModel.sol";
import "./interface/ILendbridge.sol";

contract CLendInterestModel is InterestModel {

    ILendbridge public lendbridge;

    constructor(ILendbridge _lendbridge) public {
        lendbridge = _lendbridge;
    }

    function getInterestRate(address token, uint256 /* debt */, uint256 /* floating */) external override view returns (uint256) {
        return lendbridge.getInterestRate(token);
    }
}