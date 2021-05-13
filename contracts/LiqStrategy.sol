// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./library/SafeToken.sol";
import "./library/Math.sol";
import "./interface/Strategy.sol";
import "./interface/IWHT.sol";
import "./interface/IMdexFactory.sol";
import "./interface/IMdexRouter.sol";
import "./interface/IMdexPair.sol";
import "./MdxExcessReward.sol";

contract LiqStrategy is Ownable, ReentrancyGuard, Strategy, MdxExcessReward {
    using SafeToken for address;
    using SafeMath for uint256;

    IMdexFactory public factory;
    IMdexRouter public router;
    address public wht;

    /// @dev Create a new add two-side optimal strategy instance for mdx.
    /// @param _router The mdx router smart contract.
    constructor(IMdexRouter _router) public {
        factory = IMdexFactory(_router.factory());
        router = _router;

        wht = _router.WHT();
    }

    function execute(address /* user */, address borrowToken, uint256 /* borrow */, uint256 /* debt */, bytes calldata data)
    external
    override
    payable
    nonReentrant
    {
        IMdexPair lpToken = IMdexPair(abi.decode(data, (address)));
        address token0 = lpToken.token0();
        address token1 = lpToken.token1();

        // is borrowToken is ht.
        bool isBorrowHt = borrowToken == address(0);
        borrowToken = isBorrowHt ? wht : borrowToken;

        require(borrowToken == token0 || borrowToken == token1, "borrowToken not token0 and token1");

        {
            lpToken.approve(address(router), uint256(-1));
            router.removeLiquidity(token0, token1, lpToken.balanceOf(address(this)), 0, 0, address(this), now);
        }
        {
            address tokenRelative = borrowToken == token0 ? token1 : token0;
            swapToBorrowToken(borrowToken, tokenRelative);
            if (isBorrowHt) {
                IWHT(wht).withdraw(borrowToken.myBalance());
                SafeToken.safeTransferETH(msg.sender, borrowToken.myBalance());
            } else {
                SafeToken.safeTransfer(borrowToken, msg.sender, borrowToken.myBalance());
            }
        }
    }

    function swapToBorrowToken(address borrowToken, address tokenRelative) internal {
        tokenRelative.safeApprove(address(router), 0);
        tokenRelative.safeApprove(address(router), uint256(-1));

        address[] memory path = new address[](2);
        path[0] = tokenRelative;
        path[1] = borrowToken;
        router.swapExactTokensForTokens(tokenRelative.myBalance(), 0, path, address(this), now);
    }

fallback() external {}
receive() payable external {}
}