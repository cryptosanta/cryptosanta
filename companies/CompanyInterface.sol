pragma solidity 0.4.18;

import './utils/Restriction.sol';

contract CompanyInterface is Restriction {
  function processing (address player, uint amount, uint ticketCount, uint totalTickets) isActive restricted public;

  function isStarted () public constant returns (bool);
  function isEnded () public constant returns (bool);

  function withdraw() public restricted isNotActive {
    msg.sender.transfer(this.balance);
  }

  function isActivated () public constant returns (bool) {
    return isStarted() && !isEnded();
  }

  modifier isActive () {
    require(false);
    _;
  }

  modifier isNotActive () {
    require(isEnded());
    _;
  }

  modifier isNotEnded () {
    require(false);
    _;
  }
}
