#!/usr/bin/env bash

set -euo pipefail

echo "🧪 Running Rails Builder Tests"
echo "=============================="

# Detect current system
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == "arm64" ]]; then
        SYSTEM="aarch64-darwin"
    else
        SYSTEM="x86_64-darwin"
    fi
else
    if [[ $(uname -m) == "x86_64" ]]; then
        SYSTEM="x86_64-linux"
    else
        SYSTEM="aarch64-linux"
    fi
fi

echo "🖥️  Detected system: $SYSTEM"
echo ""

# Function to run a specific test
run_test() {
    local test_name=$1
    echo "🔍 Running $test_name..."

    if nix build ".#checks.$SYSTEM.$test_name" --no-link; then
        echo "✅ $test_name passed"
    else
        echo "❌ $test_name failed"
        return 1
    fi
    echo ""
}

# Function to run all tests
run_all_tests() {
    echo "🚀 Running all tests..."

    if nix build ".#checks.$SYSTEM.runAllTests" --no-link; then
        echo "✅ All tests passed!"
    else
        echo "❌ Some tests failed"
        return 1
    fi
    echo ""
}

# Parse command line arguments
case "${1:-all}" in
    "basic")
        run_test "testBasicBuild"
        ;;
    "templates")
        run_test "testTemplates"
        ;;
    "cross-platform")
        run_test "testCrossPlatform"
        ;;
    "all")
        run_all_tests
        ;;
    "individual")
        echo "🔄 Running individual tests..."
        run_test "testBasicBuild"
        run_test "testTemplates"
        run_test "testCrossPlatform"
        echo "✅ All individual tests completed!"
        ;;
    *)
        echo "Usage: $0 [basic|templates|cross-platform|all|individual]"
        echo ""
        echo "Tests available:"
        echo "  basic        - Test basic build functionality"
        echo "  templates    - Test template validity"
        echo "  cross-platform - Test cross-platform compatibility"
        echo "  all          - Run all tests together (default)"
        echo "  individual   - Run all tests individually"
        exit 1
        ;;
esac

echo "🎉 Test run completed!"