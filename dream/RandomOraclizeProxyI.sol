pragma solidity 0.4.18;

contract RandomOraclizeProxyI {
    function requestRandom(function (bytes32) external callback, uint _gasLimit) public payable;
    function getRandomPrice(uint _gasLimit) public constant returns (uint);
}
