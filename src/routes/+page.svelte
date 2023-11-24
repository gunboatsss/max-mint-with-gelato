<script lang="ts">
	import { formatEther, parseEther, type WalletClient } from 'viem';
	import { abi } from '../libs/MaxMint.json';
	import { connected, opClient, ethClient, selectedChain } from '../libs/store';
	import { currentAddress, walletClient } from '../libs/store';
	let options = [
		{
			id: 0,
			text: 'Disabled'
		},
		{
			id: 1,
			text: 'by C-Ratio'
		},
		{
			id: 2,
			text: 'by sUSD'
		}
	];
	let config = [0,0n,0n] ;
    let sUSD = 0;
    let cRatio = 500;
	connected.subscribe(
        (t) => {
            if(!t) return;
			($selectedChain == 10) ? $opClient
				.readContract({
					address: '0xaD2E8F76f5f7b4378fD49fE62b8C0960511cf734',
					abi,
					functionName: 'config',
					args: [$currentAddress]
				})
				.then((res) => {
                    console.log(res);
					config = res;
                    sUSD = Number(formatEther(config[2]));
                    if(config[1] === 0n) {
                        cRatio = 500;
                    }
                    
				}) : $ethClient.readContract({
					address: '0x509c4C872d2a8A82aD2C9Cbd09869697c7C6729b',
					abi,
					functionName: 'config',
					args: [$currentAddress]
				})
				.then((res) => {
                    console.log(res);
					config = res;
                    sUSD = Number(formatEther(config[2]));
                    if(config[1] === 0n) {
                        cRatio = 500;
                    }
				});
		});
    $: console.log(sUSD);
    $: console.log(config);
    $: console.log(cRatio);
    $: config[1] = parseEther((1/cRatio).toFixed(18));
    $: config[2] = (sUSD != null) ? parseEther(sUSD.toFixed(18)) : 0n;
    function setConfig() {
        $walletClient.writeContract({
			address: '0xaD2E8F76f5f7b4378fD49fE62b8C0960511cf734',
			abi,
			functionName: 'setConfig',
			args: [config],
			account: $currentAddress
		})
    }
</script>

<div class="m-4 flex">
		<div>
			<span>Mode:</span>
			<select disabled={$currentAddress == null} bind:value={config[0]}>
				{#each options as option}
					<option value={option.id}>{option.text}</option>
				{/each}
			</select>
            <div>
            <span>
                Maximum C-ratio threshold to mint:
            </span>
            <input disabled={config[0] != 1} type="range" class="range" min="500" max="1000" bind:value={cRatio}>
            <input disabled={config[0] != 1} type="number" readonly bind:value={cRatio} class="ghost">
            </div>
            <span>minimum sUSD to mint: </span><input disabled={config[0] != 2} bind:value={sUSD} min="0" type="number" placeholder="minimum sUSD threshold" class="input">
		</div>
        <button class="btn btn-primary" on:click={setConfig}>Set</button>
</div>
