/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      // Supabase Storage, for progress photos and program cover art.
      { protocol: 'https', hostname: 'hxpsbhhkemccmmrukhji.supabase.co' },
    ],
  },
};
export default nextConfig;
