// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.20;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {MaxMint} from "../contracts/MaxMint.sol";

contract MaxMintOPTest is Test {
    string OP_MAINNET_RPC = vm.envString("OP_MAINNET_RPC");
    MaxMint mm;

    function setUp() public {
        vm.createSelectFork(OP_MAINNET_RPC);
        mm = new MaxMint(0x1Cb059b7e74fD21665968C908806143E744D5F30);
    }

    function test_Config() public {
        mm.setConfig(
            MaxMint.Configuation({
                mode: 1,
                minimumCRatio: 0.00196078431e18, // 510%
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
}
