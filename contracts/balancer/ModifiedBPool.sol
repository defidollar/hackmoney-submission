pragma solidity ^0.5.12;

import {BPool} from "./balancer-core/BPool.sol";
import {IAToken} from "../plugins/aave/IAToken.sol";

contract ModifiedBPool is BPool {
  function bind(address token, uint balance, uint denorm)
    public
  {
    IAToken(token).allowInterestRedirectionTo(_controller);
    // Takes care of ACLing on onlyController
    super.bind(token, balance, denorm);
  }

  function _pullUnderlying(address erc20, address from, uint amount) internal {
    if (amount == 0) return;
    super._pullUnderlying(erc20, from, amount);
  }

  function _pushUnderlying(address erc20, address to, uint amount)
    internal
  {
    if (amount == 0) return;
    super._pushUnderlying(erc20, to, amount);
  }

  function calcOutGivenIn(address tokenIn, uint tokenAmountIn, address tokenOut)
    public view
    returns (uint /* tokenAmountOut */)
  {
    Record storage inRecord = _records[address(tokenIn)];
    Record storage outRecord = _records[address(tokenOut)];
    return calcOutGivenIn(
      inRecord.balance,
      inRecord.denorm,
      outRecord.balance,
      outRecord.denorm,
      tokenAmountIn,
      _swapFee
    );
  }
}
