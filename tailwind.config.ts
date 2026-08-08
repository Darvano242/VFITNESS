import type { Config } from 'tailwindcss';

/**
 * Every value here comes from docs/BRAND.md. That file is the source of
 * truth. Do not add a colour or typeface that is not in it.
 */
const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        vf: {
          bg: '#08090a',
          bg2: '#0c0e10',
          text: '#f5f6f7',
          dim: '#9aa0a6',
          mute: '#6b7177',
          primary: '#3d7dff',
          'primary-2': '#6f5bff',
          accent: '#2dd4bf',
          green: '#22c55e',
          gold: '#f59e0b',
          red: '#f43f5e',
        },
        // Translucent overlays. The dark-glass look depends on these being
        // alpha rather than opaque, so panels pick up the aurora behind them.
        surface: 'rgba(255,255,255,0.035)',
        'surface-hi': 'rgba(255,255,255,0.06)',
        edge: 'rgba(255,255,255,0.08)',
        'edge-hi': 'rgba(255,255,255,0.14)',
      },
      fontFamily: {
        sans: ['var(--font-geist)', 'system-ui', 'sans-serif'],
        mono: ['var(--font-geist-mono)', 'ui-monospace', 'monospace'],
      },
      backgroundImage: {
        'vf-grad': 'linear-gradient(120deg, #3d7dff, #6f5bff)',
        'vf-teal': 'linear-gradient(120deg, #2dd4bf, #3d7dff)',
      },
      borderRadius: { vf: '14px' },
      transitionTimingFunction: { vf: 'cubic-bezier(.22,.68,.28,1)' },
    },
  },
  plugins: [],
};

export default config;
