pragma solidity 0.4.18;

import './utils/Restriction.sol';
import './CompanyInterface.sol';

contract CompaniesManager is Restriction {
  CompanyInterface[] public companies;

  function addNewCompany (address _company) public restricted {
    companies.push(CompanyInterface(_company));
  }

  function processing (address player, uint amount, uint ticketCount, uint totalTickets) public restricted {
    if (companies.length == 0) {return;}
    
    CompanyInterface company = currentCompany();

    if (currentCompanyIsActive()) {
      company.processing(player, amount, ticketCount, totalTickets);
    }
  }

  function currentCompany () internal constant returns (CompanyInterface) {
    return companies[companies.length - 1];
  }
  
  function currentCompanyIsActive () internal constant returns (bool) {
    return currentCompany().isActivated();
  }
}
