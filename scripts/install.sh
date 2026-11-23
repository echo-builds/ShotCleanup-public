#!/bin/bash

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
team_id="${SHOTCLEANUP_TEAM_ID:-}"
device_id="${SHOTCLEANUP_DEVICE_ID:-}"
bundle_id="${SHOTCLEANUP_BUNDLE_ID:-}"

usage() {
    cat <<'EOF'
Usage: ./scripts/install.sh [options]

Options:
  --team-id ID       Apple Development team ID
  --device-id ID     Connected iPhone identifier
  --bundle-id ID     Stable, unique bundle identifier
  -h, --help         Show this help

The same values can be provided through SHOTCLEANUP_TEAM_ID,
SHOTCLEANUP_DEVICE_ID, and SHOTCLEANUP_BUNDLE_ID.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --team-id)
            [ "$#" -ge 2 ] || { printf 'Missing value for --team-id\n' >&2; exit 2; }
            team_id="$2"
            shift 2
            ;;
        --device-id)
            [ "$#" -ge 2 ] || { printf 'Missing value for --device-id\n' >&2; exit 2; }
            device_id="$2"
            shift 2
            ;;
        --bundle-id)
            [ "$#" -ge 2 ] || { printf 'Missing value for --bundle-id\n' >&2; exit 2; }
            bundle_id="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

printf 'Checking the Mac, Xcode, signing, and connected iPhone...\n'
if ! "$root_dir/scripts/doctor.sh"; then
    printf '\nResolve the blocking item above, then rerun this same command.\n' >&2
    exit 1
fi
printf '\n'

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'ShotCleanup can only be installed from macOS.\n' >&2
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
    printf 'Full Xcode is required. Install Xcode and select it before continuing.\n' >&2
    exit 1
fi

developer_dir="$(xcode-select -p 2>/dev/null || true)"
case "$developer_dir" in
    */CommandLineTools|"")
        printf 'The full Xcode app is not selected. Run xcode-select after installing Xcode.\n' >&2
        exit 1
        ;;
esac

if [ -z "$team_id" ]; then
    team_ids="$(
        security find-identity -v -p codesigning 2>/dev/null |
        sed -n 's/.*Apple Development:.*(\([A-Z0-9][A-Z0-9]*\))".*/\1/p' |
        sort -u
    )"
    team_count="$(printf '%s\n' "$team_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ "$team_count" = "1" ]; then
        team_id="$(printf '%s\n' "$team_ids" | sed -n '1p')"
    else
        printf 'Unable to choose one signing team automatically.\n' >&2
        if [ -n "$team_ids" ]; then
            printf 'Available team IDs:\n%s\n' "$team_ids" >&2
        else
            printf 'No Apple Development identity was found. A paid membership is not required.\n' >&2
            printf 'Open Xcode → Settings → Accounts, sign in with an Apple Account, then create an Apple Development certificate for the Personal Team.\n' >&2
        fi
        printf 'Rerun with --team-id TEAM_ID.\n' >&2
        exit 2
    fi
fi

if [ -z "$device_id" ]; then
    device_ids="$(
        xcrun xctrace list devices 2>/dev/null |
        awk '/^== Devices ==/{inside=1; next} /^== Simulators ==/{inside=0} inside && /iPhone/ {print}' |
        sed -n 's/.*(\([A-Za-z0-9-][A-Za-z0-9-]*\))$/\1/p'
    )"
    device_count="$(printf '%s\n' "$device_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ "$device_count" = "1" ]; then
        device_id="$(printf '%s\n' "$device_ids" | sed -n '1p')"
    else
        printf 'Unable to choose one connected iPhone automatically.\n' >&2
        if [ -n "$device_ids" ]; then
            printf 'Connected iPhone identifiers:\n%s\n' "$device_ids" >&2
        else
            printf 'No connected iPhone was found. Connect it to the Mac, unlock it, and tap Trust when prompted.\n' >&2
            printf 'If iPhone asks for Developer Mode, enable it and reconnect after the restart.\n' >&2
        fi
        printf 'Rerun with --device-id DEVICE_ID.\n' >&2
        exit 2
    fi
fi

if [ -z "$bundle_id" ]; then
    local_name="$(id -un | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
    [ -n "$local_name" ] || local_name="user"
    bundle_id="com.echobuilds.shotcleanup.local.$local_name"
fi

case "$team_id" in
    *[!A-Za-z0-9]*) printf 'Invalid team ID: %s\n' "$team_id" >&2; exit 2 ;;
esac
case "$device_id" in
    *[!A-Za-z0-9-]*) printf 'Invalid device ID: %s\n' "$device_id" >&2; exit 2 ;;
esac
case "$bundle_id" in
    *[!A-Za-z0-9.-]*) printf 'Invalid bundle identifier: %s\n' "$bundle_id" >&2; exit 2 ;;
esac

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/shotcleanup-build.XXXXXX")"
cleanup() { rm -rf "$build_dir"; }
trap cleanup EXIT

printf 'Building ShotCleanup\n'
printf '  Team:   %s\n' "$team_id"
printf '  Device: %s\n' "$device_id"
printf '  Bundle: %s\n' "$bundle_id"

xcodebuild \
    -project "$root_dir/ShotCleanup.xcodeproj" \
    -scheme ShotCleanup \
    -configuration Debug \
    -destination "id=$device_id" \
    -derivedDataPath "$build_dir" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$team_id" \
    PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
    CODE_SIGN_STYLE=Automatic \
    build

app_path="$build_dir/Build/Products/Debug-iphoneos/ShotCleanup.app"
if [ ! -d "$app_path" ]; then
    printf 'Build succeeded, but the app was not found at %s\n' "$app_path" >&2
    exit 1
fi

xcrun devicectl device install app --device "$device_id" "$app_path"

if xcrun devicectl device process launch --device "$device_id" "$bundle_id" >/dev/null 2>&1; then
    printf 'ShotCleanup was installed and launched successfully.\n'
else
    printf 'ShotCleanup was installed. Unlock the iPhone and open the app manually.\n'
fi

cat <<'EOF'

Finish on the iPhone:
1. Allow ShotCleanup to access photos.
2. Create a Shortcut: Take Screenshot → 识别刚发送的截图.
3. Assign that Shortcut to Settings → Accessibility → Touch → Back Tap → Triple Tap.
EOF
