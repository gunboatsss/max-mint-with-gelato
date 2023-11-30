// SPDX-License-Identifier: UNLICENSED
// Modified from https://github.com/gelatodigital/w3f-solidity-synthetix

pragma solidity >=0.8.20;

import {AddressResolver} from "../interfaces/AddressResolver.sol";
import {DelegateApprovals} from "../interfaces/DelegateApprovals.sol";
import {OpsProxyFactory} from "../interfaces/OpsProxyFactory.sol";
import {IAutomate, IProxyModule, Module} from "../interfaces/Gelato.sol";
import {Synthetix} from "../interfaces/Synthetix.sol";
import {SystemSettings} from "../interfaces/SystemSettings.sol";

contract MaxMintV2 {
    // @notice Configuration for minting
    // @custom:mode 0 for disabled, 1 for price increase, 2 for using minimum issued sUSD
    // @custom:parameter parameter to use for calculation, depending on mode selected
    // @custom:maxBaseFee maximum block.basefee to not mint
    enum Mode {DISABLED, BY_PRICE_INCRASE_PERCENT, BY_MINIMUM_SUSD_ISSUED }
    
    struct Configuation {
        Mode mode;
        uint120 parameter;
        uint120 maxBaseFee;
    }

    // @notice: Name of Synthetix contracts to resolve

    bytes32 private constant SYNTHETIX = "Synthetix";
    bytes32 private constant DELEGATE_APPROVALS = "DelegateApprovals";
    bytes32 private constant SYSTEM_SETTINGS = "SystemSettings";

    AddressResolver immutable SNXAddressResolver;
    OpsProxyFactory immutable OPS_PROXY_FACTORY ;
    DelegateApprovals private delegateApprovals;
    Synthetix private SNX;
    SystemSettings private systemSettings;

    mapping(address _account => Configuation) public config;

    error ZeroAddressResolved(bytes32 name);
    error InvalidConfig();

    constructor(address _SNXAddressResolver, address _automate) {
        SNXAddressResolver = AddressResolver(_SNXAddressResolver);
        _rebuildCaches();
        IAutomate automate = IAutomate(_automate);
        IProxyModule proxyModule = IProxyModule(automate.taskModuleAddresses(Module.PROXY));
        OPS_PROXY_FACTORY = OpsProxyFactory(proxyModule.opsProxyFactory());
    }

    function checker(
        address _account
    ) external view returns (bool, bytes memory execPayload) {
        (address dedicatedMsgSender, ) = OPS_PROXY_FACTORY.getProxyOf(_account);

        uint256 cRatio = SNX.collateralisationRatio(_account);
        uint256 issuanceRatio = systemSettings.issuanceRatio();
        Configuation memory currentConfig = config[_account];

        if (currentConfig.mode == Mode.DISABLED) {
            execPayload = bytes("Disabled");
            return (false, execPayload);
        }

        if (block.basefee > currentConfig.maxBaseFee && currentConfig.maxBaseFee > 0) {
            execPayload = bytes("Base fee too high");
            return (false, execPayload);
        }

        else if (currentConfig.mode == Mode.BY_PRICE_INCRASE_PERCENT) {
            uint256 targetCRatio = issuanceRatio * 10000 / (10000 + currentConfig.parameter);
            if(cRatio >= targetCRatio) {
                execPayload = bytes("Account C-ratio is lower than target");
                return (false, execPayload);
            }
        }
        else if (currentConfig.mode == Mode.BY_MINIMUM_SUSD_ISSUED) {
            (uint256 maxIssuable,, ) = SNX.remainingIssuableSynths(_account);
            if(maxIssuable == 0) {
                execPayload = bytes("Account already below max issuable");
                return (false, execPayload);
            }
            else if(currentConfig.parameter > maxIssuable) {
                execPayload = bytes("sUSD avaliable is lower than set threshold");
                return (false, execPayload);
            }
        }

        if (!delegateApprovals.canIssueFor(_account, dedicatedMsgSender)) {
            execPayload = bytes("Not approved for issuing");
            return (false, execPayload);
        }

        execPayload = abi.encodeWithSelector(
            SNX.issueMaxSynthsOnBehalf.selector,
            _account
        );

        return (true, execPayload);
    }

    function setConfig(Mode _mode, uint120 _parameter, uint120 _maxBaseFee) external {
        config[msg.sender] = Configuation({
            mode: _mode,
            parameter: _parameter,
            maxBaseFee: _maxBaseFee
        });
    }

    function rebuildCaches() external {
        _rebuildCaches();
    }

    function _rebuildCaches() internal {
        SNX = Synthetix(getAddress(SYNTHETIX));
        delegateApprovals = DelegateApprovals(getAddress(DELEGATE_APPROVALS));
        systemSettings = SystemSettings(getAddress(SYSTEM_SETTINGS));
    }

    function getAddress(bytes32 name) internal view returns (address) {
        address resolved = SNXAddressResolver.getAddress(name);
        if (resolved == address(0)) {
            revert ZeroAddressResolved(name);
        }
        return resolved;
    }
}
