pragma solidity 0.4.18;


import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './../utils/Restriction.sol';
import './../DreamConstants.sol';


contract Fund is Restriction, DreamConstants {
    using SafeMath for uint256;

    mapping (address => uint) public balances;

    event Pay(address receiver, uint amount);
    event Refund(address receiver, uint amount);

    // how many funds are collected
    uint public totalAmount;
    // how many funds are payed as prize
    uint internal totalPrizeAmount;
    // absolute refund date
    uint32 internal refundDate;
    // user who will receive all funds
    address internal beneficiary;

    function Fund(uint _absoluteRefundDate, address _beneficiary) public {
        refundDate = uint32(_absoluteRefundDate);
        beneficiary = _beneficiary;
    }

    function deposit(address _addr) public payable restricted {
        uint balance = balances[_addr];

        balances[_addr] = balance.add(msg.value);
        totalAmount = totalAmount.add(msg.value);
    }

    function withdraw(uint amount) public restricted {
        beneficiary.transfer(amount);
    }

    /**
     * @dev Pay from fund to the specified address only if not payed already.
     * @param _addr Address to pay.
     * @param _amountWei Amount to pay.
     */
    function pay(address _addr, uint _amountWei) public restricted {
        // we have enough funds
        require(this.balance >= _amountWei);
        require(balances[_addr] != 0);
        delete balances[_addr];
        totalPrizeAmount = totalPrizeAmount.add(_amountWei);
        // send funds
        _addr.transfer(_amountWei);
        Pay(_addr, _amountWei);
    }

    /**
     * @dev If funds already payed to the specified address.
     * @param _addr Address to check.
     */
    function isPayed(address _addr) public constant returns (bool) {
        return balances[_addr] == 0;
    }

    function enableRefund() public restricted {
        require(refundDate > uint32(block.timestamp));
        refundDate = uint32(block.timestamp);
    }

    function refund(address _addr) public restricted {
        require(refundDate >= uint32(block.timestamp));
        require(balances[_addr] != 0);
        uint amount = refundAmount(_addr);
        delete balances[_addr];
        _addr.transfer(amount);
        Refund(_addr, amount);
    }

    function refundAmount(address _addr) public constant returns (uint) {
        uint balance = balances[_addr];
        uint restTotal = totalAmount.sub(totalPrizeAmount);
        uint share = balance.mul(ACCURACY).div(totalAmount);
        return restTotal.mul(share).div(ACCURACY);
    }
}
