#!/bin/bash

set -u

failures=0
warnings=0

pass() { printf '✓ %s\n' "$1"; }
warn() { printf '! %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf '✗ %s\n' "$1"; failures=$((failures + 1)); }

if [ "$(uname -s)" = "Darwin" ]; then
    pass "Running on macOS"
else
    fail "ShotCleanup can only be installed from macOS"
fi

if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
    pass "Full Xcode is available: $(xcodebuild -version | head -n 1)"
else
    fail "Full Xcode is not selected. Install Xcode from Apple, open it once, then select it with xcode-select"
fi

developer_dir="$(xcode-select -p 2>/dev/null || true)"
case "$developer_dir" in
    */CommandLineTools)
        fail "Only Command Line Tools are selected; select the full Xcode app"
        ;;
    "")
        fail "No active Xcode developer directory was found"
        ;;
    *)
        pass "Active developer directory: $developer_dir"
        ;;
esac

if xcrun --find devicectl >/dev/null 2>&1; then
    pass "Apple device tools are available"
else
    fail "devicectl is unavailable; install or select a current Xcode version"
fi

identities="$(security find-identity -v -p codesigning 2>/dev/null | grep 'Apple Development' || true)"
if [ -n "$identities" ]; then
    pass "Apple Development signing identity found"
    printf '%s\n' "$identities" | sed 's/^/  /'
else
    warn "No Apple Development signing identity found. A paid membership is not required: sign in at Xcode → Settings → Accounts, then create an Apple Development certificate for your Personal Team"
fi

device_lines="$(
    xcrun xctrace list devices 2>/dev/null |
    awk '/^== Devices ==/{inside=1; next} /^== Simulators ==/{inside=0} inside && /iPhone/ {print}'
)"
if [ -n "$device_lines" ]; then
    pass "Connected iPhone detected"
    printf '%s\n' "$device_lines" | sed 's/^/  /'
else
    warn "No connected iPhone detected. Connect it to the Mac, unlock it, tap Trust, and enable Developer Mode if requested"
fi

printf '\n'
if [ "$failures" -gt 0 ]; then
    printf 'Doctor found %s blocking problem(s) and %s warning(s).\n' "$failures" "$warnings"
    exit 1
fi

printf 'Doctor found no blocking problems and %s warning(s).\n' "$warnings"
