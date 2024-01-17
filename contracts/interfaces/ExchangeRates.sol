pragma solidity >=0.8.20;
interface ExchangeRates {function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);}