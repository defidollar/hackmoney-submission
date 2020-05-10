pragma solidity ^0.5.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IUniswap } from "./IUniswap.sol";
import { AavePlugin } from "../aave/AavePlugin.sol";
import { Pool } from "../../Pool.sol";

contract UniswapPlugin {
  IUniswap public uniswap;
  AavePlugin public aave;
  Pool public pool;

  uint256 public constant UINT_MAX_VALUE = uint256(-1);

  constructor(
    IUniswap _uniswap,
    AavePlugin _aave,
    Pool _pool)
    public
  {
    uniswap = _uniswap;
    aave = _aave;
    pool = _pool;
  }

  function mintExactIn(
    address tokenIn,
    uint256 tokenAmountIn,
    uint minPoolAmountOut,
    address intermediateReserveToken)
    external
    returns(uint poolAmountOut)
  {
    require(
      IERC20(tokenIn).transferFrom(msg.sender, address(this), tokenAmountIn),
      "In token transfer failed"
    );
    uint _tokenAmountIn = tokenAmountIn;
    if (tokenIn != intermediateReserveToken) {
      IERC20(tokenIn).approve(address(uniswap), tokenAmountIn);
      address[] memory path = new address[](2);
      path[0] = tokenIn;
      path[1] = intermediateReserveToken;
      // even with amountOutMin == 0, final assertion will take care of the slippage check
      uint[] memory amounts = uniswap.swapExactTokensForTokens(
        tokenAmountIn,
        0, // amountOutMin
        path,
        address(this), // to
        UINT_MAX_VALUE // deadline
      );
      _tokenAmountIn = amounts[1];
    }
    require(
      IERC20(intermediateReserveToken).approve(address(aave), _tokenAmountIn),
      "Approval to aave failed"
    );
    // provide minPoolAmountOut == 0 and assert on the quantity later
    poolAmountOut = aave.mintExactIn(intermediateReserveToken, _tokenAmountIn, 0 /* minPoolAmountOut */);
    require(
      poolAmountOut >= minPoolAmountOut,
      "Too much slippage"
    );
    pool.transfer(msg.sender, poolAmountOut);
  }

  function redeemExact(
    uint poolAmountIn,
    address tokenOut,
    uint minTokenAmountOut,
    address intermediateReserveToken)
    external
    returns(uint tokenAmountOut)
  {
    require(
      pool.transferFrom(msg.sender, address(this), poolAmountIn),
      "Pool token transfer failed"
    );
    require(
      pool.approve(address(aave), poolAmountIn),
      "Approval to aave failed"
    );
    tokenAmountOut = aave.redeemExact(poolAmountIn, intermediateReserveToken, 0 /* minTokenAmountOut */);
    if (tokenOut != intermediateReserveToken) {
      address[] memory path = new address[](2);
      path[0] = intermediateReserveToken;
      path[1] = tokenOut;
      IERC20(intermediateReserveToken).approve(address(uniswap), tokenAmountOut);
      uint[] memory amounts = uniswap.swapExactTokensForTokens(
        tokenAmountOut,
        0, // amountOutMin
        path,
        address(this), // to
        UINT_MAX_VALUE // deadline
      );
      tokenAmountOut = amounts[1];
    }
    require(
      tokenAmountOut >= minTokenAmountOut,
      "Too much slippage"
    );
    IERC20(tokenOut).transfer(msg.sender, tokenAmountOut);
  }

  // /**
  // * @notice Mint a specific amount of DefiDollars
  // * @param inToken ERC20 token that the user is willing to trade for DefiDollar
  // * @param maxInQuantity Max quantity of inToken that the caller is willing to part with
  // * @param pIssue Exact amount of DefiDollars to issue (no more, no less are issued)
  // */
  // function mint(address inToken, uint256 maxInQuantity, uint256 pIssue) external {
  //   require(
  //     IERC20(inToken).transferFrom(msg.sender, address(this), maxInQuantity),
  //     "In token transfer failed"
  //   );
  //   (address[] memory reserves, uint256[] memory amounts) = defiDollarCore.getPoolDelta(pIssue);
  //   uint256 cumulativeIn = 0;
  //   uint[] memory _tradeAmounts;
  //   address[] memory path = new address[](2);
  //   path[0] = inToken;
  //   for (uint8 i = 0; i < reserves.length; i++) {
  //     path[1] = reserves[i];
  //     _tradeAmounts = uniswap.swapTokensForExactTokens(
  //       amounts[i], // amountOut
  //       UINT_MAX_VALUE, // amountInMax
  //       path,
  //       address(defiDollarCore), // to
  //       UINT_MAX_VALUE // deadline
  //     );
  //     cumulativeIn += _tradeAmounts[0];
  //     // this check most likely is redundant. Remove later
  //     require(
  //       _tradeAmounts[_tradeAmounts.length - 1] == amounts[i],
  //       "Didn't get exact amount"
  //     );
  //   }
  //   defiDollarCore.mint(pIssue, msg.sender);
  //   // If the required amount is greater than maxInQuantity, uniswap trade would already have been reverted by now
  //   if (cumulativeIn < maxInQuantity) {
  //     require(
  //       IERC20(inToken).transfer(msg.sender, maxInQuantity - cumulativeIn),
  //       "Returning balance failed"
  //     );
  //   }
  // }

  // /**
  // * @notice Burn a specific amount of DefiDollars
  // * @param outToken ERC20 token that the user is willing to receive for DefiDollars
  // * @param minOutQuantity Min quantity of outToken that the caller expects
  // * @param pRedeem Amount of DefiDollars to redeem
  // */
  // function redeem(address outToken, uint256 minOutQuantity, uint256 pRedeem) external {
  //   require(
  //     token.transferFrom(msg.sender, address(this), pRedeem),
  //     "In token transfer failed"
  //   );
  //   defiDollarCore.redeem(pRedeem, address(this));
  //   (address[] memory reserves, uint256[] memory amounts) = defiDollarCore.getPoolDelta(pRedeem);
  //   uint256 cumulativeOut = 0;
  //   uint[] memory _tradeAmounts;
  //   address[] memory path = new address[](2);
  //   path[1] = outToken; // for now, assume that a direct path exists
  //   for (uint8 i = 0; i < reserves.length; i++) {
  //     path[0] = reserves[i];
  //     _tradeAmounts = uniswap.swapExactTokensForTokens(
  //       amounts[i], // exact amountIn
  //       0, // amountOutMin
  //       path,
  //       msg.sender, // to
  //       UINT_MAX_VALUE
  //     );
  //     cumulativeOut += _tradeAmounts[_tradeAmounts.length - 1];
  //     // this check most likely is redundant. Remove later
  //     require(
  //       _tradeAmounts[0] == amounts[i],
  //       "Didn't get exact amount"
  //     );
  //   }
  //   require(
  //     cumulativeOut >= minOutQuantity,
  //     "Too much slippage"
  //   );
  // }
}
