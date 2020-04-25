pragma solidity ^0.5.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DefiDollarToken } from "./DefiDollarToken.sol";
import { ILendingPool } from "./aave/ILendingPool.sol";
import { IAToken } from "./aave/IAToken.sol";

contract DefiDollarCore {
  address[] public reserves;

  struct ReserveMetadata {
    uint256 balance;
    address aToken;
  }
  uint8 public numReserves;
  mapping(address => ReserveMetadata) public reserveToMetadata;
  DefiDollarToken public token;
  ILendingPool public aaveLendingPool;

  uint256 public constant UINT_MAX_VALUE = uint256(-1);

  constructor(
    address[] memory _reserves,
    address[] memory _aTokens,
    address _defiDollarToken,
    address _aaveLendingPool,
    address _aaveLendingPoolCore,
    address _feePool
  ) public {
    reserves = _reserves;
    numReserves = uint8(_reserves.length);
    token = DefiDollarToken(_defiDollarToken);
    aaveLendingPool = ILendingPool(_aaveLendingPool);
    // These allowances might eventually run out, so need a function to be able to refresh allowances
    for (uint8 i = 0; i < numReserves; i++) {
      reserveToMetadata[_reserves[i]] = ReserveMetadata(0, _aTokens[i]);
      require(
        IERC20(_reserves[i]).approve(_aaveLendingPoolCore, UINT_MAX_VALUE),
        "Reserve coin approval failed"
      );
      // interest from aave will go to feePool contract
      IAToken(_aTokens[i]).redirectInterestStream(_feePool);
    }
  }

  /**
  * @notice Provide initial liquidity and call this
  */
  function initialize(uint256 pIssue) public /* notInitialized */ {
    uint256 each;
    for (uint8 i = 0; i < numReserves; i++) {
      uint256 balance = IERC20(reserves[i]).balanceOf(address(this));
      if (i == 0) {
        each = balance;
      } else {
        require(each == balance, "Provided unequal amount of coins");
      }
      _depositToAave(reserves[i], balance);
    }
    require(numReserves * each == pIssue, "Something went wrong");
    token.mint(msg.sender, pIssue);
  }

  /**
  * @notice Mint a specific amount of DefiDollars
  * @param pIssue Exact amount of DefiDollars to issue (no more, no less are issued)
  */
  function mint(uint256 pIssue, address to) external {
    if (to == address(0x0)) {
      to = msg.sender;
    }
    uint256 ratio = pIssue / token.totalSupply();
    uint256 inQuantity;
    for (uint8 i = 0; i < numReserves; i++) {
      ReserveMetadata storage mdata = reserveToMetadata[reserves[i]];
      // exact deposit amount to the reserve to be able to mint pIssue
      inQuantity = ratio * mdata.balance; // take care of the differing scaling factors for different tokens
      // It is assumed that this contract owns inReserve # tokens for reserves[i] by this point
      _depositToAave(reserves[i], inQuantity);
    }
    token.mint(to, pIssue);
  }

  function getPoolDelta(uint256 pDelta)
    public
    view
    returns(address[] memory _reserves, uint256[] memory _amounts
  ) {
    _reserves = new address[](numReserves);
    _amounts = new uint256[](numReserves);
    uint256 ratio = pDelta / token.totalSupply();
    for (uint8 i = 0; i < numReserves; i++) {
      _reserves[i] = reserves[i];
      _amounts[i] = ratio * reserveToMetadata[reserves[i]].balance; // take care of the differing scaling factors for different tokens
    }
  }

  /**
  * @notice Redeem a specific amount of DefiDollars
  * @param pRedeem Amount of DefiDollars to redeem
  */
  function redeem(uint256 pRedeem, address to) external {
    token.burn(msg.sender, pRedeem);
    if (to == address(0x0)) {
      to = msg.sender;
    }
    uint256 ratio = pRedeem / token.totalSupply();
    uint256 outQuantity;
    for (uint8 i = 0; i < numReserves; i++) {
      ReserveMetadata storage mdata = reserveToMetadata[reserves[i]];
      outQuantity = ratio * mdata.balance;
      _withdrawFromAave(reserves[i], outQuantity, to); // redeems exactly outReserve # tokens
    }
  }

  function trade(address inToken, address outToken, uint256 inQuantity) external {
    ReserveMetadata storage inMdata = reserveToMetadata[inToken];
    ReserveMetadata storage outMdata = reserveToMetadata[outToken];
    require(
      inMdata.aToken != address(0x0) && outMdata.aToken != address(0x0),
      "Out / in Token not supported"
    );
    require(
      IERC20(inToken).transferFrom(msg.sender, address(this), inQuantity),
      "In token transfer failed"
    );
    _depositToAave(inToken, inQuantity);
    uint256 outQuantity = getOutQuantity(inMdata.aToken, outMdata.aToken, inQuantity);
    _withdrawFromAave(outToken, outQuantity, msg.sender);
  }

  function getOutQuantity(address inAToken, address outAToken, uint256 inQuantity) public view returns(uint256 outQuantity) {
    uint256 inTokenPoolSize = getPoolSize(inAToken);
    uint256 outTokenPoolSize = getPoolSize(outAToken);
    outQuantity = outTokenPoolSize * (inQuantity / inTokenPoolSize);
  }

  function getPoolSize(address aToken) public view returns(uint256) {
    return IAToken(aToken).balanceOf(address(this));
  }

  // #### Internal Functions ###

  /**
  * @dev Deposit assets to aave
  * @param reserve The actual erc20 token address
  */
  function _depositToAave(address reserve, uint256 quantity) internal {
    aaveLendingPool.deposit(reserve, quantity, 0); // _referralCode
    reserveToMetadata[reserve].balance += quantity;
  }

  function _withdrawFromAave(address reserve, uint256 quantity, address to) internal {
    ReserveMetadata storage mdata = reserveToMetadata[reserve];
    IAToken(mdata.aToken).redeem(quantity);
    mdata.balance -= quantity;
    if (to != address(0x0)) {
      require(
        IERC20(reserve).transfer(to, quantity),
        "Token transfer failed"
      );
    }
  }
}
