#!/bin/bash
# Start local C-Gateway for development
# Usage: ./scripts/start_gateway_local.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATEWAY_DIR="$PROJECT_ROOT/apps/c-gateway"

cd "$GATEWAY_DIR"

echo "🔧 Building C-Gateway..."
if [ -f "Makefile" ]; then
  make build
else
  echo "⚠️  Makefile not found, trying CMake..."
  if [ -f "CMakeLists.txt" ]; then
    mkdir -p build
    cd build
    cmake ..
    make
    cd ..
  else
    echo "❌ No build system found in $GATEWAY_DIR"
    exit 1
  fi
fi

echo "🚀 Starting C-Gateway on port 8080..."
if [ -f "build/gateway" ]; then
  ./build/gateway --port 8080 --log-level debug
elif [ -f "build/c-gateway" ]; then
  ./build/c-gateway --port 8080 --log-level debug
else
  echo "❌ Gateway binary not found in build/"
  exit 1
fi

