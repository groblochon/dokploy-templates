import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'
import tailwindcss from '@tailwindcss/vite'
import { viteStaticCopy } from 'vite-plugin-static-copy'
// https://vitejs.dev/config/
export default defineConfig({
	plugins: [react(), tailwindcss(),
	viteStaticCopy({
		targets: [
			{
				src: path.resolve(__dirname, '../blueprints/*').replace(/\\/g, '/'),
				dest: 'blueprints'
			},
			{
				src: path.resolve(__dirname, '../meta.json').replace(/\\/g, '/'),
				dest: ''
			}
		]
	})

	],
	server: {
		allowedHosts: true,
	},
	resolve: {
		alias: {
			'@': path.resolve(__dirname, './src'),
		},
	},
})
