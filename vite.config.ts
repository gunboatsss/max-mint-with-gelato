import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { vitePluginEvmts } from '@evmts/vite-plugin';

export default defineConfig({
	plugins: [sveltekit(), vitePluginEvmts()]
});
