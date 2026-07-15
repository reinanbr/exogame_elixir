# ============================================================
# Stage 1 – Dependencies
# ============================================================
FROM node:22-alpine AS deps

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci

# ============================================================
# Stage 2 – Builder
# ============================================================
FROM node:22-alpine AS builder

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# public/ is gitignored (currently empty) so it may not exist on a fresh
# checkout — guarantee it's there for the runner stage's COPY below.
RUN mkdir -p public

ENV NEXT_TELEMETRY_DISABLED=1

# NEXT_PUBLIC_* vars are inlined into the client bundle at build time, so
# they must be present here, not just at container runtime.
ARG NEXT_PUBLIC_PHOENIX_URL
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_PHOENIX_URL=${NEXT_PUBLIC_PHOENIX_URL}
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

RUN npm run build

# ============================================================
# Stage 3 – Runner
# ============================================================
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser  --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

# Docker auto-injects HOSTNAME=<container id> into every container, and
# Next.js's standalone server.js does `process.env.HOSTNAME || '0.0.0.0'` —
# without this override it silently binds only to the container's internal
# bridge IP instead of all interfaces, refusing connections on 127.0.0.1.
ENV PORT=3000 \
    HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
