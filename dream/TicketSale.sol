pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './utils/Restriction.sol';
import './DreamConstants.sol';
import './TicketHolder.sol';
import './storages/Fund.sol';
import './RandomOraclizeProxyI.sol';
import './integration/CompaniesManagerInterface.sol';

contract TicketSale is Restriction, DreamConstants {
    using SafeMath for uint256;
    uint constant RANDOM_GAS = 1000000;

    TicketHolder public ticketHolder;
    Fund public fund;
    RandomOraclizeProxyI private proxy;
    CompaniesManagerInterface public companiesManager;
    bytes32[] public randomNumbers;

    uint32 public endDate;

    function TicketSale(uint _endDate, address _proxy, address _beneficiary, uint _maxTickets) public {
        require(_endDate > block.timestamp);
        require(_beneficiary != 0);
        uint refundDate = block.timestamp + REFUND_AFTER;
        // end date mist be less then refund
        require(_endDate < refundDate);

        ticketHolder = new TicketHolder(_maxTickets);
        ticketHolder.giveAccess(msg.sender);

        fund = new Fund(refundDate, _beneficiary);
        fund.giveAccess(msg.sender);

        endDate = uint32(_endDate);
        proxy = RandomOraclizeProxyI(_proxy);
    }

    // fallback function used to buy tickets
    function() public payable {
        uint dreamWei = 0;
        if (msg.data.length != 0) {
            uint dreamEth = parseDream();
            dreamWei = dreamEth * 1 ether;
        }
        buyTicketsInternal(msg.sender, msg.value, dreamWei);
    }

    function buyTickets(uint _dreamAmount) public payable {
        buyTicketsInternal(msg.sender, msg.value, _dreamAmount);
    }

    function buyTicketsFor(address _addr, uint _dreamAmount) public payable {
        buyTicketsInternal(_addr, msg.value, _dreamAmount);
    }

    function buyTicketsInternal(address _addr, uint _valueWei, uint _dreamAmount) internal notEnded {
        require(_valueWei >= TICKET_PRICE);

        uint change = _valueWei % TICKET_PRICE;
        uint weiAmount = _valueWei - change;
        uint ticketCount = weiAmount.div(TICKET_PRICE);

        if (address(companiesManager) != 0) {
            uint totalTickets = ticketHolder.totalTickets();
            companiesManager.processing(_addr, weiAmount, ticketCount, totalTickets);
        }

        // issue right amount of tickets
        ticketHolder.issueTickets(_addr, ticketCount, _dreamAmount);

        // transfer to fund
        fund.deposit.value(weiAmount)(_addr);

        // return change
        if (change != 0) {
            msg.sender.transfer(change);
        }
    }

    // server integration methods

    function refund() public {
        fund.refund(msg.sender);
    }

    /**
     * @dev Send funds to player by index. In case server calculate all.
     * @param _playerIndex The winner player index.
     * @param _amountWei Amount of prize in wei.
     */
    function payout(uint _playerIndex, uint _amountWei) public restricted ended {
        address playerAddress;
        uint ticketAmount;
        uint dreamAmount;
        (playerAddress, ticketAmount, dreamAmount) = ticketHolder.getTickets(_playerIndex);
        require(playerAddress != 0);

        // pay the player's dream
        fund.pay(playerAddress, _amountWei);
    }

    /**
     * @dev If funds already payed to the specified player by index.
     * @param _playerIndex Player index.
     */
    function isPayed(uint _playerIndex) public constant returns (bool) {
        address playerAddress;
        uint ticketAmount;
        uint dreamAmount;
        (playerAddress, ticketAmount, dreamAmount) = ticketHolder.getTickets(_playerIndex);
        require(playerAddress != 0);
        return fund.isPayed(playerAddress);
    }

    /**
     * @dev Server method. Finish lottery (force finish if required), enable refund.
     */
    function finish() public restricted {
        // force end
        if (endDate > uint32(block.timestamp)) {
            endDate = uint32(block.timestamp);
        }
    }

    // random integration
    function requestRandom() public payable restricted {
        uint price = proxy.getRandomPrice(RANDOM_GAS);
        require(msg.value >= price);
        uint change = msg.value - price;
        proxy.requestRandom.value(price)(this.random_callback, RANDOM_GAS);
        if (change > 0) {
            msg.sender.transfer(change);
        }
    }

    function random_callback(bytes32 _randomNumbers) external {
        require(msg.sender == address(proxy));
        randomNumbers.push(_randomNumbers);
    }

    // companies integration
    function setCompanyManager(address _addr) public restricted {
        companiesManager = CompaniesManagerInterface(_addr);
    }

    // constant methods
    function isEnded() public constant returns (bool) {
        return block.timestamp > endDate;
    }

    function parseDream()   public constant returns (uint result) {
        for (uint i = 0; i < msg.data.length; i ++) {
            uint power = (msg.data.length - i - 1) * 2;
            uint b = uint(msg.data[i]);
            result += b / 16 * (10 ** (power + 1)) + b % 16 * (10 ** power);
        }
    }

    modifier notEnded() {
        require(!isEnded());
        _;
    }

    modifier ended() {
        require(isEnded());
        _;
    }

    function randomCount() public constant returns(uint) {
        return randomNumbers.length;
    }

    function getRandomPrice() public constant returns(uint) {
        return proxy.getRandomPrice(RANDOM_GAS);
    }

}
