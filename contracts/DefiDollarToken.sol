pragma solidity ^0.5.12;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DefiDollarToken is ERC20 {
  address public defiDollar;

  constructor(address _defiDollar) public {
    defiDollar = _defiDollar;
  }

  modifier onlyDefiDollar() {
    require(msg.sender == defiDollar, "Unauthorized");
    _;
  }

  function mint(address account, uint256 amount) public onlyDefiDollar {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) public onlyDefiDollar {
    _burn(account, amount);
  }
}
