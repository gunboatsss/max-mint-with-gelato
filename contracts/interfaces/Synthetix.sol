pragma solidity ^0.8.20;

interface Synthetix {
    function remainingIssuableSynths(address issuer)
        external
        view
        returns (uint256 maxIssuable, uint256 alreadyIssued, uint256 totalSystemDebt);

    function collateralisationRatio(address issuer) external view returns (uint256);

    function issueMaxSynthsOnBehalf(address issueForAddress) external;

    function burnSynthsToTargetOnBehalf(address burnForAddress) external;
    function burnSynthsToTarget() external;
    function burnSynths(uint256 amount) external;
    function burnSynthsOnBehalf(address burnForAddress, uint256 amount) external;
}
