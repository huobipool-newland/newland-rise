// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract Oracle is Ownable{
    struct DataInfo {
        AggregatorV3Interface priceFeed;
        int wrapperPrice;
        uint wrapperTimeStamp;
    }
    mapping(address => DataInfo) dataInfoMap;

    function setPriceFeed(address token, AggregatorV3Interface priceFeed) public onlyOwner {
        dataInfoMap[token].priceFeed = priceFeed;
    }

    function setWrapper(address token, int price, uint timeStamp) public onlyOwner {
        dataInfoMap[token].wrapperPrice = price;
        dataInfoMap[token].wrapperTimeStamp = timeStamp;
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
            price = data.wrapperPrice;
            timeStamp = data.wrapperTimeStamp;
        }
        return (price, timeStamp);
    }
}
