// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {MaxMintV2} from "../contracts/V2/MaxMintV2.sol";
import {OpsProxyFactory} from "../contracts/interfaces/OpsProxyFactory.sol";
import {Synthetix} from "../contracts/interfaces/Synthetix.sol";
import {DelegateApprovals} from "../contracts/interfaces/DelegateApprovals.sol";

contract MaxMintV2ETHTest is Test {
    MaxMintV2 mm;
    string ETH_MAINNET_RPC = vm.envString("ETH_MAINNET_RPC");
    address minter = 0x103f1A97147B2345ba1Dee9852f4991754425801;
    OpsProxyFactory ops = OpsProxyFactory(0x44bde1bccdD06119262f1fE441FBe7341EaaC185);
    Synthetix SNX = Synthetix(0xd0dA9cBeA9C3852C5d63A95F9ABCC4f6eA0F9032);
    DelegateApprovals delegate = DelegateApprovals(0x15fd6e554874B9e70F832Ed37f231Ac5E142362f);

    function setUp() public {
        vm.createSelectFork(ETH_MAINNET_RPC, 18423675);
        mm = new MaxMintV2(0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2, 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    }

    function test_Config() public {
        mm.setConfig({
                _mode: MaxMintV2.Mode.BY_MINIMUM_SUSD_ISSUED,
                _parameter: 1e18,
                _maxBaseFee: 0
            });
    }
    function test_InvalidConfig() public {
        (bool succ,) = address(mm).call(
            abi.encodeWithSelector(
                MaxMintV2.setConfig.selector, 
                3,
                0,
                0
        ));
        assertFalse(succ);
    }
    function test_NotAllowToMint() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertEq(result, bytes("Disabled"));
        assertFalse(shouldCall);
        vm.prank(minter);
        mm.setConfig(
            MaxMintV2.Mode.BY_MINIMUM_SUSD_ISSUED,
            100e18,
            0
        );
        //(uint256 maxIssuable, uint256 alreadyIssued,) = SNX.remainingIssuableSynths(minter);
        //console2.log("maxissue: ", maxIssuable, "alreadyissued", alreadyIssued);
        console2.log("can issue for ", delegate.canIssueFor(minter, dedicatedMsgSender));
        (shouldCall, result) = mm.checker(minter);
        assertEq(result, bytes("Not approved for issuing"));
        assertFalse(shouldCall);
    }
    function test_MintByMinimumSusd() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        vm.startPrank(minter);
        mm.setConfig(
            MaxMintV2.Mode.BY_MINIMUM_SUSD_ISSUED,
            100e18,
            0
        );
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertTrue(shouldCall);
        assertEq(
            result,
            abi.encodeWithSelector(SNX.issueMaxSynthsOnBehalf.selector, minter)
        );
        vm.stopPrank();
        vm.prank(dedicatedMsgSender);
        (bool succ, ) = address(SNX).call(result);
        assertTrue(succ);
    }
    function test_MinimumSusdNotReach() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        vm.startPrank(minter);
        mm.setConfig(
            MaxMintV2.Mode.BY_MINIMUM_SUSD_ISSUED,
            10000e18,
            0
        );
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertFalse(shouldCall);
        assertEq(
            result,
            bytes("sUSD avaliable is lower than set threshold")
        );
    }
    function test_MintByPriceIncrease() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        vm.startPrank(minter);
        console2.log("c-ratio ", SNX.collateralisationRatio(minter));
        mm.setConfig(
            MaxMintV2.Mode.BY_PRICE_INCRASE_PERCENT,
            200,
            0
        );
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertTrue(shouldCall);
        assertEq(
            result,
            abi.encodeWithSelector(SNX.issueMaxSynthsOnBehalf.selector, minter)
        );
        vm.stopPrank();
        vm.prank(dedicatedMsgSender);
        (bool succ, ) = address(SNX).call(result);
        assertTrue(succ);
    }
    function test_CRatioNotReached() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        vm.startPrank(minter);
        console2.log("c-ratio ", SNX.collateralisationRatio(minter));
        mm.setConfig(
            MaxMintV2.Mode.BY_PRICE_INCRASE_PERCENT,
            2000,
            0
        );
        console2.log(uint256(0.2e18) * 10000 / (10000 + 2000));
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertFalse(shouldCall);
        assertEq(
            result,
            bytes("Account C-ratio is lower than target")
        );
    }
    function test_baseFeeTooHigh() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        vm.startPrank(minter);
        console2.log("c-ratio ", SNX.collateralisationRatio(minter));
        mm.setConfig(
            MaxMintV2.Mode.BY_PRICE_INCRASE_PERCENT,
            2000,
            99 gwei
        );
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        vm.fee(100 gwei);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertFalse(shouldCall);
        assertEq(
            result,
            "Base fee too high"
        );
    }
}
