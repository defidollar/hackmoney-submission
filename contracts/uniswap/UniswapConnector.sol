pragma solidity ^0.5.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IUniswap } from "./IUniswap.sol";
import { DefiDollarCore } from "../DefiDollarCore.sol";
import { DefiDollarToken } from "../DefiDollarToken.sol";

contract UniswapConnector {
  IUniswap public uniswap;
  DefiDollarCore public defiDollarCore;
  DefiDollarToken public token;

  constructor(address _defiDollarCore, address _defiDollarToken, address _uniswap) public {
    defiDollarCore = DefiDollarCore(_defiDollarCore);
    token = DefiDollarToken(_defiDollarToken);
    uniswap = IUniswap(_uniswap);
  }

  /**
  * @notice Mint a specific amount of DefiDollars
  * @param inToken ERC20 token that the user is willing to trade for DefiDollar
  * @param maxInQuantity Max quantity of inToken that the caller is willing to part with
  * @param pIssue Exact amount of DefiDollars to issue (no more, no less are issued)
  */
  function mint(address inToken, uint256 maxInQuantity, uint256 pIssue) external {
    require(
      IERC20(inToken).transferFrom(msg.sender, address(this), maxInQuantity),
      "In token transfer failed"
    );
    (address[] memory reserves, uint256[] memory amounts) = defiDollarCore.getPoolDelta(pIssue);
    uint256 cumulativeIn = 0;
    for (uint8 i = 0; i < reserves.length; i++) {
      uint256 _in = uniswap.tradeExactOut(
        inToken,
        address(reserves[i]), // out token
        amounts[i] // receive exactly inReserve # of out token
      );
      cumulativeIn += _in;
    }
    defiDollarCore.mint(pIssue, msg.sender);
    // If the required amount is greater than maxInQuantity, uniswap trade would already have been reverted by now
    if (cumulativeIn < maxInQuantity) {
      require(
        IERC20(inToken).transfer(msg.sender, maxInQuantity - cumulativeIn),
        "Returning balance failed"
      );
    }
  }

  /**
  * @notice Burn a specific amount of DefiDollars
  * @param outToken ERC20 token that the user is willing to receive for DefiDollars
  * @param minOutQuantity Min quantity of outToken that the caller expects
  * @param pRedeem Amount of DefiDollars to redeem
  */
  function redeem(address outToken, uint256 minOutQuantity, uint256 pRedeem) external {
    require(
      token.transferFrom(msg.sender, address(this), pRedeem),
      "In token transfer failed"
    );
    defiDollarCore.redeem(pRedeem, address(this));
    (address[] memory reserves, uint256[] memory amounts) = defiDollarCore.getPoolDelta(pRedeem);
    uint256 cumulativeOut = 0;
    for (uint8 i = 0; i < reserves.length; i++) {
      uint256 out = uniswap.tradeExactIn(
        reserves[i], // in token
        outToken,
        amounts[i] // exact in amount
      );
      cumulativeOut += out;
    }
    require(
      cumulativeOut >= minOutQuantity,
      "Too much slippage"
    );
    require(
      IERC20(outToken).transfer(msg.sender, cumulativeOut),
      "Token transfer failed"
    );
  }
}
