#!/bin/bash
# package_app.sh
#
# Builds Qutran in Release mode and packages it into build/Qutran.zip and build/Qutran.dmg.
#
# Signing is opt-in. With nothing configured the app is signed ad-hoc — with the hardened runtime
# and the real entitlements still applied — so a fresh clone and a fork's CI run both work without
# an Apple Developer account. Point OPENCLIP_SIGN_IDENTITY at a Developer ID certificate to
# produce a distributable build, and add OPENCLIP_NOTARIZE=1 to take it all the way through
# Apple's notary service:
#
#   ./scripts/package_app.sh                                    # ad-hoc, offline, no account
#   OPENCLIP_SIGN_IDENTITY=auto ./scripts/package_app.sh        # Developer ID signed
#   OPENCLIP_SIGN_IDENTITY=auto OPENCLIP_NOTARIZE=1 \
#       ./scripts/package_app.sh                                # signed, notarized, stapled
#
# See scripts/signing_config.sh for the full configuration precedence, including the gitignored
# keys/signing.env used for local release builds.

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

OC_PROJECT_DIR="$PROJECT_DIR"
# shellcheck source=scripts/signing_config.sh
. "$PROJECT_DIR/scripts/signing_config.sh"

oc_load_signing_env
IDENTITY="$(oc_resolve_identity "")"
NOTARIZE="${OPENCLIP_NOTARIZE:-0}"

if [ "$NOTARIZE" = "1" ] && oc_is_adhoc "$IDENTITY"; then
    echo "error: OPENCLIP_NOTARIZE=1 needs a Developer ID identity; Apple will not notarize an ad-hoc build." >&2
    echo "       Set OPENCLIP_SIGN_IDENTITY (see scripts/signing_config.sh)." >&2
    exit 1
fi

echo "Generating Xcode project..."
xcodegen generate

echo "Building Qutran (Release)..."
# The build is left ad-hoc signed whatever the final identity is, and scripts/sign_artifact.sh
# re-signs the finished bundle. That keeps one signing path for contributors and releases alike,
# and it is the only way to get Sparkle's nested helpers off the ad-hoc signature they ship with.
DERIVED_DATA="$PROJECT_DIR/build.noindex/ReleaseDerivedData"
xcodebuild -project OpenClip.xcodeproj -scheme OpenClip -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED_DATA" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES CLANG_ENABLE_CODE_COVERAGE=NO build > /dev/null

BUILT_APP="$DERIVED_DATA/Build/Products/Release/Qutran.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Release build output not found."
    exit 1
fi

"$PROJECT_DIR/scripts/sign_artifact.sh" "$BUILT_APP"

# CI runs this script on every push, so this is where an arm64-only regression gets caught
# before it can reach a tag.
"$PROJECT_DIR/scripts/verify_universal.sh" "$BUILT_APP" "Qutran.app"

# How far the signature has to go depends on what was configured. An ad-hoc build still has to
# be hardened and carry exactly the declared entitlements; a Developer ID build additionally
# needs a real certificate, a secure timestamp, and one team across every nested binary.
REQUIRE="any"
oc_is_adhoc "$IDENTITY" || REQUIRE="developer-id"

if [ "$NOTARIZE" = "1" ]; then
    "$PROJECT_DIR/scripts/verify_signing.sh" "$BUILT_APP" --require "$REQUIRE"
    "$PROJECT_DIR/scripts/notarize_artifact.sh" "$BUILT_APP"
    REQUIRE="notarized"
fi

"$PROJECT_DIR/scripts/verify_signing.sh" "$BUILT_APP" --require "$REQUIRE"

echo "Verifying Qutran launches..."
"$BUILT_APP/Contents/MacOS/Qutran" --version

mkdir -p "$PROJECT_DIR/build"
OUTPUT_ZIP="$PROJECT_DIR/build/Qutran.zip"
OUTPUT_DMG="$PROJECT_DIR/build/Qutran.dmg"

# Both archives are cut after the app is signed and stapled, so the ticket travels with them.
echo "Packaging $BUILT_APP into $OUTPUT_ZIP..."
ditto -c -k --sequesterRsrc --keepParent "$BUILT_APP" "$OUTPUT_ZIP"

echo "Packaging $BUILT_APP into $OUTPUT_DMG..."
"$PROJECT_DIR/scripts/make_dmg.sh" "$BUILT_APP" "$OUTPUT_DMG"

# The disk image is assessed by Gatekeeper in its own right, so it gets its own signature and,
# when notarizing, its own ticket.
"$PROJECT_DIR/scripts/sign_artifact.sh" "$OUTPUT_DMG"
if [ "$NOTARIZE" = "1" ]; then
    "$PROJECT_DIR/scripts/notarize_artifact.sh" "$OUTPUT_DMG"
fi
"$PROJECT_DIR/scripts/verify_signing.sh" "$OUTPUT_DMG" --require "$REQUIRE"

echo "Release packages created:"
echo "  ZIP: $OUTPUT_ZIP"
echo "  DMG: $OUTPUT_DMG"
if oc_is_adhoc "$IDENTITY"; then
    echo ""
    echo "note: this build is ad-hoc signed and not notarized. macOS may block its first launch after downloading."
    echo "      A public test release needs clear Open Anyway instructions; a normal release needs Developer ID signing and notarization."
fi
