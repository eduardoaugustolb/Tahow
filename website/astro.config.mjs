import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
export default defineConfig({
  site: 'https://eduardoaugustolb.github.io',
  base: '/Tahow',
  trailingSlash: 'always',
  integrations: [mdx()],
});
