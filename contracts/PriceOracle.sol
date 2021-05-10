// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./AccessSetting.sol";

contract PriceOracle is AccessSetting {
    struct DataInfo {
        AggregatorV3Interface priceFeed;
        int price;
        uint timeStamp;
    }
    mapping(address => DataInfo) public dataInfoMap;

    function setPriceFeed(address token, AggregatorV3Interface priceFeed) public onlyOps {
        dataInfoMap[token].priceFeed = priceFeed;
    }

    function setPriceWrapper(address[] memory tokens, int[] memory prices) public onlyOps {
        for(uint i = 0; i < tokens.length; i++) {
            dataInfoMap[tokens[i]].price = prices[i];
            dataInfoMap[tokens[i]].timeStamp = block.timestamp;
        }
    }

    /**
     * Returns the latest price
     */
    function getPrice(address token) public view returns (int, uint) {
        DataInfo memory data = dataInfoMap[token];
        AggregatorV3Interface priceFeed = data.priceFeed;
        int price;
        uint timeStamp;
        if (address(priceFeed) != address(0)) {
            (
            ,
            price
            ,
            ,
            timeStamp
            ,
            ) = priceFeed.latestRoundData();
        }
        if (price <= 0) {
            price = data.price;
            timeStamp = data.timeStamp;
        }
        return (price, timeStamp);
    }
}
