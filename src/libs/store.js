import { writable, readable } from "svelte/store";
import { createPublicClient, http } from 'viem';
import { optimism, mainnet } from 'viem/chains';
/** @type {import('svelte/store').Writable<import('viem').Address | null>} */
export const currentAddress = writable(null);
export const connected = writable(false);
export const opClient = readable(createPublicClient({
    chain: optimism,
    transport: http()
}));
export const ethClient = readable(createPublicClient({
    chain: mainnet,
    transport: http()
}));
export const walletClient = writable();
export const selectedChain = writable(10);