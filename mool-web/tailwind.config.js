/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        mool: {
          linen: '#F6F3EC',
          moss: {
            DEFAULT: '#5F7A5E',
            light: '#728F71',
            dark: '#4B624A',
            soft: '#EAF0E9',
          },
          dusk: {
            DEFAULT: '#2E4452',
            light: '#3C5668',
            dark: '#1F303B',
            soft: '#E7ECF0',
          },
          sandrose: {
            DEFAULT: '#C98B76',
            light: '#DDA28F',
            soft: '#F8EFEA',
          },
          ink: {
            DEFAULT: '#2B2B28',
            muted: '#595952',
            faint: '#8C8C83',
          },
          mist: {
            DEFAULT: '#E4E0D5',
            light: '#EFECE4',
            dark: '#D5CFBF',
          },
          signal: {
            DEFAULT: '#B3543F',
            soft: '#F9ECE9',
          },
        },
      },
      fontFamily: {
        serif: ['Fraunces', 'Georgia', 'serif'],
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
      borderRadius: {
        'organic': '1.25rem',
        'organic-lg': '1.75rem',
        'organic-sm': '0.75rem',
      },
      boxShadow: {
        'soft-ground': '0 4px 20px -2px rgba(43, 43, 40, 0.05), 0 2px 6px -1px rgba(43, 43, 40, 0.03)',
        'dusk-elevated': '0 10px 25px -5px rgba(46, 68, 82, 0.12), 0 4px 10px -2px rgba(46, 68, 82, 0.06)',
      },
    },
  },
  plugins: [],
}

