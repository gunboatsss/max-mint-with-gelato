// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20;

import {ERC20} from "../interfaces/ERC20.sol";

// Gelato Dependency
import {OpsProxy} from "../interfaces/OpsProxy.sol";
import {OpsProxyFactory} from "../interfaces/OpsProxyFactory.sol";
import {IAutomate, IProxyModule, Module} from "../interfaces/Gelato.sol";
// Synthetix Dependency
import {AddressResolver} from "../interfaces/AddressResolver.sol";
import {DelegateApprovals} from "../interfaces/DelegateApprovals.sol";
import {ExchangeRates} from "../interfaces/ExchangeRates.sol";
import {FeePool} from "../interfaces/FeePool.sol";
import {Issuer} from "../interfaces/Issuer.sol";
import {Synthetix} from "../interfaces/Synthetix.sol";
import {SystemSettings} from "../interfaces/SystemSettings.sol";

contract LiquidationSaverV2 {
    bytes32 private constant DELEGATE_APPROVALS = "DelegateApprovals";
    bytes32 private constant SYSTEM_SETTINGS = "SystemSettings";
    bytes32 private constant EXCHANGE_RATES = "ExchangeRates";
    bytes32 private constant FEE_POOL = "FeePool";
    bytes32 private constant ISSUER = "Issuer";
    bytes32 private constant SUSD_PROXY = "ProxyERC20sUSD";
    bytes32 private constant SYNTHETIX = "Synthetix";
    bytes32 private constant SNX_TICKER = "SNX";

    AddressResolver immutable SNXAddressResolver;
    OpsProxyFactory immutable OPS_PROXY_FACTORY;
    DelegateApprovals private delegateApprovals;
    ExchangeRates private exchangeRates;
    FeePool private feePool;
    Issuer private issuer;
    ERC20 private sUSD;
    SystemSettings private systemSettings;
    address private SNX;

    struct Configuration {
        uint80 triggerCRatio;
        uint80 targetCRatio;
        uint80 baseFee;
    }

    mapping(address => Configuration) public config;

    error ZeroAddressResolved(bytes32 name);

    constructor(address _SNXAddressResolver, address _automate) {
        SNXAddressResolver = AddressResolver(_SNXAddressResolver);
        _rebuildCaches();
        IAutomate automate = IAutomate(_automate);
        IProxyModule proxyModule = IProxyModule(automate.taskModuleAddresses(Module.PROXY));
        OPS_PROXY_FACTORY = OpsProxyFactory(proxyModule.opsProxyFactory());
    }

    function checker(address _account) external view returns (bool, bytes memory execPayload) {
        (address dedicatedMsgSender,) = OPS_PROXY_FACTORY.getProxyOf(_account);

        // first off, check gas price
        uint256 _gasPrice = config[_account].baseFee;
        if (_gasPrice != 0 && block.basefee > _gasPrice) {
            return (false, "basefee too high");
        }
        if (!delegateApprovals.canBurnFor(_account, dedicatedMsgSender)) {
            return (false, "no burn permission");
        }
        uint256 cRatio = issuer.collateralisationRatio(_account);
        uint256 liquidationRatio = systemSettings.liquidationRatio();
        // Liquidation case, need to return to issuance to unflag
        uint256 triggerCRatio = config[_account].triggerCRatio;

        if (cRatio > liquidationRatio) {
            uint256 debtBalance = issuer.debtBalanceOf(_account, "sUSD");
            uint256 maxIssuable = issuer.maxIssuableSynths(_account);
            uint256 burnAmount = debtBalance - maxIssuable;
            uint256 sUSDBalance = sUSD.balanceOf(_account);
            if (sUSDBalance < burnAmount) {
                return (false, "not enough sUSD to fix c-ratio");
            }
            else {
                return
                    (
                        true,
                        abi.encodeWithSelector(Synthetix.burnSynthsToTargetOnBehalf.selector, _account)
                    );
            }
        }
        else if(cRatio <= triggerCRatio) {
            return (false, "no need to fix c-ratio");
        }
        else if(!issuer.canBurnSynths(_account)) {
            return (false, "burn cooldown");
        }
        unchecked {
            uint256 debtUnscaled = cRatio - config[_account].targetCRatio;
            (uint256 snxRate, ) = exchangeRates.rateAndInvalid(SNX_TICKER);
            uint256 collateral = issuer.collateral(_account);
            uint256 snxInUsd = collateral * snxRate / 1e18;
            uint256 debt = debtUnscaled * snxInUsd;
            uint256 sUSDBalance = sUSD.balanceOf(_account);
            if(sUSDBalance < debt) {
                return (false, "not enough sUSD to fix c-ratio");
            }
            else {
                return
                (
                    true,
                    abi.encodeWithSelector(
                        Synthetix.burnSynthsOnBehalf.selector,
                        _account,
                        debt
                    )
                );
            }
        }
    }

    function setConfig(uint80 _triggerCRatio, uint80 _targetCRatio, uint80 _baseFee) external {
        require(_triggerCRatio > _targetCRatio, "invalid config");
        config[msg.sender] = Configuration({
            triggerCRatio: _triggerCRatio,
            targetCRatio: _targetCRatio,
            baseFee: _baseFee
        });
    }

    function rebuildCaches() external {
        _rebuildCaches();
    }

    function _rebuildCaches() internal {
        feePool = FeePool(getAddress(FEE_POOL));
        delegateApprovals = DelegateApprovals(getAddress(DELEGATE_APPROVALS));
        systemSettings = SystemSettings(getAddress(SYSTEM_SETTINGS));
        issuer = Issuer(getAddress(ISSUER));
        SNX = getAddress(SYNTHETIX);
        sUSD = ERC20(getAddress(SUSD_PROXY));
        exchangeRates = ExchangeRates(getAddress(EXCHANGE_RATES));
    }

    function getAddress(bytes32 name) internal view returns (address) {
        address resolved = SNXAddressResolver.getAddress(name);
        if (resolved == address(0)) {
            revert ZeroAddressResolved(name);
        }
        return resolved;
    }
}
