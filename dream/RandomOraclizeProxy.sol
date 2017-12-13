pragma solidity 0.4.18;

import '../ethereum-api/oraclizeAPI_0.4.sol';
import './RandomOraclizeProxyI.sol';

contract RandomOraclizeProxy is usingOraclize, RandomOraclizeProxyI {
    string constant RANDOM_DS = "random";
    mapping(bytes32 => function (bytes32) external) private callbacks;
    
    function RandomOraclizeProxy(uint _gasPrice) {
        oraclize_setProof(proofType_Ledger);
        oraclize_setCustomGasPrice(_gasPrice);
    }

    function requestRandom(function (bytes32) external callback, uint _gasLimit) public payable {
        uint price = getRandomPrice(_gasLimit);
        require(price == msg.value);
        bytes32 queryId = oraclize_newRandomDSQuery(0, 32, _gasLimit);
        callbacks[queryId] = callback;
    }

    function __callback(bytes32 _queryId, string _result, bytes _proof) public {
        require(msg.sender == oraclize_cbAddress());
        require(oraclize_randomDS_proofVerify__returnCode(_queryId, _result, _proof) == 0);
        bytes32 result;
        //check len
        assembly {
            result := mload(add(_result, 32))
        }
        callbacks[_queryId](result);
        delete callbacks[_queryId];
    }

    function getRandomPrice(uint _gasLimit) public constant returns (uint) {
        return oraclize_getPrice(RANDOM_DS, _gasLimit);
    }


}
