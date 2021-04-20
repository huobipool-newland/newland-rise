// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./NToken.sol";

contract NTokenFactory {

    function genNToken(string memory _symbol) public returns(address) {
        return address(new NToken(_symbol));
    }
}