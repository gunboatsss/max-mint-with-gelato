// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {MaxMint} from "../contracts/MaxMint.sol";
import {OpsProxyFactory} from "../contracts/interfaces/OpsProxyFactory.sol";
import {Synthetix} from "../contracts/interfaces/Synthetix.sol";
import {DelegateApprovals} from "../contracts/interfaces/DelegateApprovals.sol";

contract MaxMintETHTest is Test {
    MaxMint mm;
    string ETH_MAINNET_RPC = vm.envString("ETH_MAINNET_RPC");
    address minter = 0x103f1A97147B2345ba1Dee9852f4991754425801;
    OpsProxyFactory ops = OpsProxyFactory(0xC815dB16D4be6ddf2685C201937905aBf338F5D7);
    Synthetix SNX = Synthetix(0xd0dA9cBeA9C3852C5d63A95F9ABCC4f6eA0F9032);
    DelegateApprovals delegate = DelegateApprovals(0x15fd6e554874B9e70F832Ed37f231Ac5E142362f);

    function setUp() public {
        vm.createSelectFork(ETH_MAINNET_RPC, 18423675);
        mm = new MaxMint(0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2);
    }

    function test_Config() public {
        mm.setConfig(
            MaxMint.Configuation({
                mode: 1,
                minimumCRatio: 0.19607843137e18, // 510%
                minimumIssuedsUSD: 0
            })
        );
    }

    function test_InvalidConfig() public {
        vm.expectRevert();
        mm.setConfig(MaxMint.Configuation({mode: 3, minimumCRatio: 0, minimumIssuedsUSD: 0}));
        vm.expectRevert();
        mm.setConfig(MaxMint.Configuation(uint8(8), uint120(0), uint120(0)));
    }

    function test_NotAllowToMint() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertEq(result, bytes("Disabled"));
        assertFalse(shouldCall);
        vm.prank(minter);
        mm.setConfig(MaxMint.Configuation({mode: 2, minimumCRatio: 0, minimumIssuedsUSD: 100e18}));
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
            MaxMint.Configuation({
                mode: 2,
                minimumCRatio: 0, // 510%
                minimumIssuedsUSD: 100e18
            })
        );
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertTrue(shouldCall);
        assertEq(result, abi.encodeWithSelector(SNX.issueMaxSynthsOnBehalf.selector, minter));
        vm.stopPrank();
        vm.prank(dedicatedMsgSender);
        SNX.issueMaxSynthsOnBehalf(minter);
    }

    function test_MinimumSusdNotReach() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        vm.startPrank(minter);
        mm.setConfig(
            MaxMint.Configuation({
                mode: 2,
                minimumCRatio: 0, // 510%
                minimumIssuedsUSD: 100000e18
            })
        );
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertFalse(shouldCall);
        assertEq(result, bytes("sUSD avaliable is lower than set threshold"));
    }

    function test_MintByCRatio() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        vm.startPrank(minter);
        console2.log("c-ratio ", SNX.collateralisationRatio(minter));
        mm.setConfig(
            MaxMint.Configuation({
                mode: 1,
                minimumCRatio: 0.19607843137e18, // 510%
                minimumIssuedsUSD: 0
            })
        );
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertTrue(shouldCall);
        assertEq(result, abi.encodeWithSelector(SNX.issueMaxSynthsOnBehalf.selector, minter));
        vm.stopPrank();
        vm.prank(dedicatedMsgSender);
        SNX.issueMaxSynthsOnBehalf(minter);
    }

    function test_CRatioNotReached() public {
        (address dedicatedMsgSender,) = ops.getProxyOf(minter);
        vm.startPrank(minter);
        console2.log("c-ratio ", SNX.collateralisationRatio(minter));
        mm.setConfig(
            MaxMint.Configuation({
                mode: 1,
                minimumCRatio: 0.16666666666e18, // 600%
                minimumIssuedsUSD: 0
            })
        );
        delegate.approveIssueOnBehalf(dedicatedMsgSender);
        (bool shouldCall, bytes memory result) = mm.checker(minter);
        assertFalse(shouldCall);
        assertEq(result, bytes("C-Ratio is lower than set threshold"));
    }
}
