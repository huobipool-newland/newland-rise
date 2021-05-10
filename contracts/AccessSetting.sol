// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AccessSetting is Ownable {
    struct OpInfo {
        address op;
        bool enable;
    }

    //@opInfoMap.args '0xE1e9670D7AC114D145fdbc9D150c943ac8C1F828'
    mapping(address => OpInfo) public opInfoMap;

    //@opRecords.args 0
    address[] public opRecords;

    constructor() public {
        _setOps(msg.sender, true);
    }

    modifier onlyOps() {
        require(opInfoMap[msg.sender].enable, 'not operator');
        _;
    }

    // @setOps.args '0xE1e9670D7AC114D145fdbc9D150c943ac8C1F828',true
    function setOps(address op, bool enable) public onlyOwner {
        _setOps(op, enable);
    }

    function _setOps(address op, bool enable) internal {
        if (opInfoMap[op].op == address(0)) {
            opInfoMap[op].op = op;
            opRecords.push(op);
        }
        opInfoMap[op].enable = enable;
    }

    function getOpRecords() public view returns(address[] memory){
        return opRecords;
    }
}