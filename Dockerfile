# syntax=docker/dockerfile:1

FROM node:20-alpine AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS deps

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

FROM base AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
# next.config.ts must be evaluated during the build. The production value is
# injected at container startup by Dokploy and is not baked into this image.
ENV NEXT_PUBLIC_API_URL=http://127.0.0.1:4000
RUN pnpm build

FROM node:20-alpine AS runner

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

WORKDIR /app

RUN addgroup --system --gid 1001 nodejs \
	&& adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

CMD ["sh", "-c", "node -e 'const fs=require(\"fs\");const path=\".next/routes-manifest.json\";const value=process.env.NEXT_PUBLIC_API_URL;if(!/^https?:\\/\\//.test(value||\"\")){console.error(\"NEXT_PUBLIC_API_URL must be an absolute URL provided by the deployment environment\");process.exit(1)}const manifest=JSON.parse(fs.readFileSync(path,\"utf8\"));const apiUrl=value.replace(/\\/api\\/?$/,\"\").replace(/\\/$/,\"\");for(const rewrite of manifest.rewrites.afterFiles){rewrite.destination=rewrite.destination.replace(\"http://127.0.0.1:4000\",apiUrl)}fs.writeFileSync(path,JSON.stringify(manifest));' && exec node server.js"]
