pragma solidity ^0.5.12;

import {UpgradableProxy} from "../common/proxy/UpgradableProxy.sol";
import {IAToken} from "../plugins/aave/IAToken.sol";

contract BPoolProxy is UpgradableProxy {
  constructor(address _proxyTo) public UpgradableProxy(_proxyTo) {}

  /**
   * @dev proxy.owner is the controller
   * @dev Jumps to implementation.bind which checks onlyController ACL
   */
  function bind(address token, uint balance, uint denorm)
    external
  {
    IAToken(token).allowInterestRedirectionTo(loadOwner());
    delegatedFwd(loadImplementation(), msg.data);
  }
}
