pragma solidity ^0.8.20;

interface SystemSettings {
    function issuanceRatio() external view returns (uint256);

    function targetThreshold() external view returns (uint256);

    function liquidationRatio() external view returns (uint256);
}
