pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './../CompanyInterface.sol';

contract CashBackCompany is CompanyInterface {
  using SafeMath for uint256;
  using SafeMath for uint16;

  uint256 startTime;
  uint256 endTime;

  struct CashBackRule {
    uint16 ticketsLimit;
    uint8 refund;
  }

  CashBackRule[] public rules;

  function () public payable {}

  function CashBackCompany (uint _startTime, uint _endTime) public payable {
    require(_startTime >= now);
    require(_endTime >= _startTime);

    startTime = _startTime;
    endTime = _endTime;
  }

  function addRule (uint ticketsLimit, uint refund) public isNotEnded restricted {
    rules.push(CashBackRule(uint16(ticketsLimit), uint8(refund)));
  }

  function processing (address player, uint amount, uint ticketCount, uint totalTickets) isActive restricted public {
    if (rules.length == 0) {return;}

    uint16 ticketsRefunded = 0;
    uint16 offset = 0;

    for (uint i = 0; i < rules.length; i++) {
      uint tickets = ticketCount - ticketsRefunded;
      if (tickets == 0) {break;}

      CashBackRule storage rule = rules[i];

      uint16 ticketsLimit = rule.ticketsLimit + offset;

      offset += rule.ticketsLimit;

      if (totalTickets.add(ticketsRefunded) < ticketsLimit) {
        uint16 ticketsCountForRefund = uint16(ticketsForRefund(ticketsLimit, tickets, totalTickets.add(ticketsRefunded)));
        ticketsRefunded += ticketsCountForRefund;

        uint refund = calculateRefundAmount(
          rule.refund, amount,
          ticketsCountForRefund,
          ticketCount
        );

        if (refund > 0) {player.transfer(refund);}
      }
    }
  }

  function calculateRefundAmount (uint refund, uint amount, uint ticketsForRefund, uint ticketCount) public constant returns (uint) {
    return amount.mul(ticketsForRefund).mul(refund).div(ticketCount).div(100);
  }

  function ticketsForRefund (uint ticketsLimit, uint ticketCount, uint totalTickets) public constant returns (uint) {
    uint ticketsForRefund = 0;

    if (totalTickets.add(ticketCount) > ticketsLimit) {
      ticketsForRefund = ticketsLimit.sub(totalTickets);
    } else {
      ticketsForRefund = ticketCount;
    }

    return ticketsForRefund;
  }

  function isStarted () public constant returns (bool) {
    return now >= startTime;
  }

  function isEnded () public constant returns (bool) {
    return now >= endTime;
  }

  modifier isActive () {
    require(isStarted() && !isEnded());
    _;
  }

  modifier isNotEnded () {
    require(!isEnded());
    _;
  }
}
