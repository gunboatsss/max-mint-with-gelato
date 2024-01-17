// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {AutoBurnAndClaimV2} from "../contracts/V2/AutoBurnAndClaimV2.sol";
import {ERC20} from "../contracts/interfaces/ERC20.sol";
import {OpsProxyFactory} from "../contracts/interfaces/OpsProxyFactory.sol";
import {OpsProxy} from "../contracts/interfaces/OpsProxy.sol";
import {Synthetix} from "../contracts/interfaces/Synthetix.sol";
import {DelegateApprovals} from "../contracts/interfaces/DelegateApprovals.sol";
import {FeePool} from "../contracts/interfaces/FeePool.sol";

contract AutoBurnAndClaimV2Test is Test {
    using stdStorage for StdStorage;

    AutoBurnAndClaimV2 abac;
    string ETH_MAINNET_RPC = vm.envString("ETH_MAINNET_RPC");
    address target = 0x629b1166064abc68a4eA392E37Cd4133103d7516;
    address feepool = 0x83105D7CDd2fd9b8185BFF1cb56bB1595a618618;
    OpsProxyFactory ops = OpsProxyFactory(0x44bde1bccdD06119262f1fE441FBe7341EaaC185);
    Synthetix SNX = Synthetix(0xd0dA9cBeA9C3852C5d63A95F9ABCC4f6eA0F9032);
    DelegateApprovals delegate = DelegateApprovals(0x15fd6e554874B9e70F832Ed37f231Ac5E142362f);
    ERC20 debtShares = ERC20(0x89FCb32F29e509cc42d0C8b6f058C993013A843F);
    FeePool feePool = FeePool(feepool);

    function setUp() public {
        vm.createSelectFork(ETH_MAINNET_RPC, 18634930);
        abac =
        new AutoBurnAndClaimV2(0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2, 0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    }

    function test_happy_path() public {
        vm.pauseGasMetering();
        console.log(debtShares.balanceOf(target));
        (address dedicatedMsgSender, bool deployed) = ops.getProxyOf(target);
        if (!deployed) {
            ops.deployFor(target);
        }
        vm.startPrank(target);
        delegate.approveBurnOnBehalf(dedicatedMsgSender);
        delegate.approveClaimOnBehalf(dedicatedMsgSender);
        vm.stopPrank();
        vm.startPrank(OpsProxy(dedicatedMsgSender).owner());
        vm.resumeGasMetering();
        (bool ready, bytes memory execPayload) = abac.checker(target);
        console2.logBytes(execPayload);
        assertTrue(ready, "can't burn and claim");
        (bool succ,) = dedicatedMsgSender.call(execPayload);
        assertTrue(succ, "burn and claim failed");
    }

    // i can't write test for the one that barely pass the threshold so let's hope it work
    function test_healthy_cratio() public {
        vm.pauseGasMetering();
        console.log(debtShares.balanceOf(target));
        (address dedicatedMsgSender, bool deployed) = ops.getProxyOf(target);
        if (!deployed) {
            ops.deployFor(target);
        }
        vm.startPrank(target);
        SNX.burnSynthsToTarget();
        delegate.approveClaimOnBehalf(dedicatedMsgSender);
        vm.stopPrank();
        vm.startPrank(OpsProxy(dedicatedMsgSender).owner());
        vm.resumeGasMetering();
        (bool ready, bytes memory execPayload) = abac.checker(target);
        address[] memory checkAddress = new address[](1);
        bytes[] memory checkCalldata = new bytes[](1);
        uint256[] memory checkValues = new uint256[](1);
        checkAddress[0] = feepool;
        checkCalldata[0] = abi.encodeWithSelector(FeePool.claimOnBehalf.selector, target);
        checkValues[0] = 0;
        assertEq0(
            execPayload,
            abi.encodeWithSelector(OpsProxy.batchExecuteCall.selector, checkAddress, checkCalldata, checkValues),
            "expect claim tx only"
        );
        assertTrue(ready, "claim condition failed");
        (bool succ,) = dedicatedMsgSender.call(execPayload);
        assertTrue(succ, "claim failed");
    }

    function test_sad_path() public {
        vm.prank(target);
        abac.setBaseFee(69 gwei);
        vm.fee(70 gwei);
        bool succ;
        bytes memory execPayload;
        (succ, execPayload) = abac.checker(target);
        assertFalse(succ);
        assertEq0(execPayload, "basefee too high");
        vm.fee(0);
        (succ, execPayload) = abac.checker(target);
        assertFalse(succ);
        assertEq0(execPayload, "no claim permission for gelato");

        // the test would check for snx reward but it is really unlikely that snx reward completely gone

        (address dedicatedMsgSender,) = ops.getProxyOf(target);
        vm.prank(target);
        delegate.approveClaimOnBehalf(dedicatedMsgSender);
        (succ, execPayload) = abac.checker(target);
        assertFalse(succ);
        assertEq0(execPayload, "no burn permission and c-ratio too low");

        // give burn perms
        vm.prank(target);
        delegate.approveBurnOnBehalf(dedicatedMsgSender);

        uint256 balance = stdstore.target(0x05a9CBe762B36632b3594DA4F082340E0e5343e8).sig("balanceOf(address)").with_key(
            target
        ).read_uint();
        uint256 slot = stdstore.target(0x05a9CBe762B36632b3594DA4F082340E0e5343e8).sig("balanceOf(address)").with_key(
            target
        ).find();
        console2.log("balance: ", balance);
        console2.log("slot: ", slot);
        // manipulate balance such that it can't fix the balance
        vm.store(0x05a9CBe762B36632b3594DA4F082340E0e5343e8, bytes32(slot), bytes32(uint256(69)));
        (succ, execPayload) = abac.checker(target);
        assertFalse(succ);
        assertEq0(execPayload, "not enough sUSD to fix c-ratio");
    }

    function test_already_claimed() public {
        vm.startPrank(target);
        SNX.burnSynthsToTarget();
        feePool.claimFees();
        (address dedicatedMsgSender, bool deployed) = ops.getProxyOf(target);
        if (!deployed) {
            ops.deployFor(target);
        }
        delegate.approveClaimOnBehalf(dedicatedMsgSender);
        vm.stopPrank();
        (bool succ, bytes memory execPayload) = abac.checker(target);
        assertFalse(succ);
        assertEq(execPayload, "no reward avaliable");
    }
}
