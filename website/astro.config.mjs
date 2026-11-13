import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
export default defineConfig({
  site: 'https://tahow.eduardoaugusto.work',
  trailingSlash: 'always',
  integrations: [mdx()],
});
