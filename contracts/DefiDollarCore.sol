pragma solidity ^0.5.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/math/Math.sol";

import { ILendingPool } from "./aave/ILendingPool.sol";
import { IAToken } from "./aave/IAToken.sol";
import { BFactory } from "./balancer/BFactory.sol";
import { BPool } from "./balancer/BPool.sol";

import { DefiDollarToken } from "./DefiDollarToken.sol";
import { Oracle } from "./chainlink/Oracle.sol";

contract DefiDollarCore {
  address[] public reserves;
  uint8 public numReserves;
  uint[] public denorm;
  mapping(address => address) public reserveToAtoken;

  DefiDollarToken public token;
  ILendingPool public aaveLendingPool;
  BPool public bpool;
  Oracle public oracle;

  uint public constant UINT_MAX_VALUE = uint256(-1);

  constructor(
    address[] memory _reserves,
    address[] memory _aTokens,
    address _aaveLendingPool,
    address _aaveLendingPoolCore,
    address _oracle
  ) public {
    reserves = _reserves;
    numReserves = uint8(_reserves.length);
    aaveLendingPool = ILendingPool(_aaveLendingPool);
    oracle = Oracle(_oracle);
    // These allowances might eventually run out, so need a function to be able to refresh allowances
    for (uint8 i = 0; i < numReserves; i++) {
      reserveToAtoken[_reserves[i]] = _aTokens[i];
      require(
        IERC20(_reserves[i]).approve(_aaveLendingPoolCore, UINT_MAX_VALUE),
        "Reserve coin approval failed"
      );
      // interest from aave will go to feePool contract
      // IAToken(_aTokens[i]).redirectInterestStream(_feePool);
    }
  }

  function initialize(
    address _defiDollarToken,
    address _bFactory,
    uint[] calldata _balances,
    uint[] calldata _denorm
  ) external /* notInitialized */ {
    token = DefiDollarToken(_defiDollarToken);
    bpool = BFactory(_bFactory).newBPool();
    denorm = _denorm;
    uint totalDeposit = 0;
    for (uint8 i = 0; i < numReserves; i++) {
      _pullToken(reserves[i], msg.sender, address(this), _balances[i]);
      _depositToAave(reserves[i], _balances[i]);
      require(
        IERC20(reserveToAtoken[reserves[i]]).approve(address(bpool), UINT_MAX_VALUE),
        "Reserve coin approval to bpool failed"
      );
      bpool.bind(reserveToAtoken[reserves[i]], _balances[i], _denorm[i]);
      // assuming each given coin is worth a $ at start
      totalDeposit += _balances[i];
    }
    bpool.setSwapFee(0);
    bpool.softFinalize(); // this will mint INIT_POOL_SUPPLY = 10**18 * 100 pool tokens to address(this)
    token.mint(msg.sender, totalDeposit);
  }

  function mintExactIn(address reserve, uint tokenAmountIn, uint minPoolAmountOut, address to)
    external
    returns(uint)
  {
    _pullToken(reserve, msg.sender, address(this), tokenAmountIn);
    _depositToAave(reserve, tokenAmountIn);
    // will revert if reserve and hence mdata.aToken is not supported
    uint poolAmountOut = bpool.joinswapExternAmountIn(reserveToAtoken[reserve], tokenAmountIn, minPoolAmountOut);
    token.mint(to, poolAmountOut);
    return poolAmountOut;
  }

  function mintExactOut(address reserve, uint poolAmountOut, uint maxAmountIn, address to)
    external
    returns (uint)
  {
    _pullToken(reserve, msg.sender, address(this), maxAmountIn);
    _depositToAave(reserve, maxAmountIn);
    // will revert if reserve and hence mdata.aToken is not supported
    uint tokenAmountIn = bpool.joinswapPoolAmountOut(reserveToAtoken[reserve], poolAmountOut, maxAmountIn);
    if (tokenAmountIn < maxAmountIn) {
      _withdrawFromAave(reserve, maxAmountIn - tokenAmountIn, to);
    }
    token.mint(to, poolAmountOut);
    return tokenAmountIn;
  }

  function redeemExact(address tokenOut, uint poolAmountIn, uint minAmountOut)
    external
    returns(uint)
  {
    token.burn(msg.sender, poolAmountIn);
    uint tokenAmountOut = bpool.exitswapPoolAmountIn(reserveToAtoken[tokenOut], poolAmountIn, minAmountOut);
    _withdrawFromAave(tokenOut, tokenAmountOut, msg.sender);
    return tokenAmountOut;
  }

  function redeemExactOut(address tokenOut, uint tokenAmountOut, uint maxPoolAmountIn)
    external
    returns(uint)
  {
    uint poolAmountIn = bpool.exitswapExternAmountOut(reserveToAtoken[tokenOut], tokenAmountOut, maxPoolAmountIn);
    token.burn(msg.sender, poolAmountIn);
    _withdrawFromAave(tokenOut, tokenAmountOut, msg.sender);
    return poolAmountIn;
  }

  event debug(uint indexed poolBalance, int256 indexed feed, int256 indexed coinDelta, uint8 i);
  function reBalance() public {
    int256[] memory feed = oracle.getPriceFeed();
    uint supply = token.totalSupply();
    for(uint8 i = 0; i < reserves.length; i++) {
      address aToken = reserveToAtoken[reserves[i]];
      (uint norm, uint poolBalance) = _poolMetadata(aToken);
      uint marketCap = supply * norm;
      uint newBalance = marketCap / uint(feed[i]);
      if (newBalance == poolBalance) {
        continue;
      }
      uint coreBalance = IAToken(aToken).balanceOf(address(this));
      if (newBalance > poolBalance + coreBalance) {
        // can't give more than what the core has accumulated in earnings
        newBalance = poolBalance + coreBalance;
      } else if (newBalance < 10**6) {
        // balancer pool requires a MIN_BALANCE = 10**6
        newBalance = 10**6;
      }
      bpool.rebind(aToken, newBalance, denorm[i]);
    }
  }

  // #### Internal Functions ###

  function _poolMetadata(address _token) internal view returns(uint norm, uint balance) {
    norm = bpool.getNormalizedWeight(_token);
    balance = bpool.getBalance(_token);
  }

  /**
  * @dev Deposit assets to aave
  * @param reserve The actual erc20 token address
  */
  function _depositToAave(address reserve, uint256 quantity) internal {
    aaveLendingPool.deposit(reserve, quantity, 0); // _referralCode
    // reserveToAtoken[reserve].balance += quantity;
  }

  function _withdrawFromAave(address reserve, uint256 quantity, address to) internal {
    IAToken(reserveToAtoken[reserve]).redeem(quantity);
    // mdata.balance -= quantity;
    if (to != address(0x0)) {
      require(
        IERC20(reserve).transfer(to, quantity),
        "Token transfer failed"
      );
    }
  }

  function _pullToken(address _token, address from, address to, uint amount) internal {
    require(
      IERC20(_token).transferFrom(from, to, amount),
      "ERR_ERC20_FALSE"
    );
  }
}
