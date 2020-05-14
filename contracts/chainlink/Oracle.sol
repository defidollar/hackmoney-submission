pragma solidity ^0.5.0;

import "@chainlink/contracts/src/v0.5/dev/AggregatorInterface.sol";

contract Oracle {
  AggregatorInterface[] public refs;
  AggregatorInterface public ethUsdAggregator;

  /**
  * @dev Initialize oracle with chainlink aggregators
  * @param _aggregators <coin>-ETH Aggregator
  * @param _ethUsdAggregator ETH-USD Aggregator
  */
  constructor(AggregatorInterface[] memory _aggregators, AggregatorInterface _ethUsdAggregator) public {
    refs.length = _aggregators.length;
    for(uint8 i = 0; i < _aggregators.length; i++) {
      refs[i] = _aggregators[i];
    }
    ethUsdAggregator = _ethUsdAggregator;
  }

  /**
  * @dev The latestAnswer value for all USD reference data contracts is multiplied by 100000000 before being written on-chain and
  * by 1000000000000000000 for all ETH pairs.
  */
  function getPriceFeed() public view returns(int256[] memory feed) {
    int256 ethUsdRate = ethUsdAggregator.latestAnswer();
    feed = new int256[](refs.length);
    for(uint8 i = 0; i < refs.length; i++) {
      feed[i] = (refs[i].latestAnswer() * ethUsdRate) / 100000000;
    }
    return feed;
  }
}
