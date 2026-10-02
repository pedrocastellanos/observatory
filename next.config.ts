import type { NextConfig } from "next";

const nextConfig: NextConfig = {
	/* config options here */
	reactCompiler: true,
	output: "standalone",
	async rewrites() {
		return [
			{
				source: "/api/:path*",
				destination: `${process.env.NEXT_PUBLIC_API_URL}/api/:path*/`,
			},
		];
	},
	images: {
		domains: ["lh3.googleusercontent.com"],
	},
};

export default nextConfig;
