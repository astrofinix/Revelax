import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  optimizeDeps: {
    include: ['@supabase/supabase-js'],
  },
  resolve: {
    alias: {
      '@supabase/supabase-js': '@supabase/supabase-js/dist/module'
    }
  }
});