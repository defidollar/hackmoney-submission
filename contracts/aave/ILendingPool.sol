pragma solidity ^0.5.15;

contract ILendingPool {
  function deposit(address _reserve, uint256 _amount, uint16 _referralCode) public;
}
