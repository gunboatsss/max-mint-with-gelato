<script>
import "../app.postcss";
import {createPublicClient, createWalletClient} from "viem";
import { MaxMint } from '../../contracts/MaxMint.sol';
import { getContractFromEvmts } from '@evmts/viem';

const MaxMintInstance = getContractFromEvmts(MaxMint);

</script>
<nav class="navbar bg-base-100">
    <span class="text-xl flex-1 ml-1 truncate">Auto Minting Utility for Synthetix V2x</span>
    <button class="btn flex-none bg-gradient-to-r from-green-500 to-blue-500 color text-black">Connect Wallet</button>
</nav>
<slot></slot>