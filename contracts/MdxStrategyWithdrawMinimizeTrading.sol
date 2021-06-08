// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./library/SafeToken.sol";
import "./interface/Strategy.sol";
import "./interface/IWHT.sol";
import "./interface/IMdexFactory.sol";
import "./interface/IMdexRouter.sol";
import "./interface/IMdexPair.sol";
import "./interface/ISwapMining.sol";
import "./MdxExcessReward.sol";

contract MdxStrategyWithdrawMinimizeTrading is Ownable, ReentrancyGuard, Strategy, MdxExcessReward {
    using SafeToken for address;
    using SafeMath for uint256;

    IMdexFactory public factory;
    IMdexRouter public router;
    address public wht;

    /// @dev Create a new withdraw minimize trading strategy instance for mdx.
    /// @param _router The mdx router smart contract.
    constructor(IMdexRouter _router) public {
        factory = IMdexFactory(_router.factory());
        router = _router;
        wht = _router.WHT();
    }

    /// @dev Execute worker strategy. Take LP tokens. Return debt token + token want back.
    /// @param user User address to withdraw liquidity.
    /// @param borrowToken The token user borrow from bank.
    /// @param debt User's debt amount.
    /// @param data Extra calldata information passed along to this strategy.
    function execute(address user, address borrowToken, uint256 /* borrow */, uint256 debt, bytes calldata data)
    external
    override
    payable
    nonReentrant
    {
        // 1. Find out lpToken and liquidity.
        // whichWantBack: 0:token0;1:token1;2:token what surplus.
        (address token0, address token1, uint whichWantBack) = abi.decode(data, (address, address, uint));

        // is borrowToken is ht.
        bool isBorrowHt = borrowToken == address(0);
        borrowToken = isBorrowHt ? wht : borrowToken;

        // the relative token when token0 or token1 is ht.
        address htRelative = address(0);
        {
            if (token0 == address(0)){
                token0 = wht;
                htRelative = token1;
            }
            if (token1 == address(0)){
                token1 = wht;
                htRelative = token0;
            }
        }
        require(borrowToken == token0 || borrowToken == token1, "borrowToken not token0 and token1");
        require(whichWantBack == uint(0) || whichWantBack == uint(1) || whichWantBack == uint(2),
            "whichWantBack not in (0,1,2)");

        address tokenUserWant = whichWantBack == uint(0) ? token0 : token1;

        IMdexPair lpToken = IMdexPair(factory.getPair(token0, token1));
        token0 = lpToken.token0();
        token1 = lpToken.token1();

        {
            lpToken.approve(address(router), 0);
            lpToken.approve(address(router), uint256(-1));
            router.removeLiquidity(token0, token1, lpToken.balanceOf(address(this)), 0, 0, address(this), now);
        }
        {
            address tokenRelative = borrowToken == token0 ? token1 : token0;

            swapIfNeed(borrowToken, tokenRelative, debt);

            if (isBorrowHt) {
                IWHT(wht).withdraw(debt);
                SafeToken.safeTransferETH(msg.sender, debt);
            } else {
                SafeToken.safeTransfer(borrowToken, msg.sender, debt);
            }
        }

        // 2. swap remaining token to what user want.
        if (whichWantBack != uint(2)) {
            address tokenAnother = tokenUserWant == token0 ? token1 : token0;
            uint256 anotherAmount = tokenAnother.myBalance();
            if(anotherAmount > 0){
                tokenAnother.safeApprove(address(router), 0);
                tokenAnother.safeApprove(address(router), uint256(-1));

                address[] memory path = new address[](2);
                path[0] = tokenAnother;
                path[1] = tokenUserWant;
                router.swapExactTokensForTokens(anotherAmount, 0, path, address(this), now);
            }
        }

        // 3. send all tokens back.
        if (htRelative == address(0)) {
            token0.safeTransfer(user, token0.myBalance());
            token1.safeTransfer(user, token1.myBalance());
        } else {
            safeUnWrapperAndAllSend(wht, user);
            safeUnWrapperAndAllSend(htRelative, user);
        }
    }

    /// swap if need.
    function swapIfNeed(address borrowToken, address tokenRelative, uint256 debt) internal {
        uint256 borrowTokenAmount = borrowToken.myBalance();
        if (debt > borrowTokenAmount) {
            tokenRelative.safeApprove(address(router), 0);
            tokenRelative.safeApprove(address(router), uint256(-1));

            uint256 remainingDebt = debt.sub(borrowTokenAmount);
            address[] memory path = new address[](2);
            path[0] = tokenRelative;
            path[1] = borrowToken;
            router.swapTokensForExactTokens(remainingDebt, tokenRelative.myBalance(), path, address(this), now);
        }
    }

    /// get token balance, if is WHT un wrapper to HT and send to 'to'
    function safeUnWrapperAndAllSend(address token, address to) internal {
        uint256 total = SafeToken.myBalance(token);
        if (total > 0) {
            if (token == wht) {
                IWHT(wht).withdraw(total);
                SafeToken.safeTransferETH(to, total);
            } else {
                SafeToken.safeTransfer(token, to, total);
            }
        }
    }

fallback() external {}
receive() payable external {}
}