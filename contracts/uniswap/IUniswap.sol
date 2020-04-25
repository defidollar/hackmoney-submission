pragma solidity ^0.5.15;

contract IUniswap {
  function tradeExactOut(address _in, address out, uint256 exactOut) public returns(uint256 inAmount);
  function tradeExactIn(address _in, address out, uint256 exactIn) public returns(uint256 outAmount);
}
