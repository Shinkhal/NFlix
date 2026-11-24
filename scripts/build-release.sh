#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
npm test
npm run dist
node scripts/check-artifacts.cjs
