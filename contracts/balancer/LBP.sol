pragma solidity ^0.5.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { LiquidityBootstrappingPool } from "./smart-pools/LiquidityBootstrappingPool.sol";
import { IAToken } from "../plugins/aave/IAToken.sol";

contract LBP is LiquidityBootstrappingPool {
  modifier _onlyController_() {
    require(
      msg.sender == _controller,
      "ONLY_CONTROLLER"
    );
    _;
  }

  constructor(
    address bPool,
    address[] memory tokens,
    uint[] memory startBalances,
    uint[] memory startWeights,
    uint[] memory endWeights,
    uint swapFee
  )
    public
    LiquidityBootstrappingPool(
      bPool,
      tokens,
      startBalances,
      startWeights,
      endWeights,
      [0, 0, swapFee] // startBlock, endBlock, swapFee
    )
  {
  }

  function rebind(address token, uint balance, uint denorm)
    public
    _onlyController_
  {
    _bPool.rebind(token, balance, denorm);
    IERC20 erc20 = IERC20(token);
    // send any residue tokens to core. This situation may arise if we bind balance less than previous
    uint256 residueBalance = erc20.balanceOf(address(this));
    if (residueBalance > 0) {
      erc20.transfer(_controller, residueBalance);
    }
  }

  function setController(address manager)
    public
    /* ACL is managed by super.setController */
  {
    super.setController(manager);
    address[] memory tokens = _bPool.getCurrentTokens();
    for (uint8 i = 0; i < tokens.length; i++) {
      IAToken(tokens[i]).redirectInterestStreamOf(address(_bPool), manager);
    }
  }

  // UI helper functions
  function calcSingleInGivenPoolOut(uint poolAmountOut, address tokenIn)
    public view
    returns (uint /* tokenAmountIn */)
  {
    return _bPool.calcSingleInGivenPoolOut(
      _bPool.getBalance(tokenIn),
      _bPool.getDenormalizedWeight(tokenIn),
      _totalSupply,
      _bPool.getTotalDenormalizedWeight(),
      poolAmountOut,
      _swapFee
    );
  }

  function calcPoolInGivenSingleOut(address tokenOut, uint tokenAmountOut)
    public view
    returns (uint /* poolAmountIn */)
  {
    return _bPool.calcPoolInGivenSingleOut(
      _bPool.getBalance(tokenOut),
      _bPool.getDenormalizedWeight(tokenOut),
      _totalSupply,
      _bPool.getTotalDenormalizedWeight(),
      tokenAmountOut,
      _swapFee
    );
  }

  function calcPoolOutGivenSingleIn(address tokenIn, uint tokenAmountIn)
    public view
    returns (uint /* poolAmountOut */)
  {
    return _bPool.calcPoolOutGivenSingleIn(
      _bPool.getBalance(tokenIn),
      _bPool.getDenormalizedWeight(tokenIn),
      _totalSupply,
      _bPool.getTotalDenormalizedWeight(),
      tokenAmountIn,
      _swapFee
    );
  }

  function calcSingleOutGivenPoolIn(address tokenOut, uint poolAmountIn)
    public view
    returns (uint /* tokenAmountOut */)
  {
    return _bPool.calcSingleOutGivenPoolIn(
      _bPool.getBalance(tokenOut),
      _bPool.getDenormalizedWeight(tokenOut),
      _totalSupply,
      _bPool.getTotalDenormalizedWeight(),
      poolAmountIn,
      _swapFee
    );
  }
}
