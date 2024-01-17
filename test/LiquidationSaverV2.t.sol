pragma solidity >=0.8.20;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {LiquidationSaverV2} from "../contracts/V2/LiquidationSaverV2.sol";
import {ERC20} from "../contracts/interfaces/ERC20.sol";
import {OpsProxyFactory} from "../contracts/interfaces/OpsProxyFactory.sol";
import {OpsProxy} from "../contracts/interfaces/OpsProxy.sol";
import {Synthetix} from "../contracts/interfaces/Synthetix.sol";
import {Issuer} from "../contracts/interfaces/Issuer.sol";
import {DelegateApprovals} from "../contracts/interfaces/DelegateApprovals.sol";

contract LiquidationSaverV2Test is Test {
    using stdStorage for StdStorage;

    LiquidationSaverV2 maintainer;
    string OP_MAINNET_RPC = vm.envString("OP_MAINNET_RPC");
    address target = 0xd7BBeEA70aa555476D4e9bEF553fC137Cc20EcF6;
    OpsProxyFactory ops = OpsProxyFactory(0x44bde1bccdD06119262f1fE441FBe7341EaaC185);
    Synthetix SNX = Synthetix(0xfF5c26abD36078C768C40847672202eC343AC5ad);
    DelegateApprovals delegate = DelegateApprovals(0x15fd6e554874B9e70F832Ed37f231Ac5E142362f);
    Issuer issuer = Issuer(0xEb66Fc1BFdF3284Cb0CA1dE57149dcf3cEFa5453);
    function setUp() public {
        vm.createSelectFork(OP_MAINNET_RPC, 114556536);
        maintainer = new LiquidationSaverV2(
            0x1Cb059b7e74fD21665968C908806143E744D5F30,
            0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0
        );
    }

    function test_print() public {
        console2.log("cratio ", SNX.collateralisationRatio(target));
        console2.log("collateral ", issuer.collateral(target));
        vm.prank(target);
        SNX.burnSynths(1803698669018410662352);
        console2.log("cratio ", SNX.collateralisationRatio(target));
    }

    function test_happy_path() public {
        (address dedicatedMsgSender, bool deployed) = ops.getProxyOf(target);
        vm.prank(target);
        delegate.approveBurnOnBehalf(dedicatedMsgSender);
        if (!deployed) {
            ops.deployFor(target);
        }
        
        
        console2.log(target);
        
        //vm.startPrank(OpsProxy(dedicatedMsgSender).owner());
        (bool ready, bytes memory execPayload) = maintainer.checker(target);
        console2.logBytes(execPayload);
        assertTrue(ready, "can't burn and claim");
    }
}