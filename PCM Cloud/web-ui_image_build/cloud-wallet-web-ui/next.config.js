const path = require('path');

const createNextIntlPlugin = require('next-intl/plugin');
 
const withNextIntl = createNextIntlPlugin();

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false,
  output: 'standalone',
  sassOptions: {
    includePaths: [path.join(__dirname, 'styles')],
  },
  env: Object.fromEntries(
    Object.entries(process.env)
      .filter(([key]) => key.startsWith('NEXT_PUBLIC_'))
      .map(([key, value]) => [key.replace('NEXT_PUBLIC_', ''), value])
  ),
};

module.exports = withNextIntl(nextConfig);
