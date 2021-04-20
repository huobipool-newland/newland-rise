// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./library/SafeToken.sol";

contract NToken is ERC20, Ownable {
    using SafeToken for address;
    using SafeMath for uint256;

    event Mint(address sender, address account, uint amount);
    event Burn(address sender, address account, uint amount);

    constructor(string memory _symbol) public ERC20(_symbol, _symbol) {

    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
        emit Mint(msg.sender, account, amount);
    }

    function burn(address account, uint256 value) public onlyOwner {
        _burn(account, value);
        emit Burn(msg.sender, account, value);
    }
}