#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/ROBO-iOS-Build-49.xcarchive"
IPA="$BUILD_DIR/ROBO-iOS-Build-49-unsigned.ipa"
echo "Building repository revision: $(git -C "$ROOT" rev-parse --short HEAD)"

if [[ -z "${M3SB_PACKAGE_TOKEN:-}" ]]; then
  M3SB_PACKAGE_TOKEN="ROBO_IOS_BUILD"
fi
if [[ -z "${M3SB_HMAC_SECRET:-}" ]]; then
  M3SB_HMAC_SECRET="ROBO_IOS_BUILD_SECRET"
fi
export M3SB_PACKAGE_TOKEN M3SB_HMAC_SECRET

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
command -v xcodebuild >/dev/null || { echo 'xcodebuild is required on macOS' >&2; exit 127; }
python3 "$ROOT/generate_embedded_localizations.py"

xcodebuild \
  -project "$ROOT/ThreeOneOSFive.xcodeproj" \
  -scheme 3105 \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  archive

APP="$ARCHIVE/Products/Applications/SAKK EXTERNAL.app"
test -d "$APP"
# Remote patches must never be embedded in the signed app. Remove packages
# from every possible Xcode resource layout, not only from the app root.
find "$APP" -type f -name '*.3105' -print -delete
if find "$APP" -type f -name '*.3105' -print -quit | grep -q .; then
  echo "Error: a local .3105 patch remains inside the app bundle." >&2
  exit 1
fi
echo "Verified no bundled local patch resources; patches are loaded only from ROBO iOS online."

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable SAK" "$APP/Info.plist" || true
/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" "$APP/Info.plist" || true
python3 - "$APP/Info.plist" <<'PY'
import base64
import os
import plistlib
import sys

path = sys.argv[1]
values = {
    "M3SB_PACKAGE_TOKEN_OBFUSCATED": os.environ["M3SB_PACKAGE_TOKEN"],
    "M3SB_HMAC_SECRET_OBFUSCATED": os.environ["M3SB_HMAC_SECRET"],
}
with open(path, "rb") as stream:
    info = plistlib.load(stream)
info.pop("M3SB_PACKAGE_TOKEN", None)
info.pop("M3SB_HMAC_SECRET", None)
for key, value in values.items():
    raw = value.encode("utf-8")
    obfuscated = bytes(byte ^ 0x5A for byte in raw)
    info[key] = base64.b64encode(obfuscated).decode("ascii")
with open(path, "wb") as stream:
    plistlib.dump(info, stream, fmt=plistlib.FMT_XML, sort_keys=False)
print("Embedded obfuscated M3SB configuration in the app bundle.")
PY

test -f "$APP/SAK"
# Keep the requested 400 MiB filler before the resource footer is appended.
# The footer must remain at EOF so embed_app_resources.py can verify it.
printf 'Adding 400 MiB executable padding...\n'
dd if=/dev/zero bs=1m count=400 2>/dev/null >> "$APP/SAK"
python3 "$ROOT/embed_app_resources.py" "$APP"
python3 "$ROOT/embed_app_resources.py" --strip-audio "$APP"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"
(
  cd "$BUILD_DIR"
  /usr/bin/zip -9qry "$IPA" Payload
  rm -rf Payload
)
ls -lh "$IPA"
echo "$IPA"
