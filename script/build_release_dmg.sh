#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TinySigner"
PROJECT_NAME="TinySigner.xcodeproj"
SCHEME_NAME="TinySigner"
CONFIGURATION="Release"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_ROOT="$ROOT_DIR/build/release"
ARCHIVE_PATH="$RELEASE_ROOT/$APP_NAME.xcarchive"
EXPORT_PATH="$RELEASE_ROOT/export"
EXPORT_OPTIONS="$RELEASE_ROOT/ExportOptions.plist"
DMG_STAGING="$RELEASE_ROOT/dmg-staging"
NOTARIZE=false
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"

usage() {
  cat <<USAGE
Usage: $0 [--notarize] [--profile KEYCHAIN_PROFILE]

Builds a Release archive, exports a Developer ID signed app, and packages it
as a drag-to-Applications DMG under build/release/.

Options:
  --notarize                 Submit the DMG with notarytool and staple ticket.
  --profile KEYCHAIN_PROFILE Keychain profile created by xcrun notarytool.

Environment:
  NOTARYTOOL_PROFILE         Default keychain profile for --notarize.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize)
      NOTARIZE=true
      shift
      ;;
    --profile)
      NOTARY_PROFILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$NOTARIZE" == true && -z "$NOTARY_PROFILE" ]]; then
  echo "Missing notarytool profile. Pass --profile or set NOTARYTOOL_PROFILE." >&2
  exit 2
fi

setting_from_xcodebuild() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  '
}

echo "Reading release build settings..."
BUILD_SETTINGS="$(
  xcodebuild \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -showBuildSettings
)"

MARKETING_VERSION="$(printf "%s" "$BUILD_SETTINGS" | setting_from_xcodebuild MARKETING_VERSION)"
BUILD_NUMBER="$(printf "%s" "$BUILD_SETTINGS" | setting_from_xcodebuild CURRENT_PROJECT_VERSION)"
TEAM_ID="$(printf "%s" "$BUILD_SETTINGS" | setting_from_xcodebuild DEVELOPMENT_TEAM)"
DMG_BASENAME="$APP_NAME-$MARKETING_VERSION"
DMG_PATH="$RELEASE_ROOT/$DMG_BASENAME.dmg"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"

if [[ -z "$MARKETING_VERSION" || -z "$BUILD_NUMBER" || -z "$TEAM_ID" ]]; then
  echo "Could not read version/build/team settings from Xcode." >&2
  exit 1
fi

mkdir -p "$RELEASE_ROOT"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$DMG_STAGING" "$DMG_PATH" "$DMG_PATH.sha256"

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST

echo "Archiving $APP_NAME $MARKETING_VERSION ($BUILD_NUMBER)..."
xcodebuild archive \
  -project "$ROOT_DIR/$PROJECT_NAME" \
  -scheme "$SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  | tee "$RELEASE_ROOT/archive.log"

echo "Exporting Developer ID signed app..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  | tee "$RELEASE_ROOT/export.log"

echo "Creating DMG..."
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
  -volname "$APP_NAME $MARKETING_VERSION" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

DMG_SIGN_IDENTITY="$(
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -v team="$TEAM_ID" '/Developer ID Application:/ && index($0, "(" team ")") { print $2; exit }'
)"

if [[ -n "$DMG_SIGN_IDENTITY" ]]; then
  echo "Signing DMG..."
  codesign --force --sign "$DMG_SIGN_IDENTITY" "$DMG_PATH"
else
  echo "Warning: Developer ID Application identity not found; DMG was not code signed." >&2
fi

if [[ "$NOTARIZE" == true ]]; then
  echo "Submitting DMG for notarization with profile '$NOTARY_PROFILE'..."
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "Stapling notarization ticket..."
  xcrun stapler staple "$DMG_PATH"
fi

echo "Validating release artifact..."
{
  echo "== App code signature verify =="
  codesign --verify --deep --strict --verbose=4 "$APP_PATH"
  echo
  echo "== App signing identity =="
  codesign -dv --verbose=4 "$APP_PATH" 2>&1 | egrep 'Identifier=|Authority=|TeamIdentifier=|Runtime Version=|Timestamp=|Format='
  echo
  echo "== App entitlements =="
  codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | plutil -p -
  echo
  echo "== Binary architectures =="
  lipo -info "$APP_PATH/Contents/MacOS/$APP_NAME"
  echo
  echo "== DMG checksum verify =="
  hdiutil verify "$DMG_PATH"
  echo
  echo "== DMG code signature verify =="
  codesign --verify --verbose=4 "$DMG_PATH"
  codesign -dv --verbose=4 "$DMG_PATH" 2>&1 | egrep 'Authority=|TeamIdentifier=|Timestamp=|Format='
  echo
  echo "== Stapler DMG validation =="
  xcrun stapler validate "$DMG_PATH" || true
  echo
  echo "== Gatekeeper app assessment =="
  spctl -a -vvv -t execute "$APP_PATH" || true
} | tee "$RELEASE_ROOT/validation.log"

shasum -a 256 "$DMG_PATH" | tee "$DMG_PATH.sha256"

echo
echo "Release DMG: $DMG_PATH"
echo "SHA-256:     $DMG_PATH.sha256"
if [[ "$NOTARIZE" != true ]]; then
  echo "Not notarized. Re-run with --notarize --profile KEYCHAIN_PROFILE before public distribution."
fi
