#!/usr/bin/env bash
# Universal build script for nuxt-dx-tools-lsp
# Auto-detects package manager and builds the LSP server

set -e

cd "$(dirname "$0")"

echo "🔍 Detecting package manager..."

# Detect package manager
PM=""

if [ -f "pnpm-lock.yaml" ]; then
    PM="pnpm"
elif [ -f "yarn.lock" ]; then
    PM="yarn"
elif [ -f "bun.lockb" ]; then
    PM="bun"
elif [ -f "package-lock.json" ]; then
    PM="npm"
else
    # No lockfile, check which is available
    if command -v pnpm &> /dev/null; then
        PM="pnpm"
    elif command -v yarn &> /dev/null; then
        PM="yarn"
    elif command -v bun &> /dev/null; then
        PM="bun"
    else
        PM="npm"
    fi
fi

echo "📦 Using package manager: $PM"
echo

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📥 Installing dependencies with $PM..."
    case $PM in
        pnpm)
            pnpm install
            ;;
        yarn)
            yarn install
            ;;
        bun)
            bun install
            ;;
        *)
            npm install
            ;;
    esac
    echo
fi

# Build the project
echo "🔨 Building LSP server..."
case $PM in
    pnpm)
        pnpm build
        ;;
    yarn)
        yarn build
        ;;
    bun)
        bun run build
        ;;
    *)
        npm run build
        ;;
esac

echo "✅ Build complete!"
