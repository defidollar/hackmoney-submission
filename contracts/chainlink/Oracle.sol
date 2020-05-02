pragma solidity ^0.5.0;

import "@chainlink/contracts/src/v0.5/dev/AggregatorInterface.sol";

contract Oracle {
  AggregatorInterface[] public refs;

  constructor(address[] memory _aggregators) public {
    refs.length = _aggregators.length;
    for(uint8 i = 0; i < _aggregators.length; i++) {
      // will have to normalize decimal places
      refs[i] = AggregatorInterface(_aggregators[i]);
    }
  }

  function getPriceFeed() public view returns(int256[] memory) {
    int256[] memory feed = new int256[](refs.length);
    for(uint8 i = 0; i < refs.length; i++) {
      // will have to normalize decimal places
      feed[i] = refs[i].latestAnswer();
    }
    return feed;
  }
}
