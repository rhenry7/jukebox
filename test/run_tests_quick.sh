#!/bin/bash

# Quick test runner - skips analysis, just runs tests
# Usage: ./test/run_tests_quick.sh

set -e

echo "🧪 Running tests (quick mode - no analysis)..."
echo ""

flutter test

echo ""
echo "✅ Tests complete!"
