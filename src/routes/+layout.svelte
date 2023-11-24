<script lang="ts">
	import '../app.postcss';
	import { createWalletClient, custom, type WalletClient } from 'viem';
    import { writable } from 'svelte/store';
	import { optimism, mainnet } from 'viem/chains';
    import { currentAddress, connected, walletClient, selectedChain } from '../libs/store';
    $: console.log($connected);
	async function connect() {
		walletClient.set(createWalletClient({ chain: ($selectedChain == 10) ? optimism : mainnet, transport: custom(window.ethereum) }));
        let addresses = await $walletClient.requestAddresses();
        currentAddress.set(addresses[0]);
        console.log($currentAddress);
        connected.set(true);
        console.log($walletClient.chain);
	}
    let chains = [
        {
            id: 1,
            name: 'Ethereum Mainnet'
        },
        {
            id: 10,
            name: 'OP Mainnet'
        }
    ]
    async function handleSwitchChain() {
        if($walletClient) {
            await $walletClient.swtichChain({id: $selectedChain});
        }
    }
</script>

<nav class="navbar bg-base-100">
	<span class="text-xl flex-1 ml-1 truncate">Auto Minting Utility for Synthetix V2x</span>
    <select bind:value={$selectedChain} on:change={handleSwitchChain} class="mr-4">
        {#each chains as chain}
            <option value={chain.id}>{chain.name}</option>
        {/each}
    </select>
    {#if !$connected}
	<button on:click="{() => {connect()}}" class="btn flex-none bg-gradient-to-r from-green-500 to-blue-500 color text-black"
		>Connect Wallet</button
	>
    {:else}
    <button class="btn flex-none">
        {$currentAddress}
    </button>
    {/if}
</nav>
<slot />
