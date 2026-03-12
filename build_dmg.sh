#!/bin/bash
set -e

APP_NAME="JobApplicationWizard"
BUNDLE_ID="com.zsparks.jobapplicationwizard"
VERSION="2.1"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
DMG_FINAL="$APP_NAME.dmg"
DMG_RW="${APP_NAME}-rw.dmg"
VOL_NAME="Job Application Wizard"
# Set these in your environment or a local .env file (never commit them):
#   export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export NOTARIZE_PROFILE="JobApplicationWizard"
SIGN_IDENTITY="${SIGN_IDENTITY:?Need to set SIGN_IDENTITY}"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-JobApplicationWizard}"

# ── 1. Build ──────────────────────────────────────────────────────────────────
echo "▶ Building release binary..."
swift build -c release

# ── 2. Assemble .app bundle ───────────────────────────────────────────────────
echo "▶ Assembling .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
[ -f "AppIcon.icns" ] && cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" << INFOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>Job Application Wizard</string>
    <key>CFBundleDisplayName</key><string>Job Application Wizard</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict>
</plist>
INFOPLIST

echo "▶ Signing app bundle..."
codesign --force --deep --options runtime \
    --entitlements "Entitlements.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP_BUNDLE"

# ── 3. Generate DMG background image (pure Python stdlib, no deps) ─────────────
echo "▶ Generating background image..."
python3 << 'PYEOF'
import struct, zlib

W, H = 540, 380

def write_png(path, rows):
    def chunk(t, d):
        c = t + d
        return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    raw = b''.join(b'\x00' + bytes([ch for px in row for ch in px]) for row in rows)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n'
              + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
              + chunk(b'IDAT', zlib.compress(raw, 9))
              + chunk(b'IEND', b''))

# Light gradient: #f5f5f7 → #eaeaec top to bottom (macOS light chrome)
pixels = [
    [(int(245 + (234 - 245) * y / (H - 1)),
      int(245 + (234 - 245) * y / (H - 1)),
      int(247 + (236 - 247) * y / (H - 1))) for _ in range(W)]
    for y in range(H)
]

ARROW = (174, 174, 178)   # macOS separator color (light)

def put(x, y):
    if 0 <= x < W and 0 <= y < H:
        pixels[y][x] = ARROW

# Layout:
#   app icon centre  → x=150, y=165  (128 px icon → right edge at x=214)
#   Applications     → x=390, y=165  (128 px icon → left  edge at x=326)
#   Arrow occupies the 112 px gap between x=214 and x=326
mid_y = 165

# Shaft: x 220–297, 18 px tall
for y in range(mid_y - 9, mid_y + 10):
    for x in range(220, 298):
        put(x, y)

# Arrowhead triangle: x 297–323, tapers from 44 px to 0
for x in range(297, 324):
    half = int(22 * (1.0 - (x - 297) / 27))
    for y in range(mid_y - half, mid_y + half + 1):
        put(x, y)

write_png('/tmp/dmg_bg.png', pixels)
print("  /tmp/dmg_bg.png written")
PYEOF

# ── 4. Create blank read-write DMG ────────────────────────────────────────────
echo "▶ Creating read-write DMG..."
rm -f "$DMG_RW" "$DMG_FINAL"
# Detach any leftover mount from a previous failed run
hdiutil detach "/Volumes/$VOL_NAME" -quiet 2>/dev/null || true

hdiutil create \
    -size 50m \
    -fs HFS+ \
    -volname "$VOL_NAME" \
    "$DMG_RW"

hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen
VOLUME="/Volumes/$VOL_NAME"

# ── 5. Populate volume ────────────────────────────────────────────────────────
cp -r "$APP_BUNDLE" "$VOLUME/"
ln -sf /Applications "$VOLUME/Applications"

# Background image goes in a hidden folder; Finder reads it to paint the window
mkdir -p "$VOLUME/.background"
cp /tmp/dmg_bg.png "$VOLUME/.background/background.png"
rm /tmp/dmg_bg.png

# ── 6. Configure Finder window via AppleScript ────────────────────────────────
echo "▶ Configuring Finder window..."
sleep 1   # give Finder a moment to register the newly mounted volume

osascript << APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- window: 540 wide × 380 tall, positioned near top-left of screen
        set the bounds of container window to {100, 100, 640, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        -- icon positions: centres at (150,165) and (390,165) within the window
        set position of item "$APP_NAME.app" of container window to {150, 165}
        set position of item "Applications"  of container window to {390, 165}
        close
        open
        update without registering applications
        delay 4
    end tell
end tell
APPLESCRIPT

# ── 7. Finalise and convert ───────────────────────────────────────────────────
echo "▶ Finalising..."
chmod -Rf go-w "$VOLUME"
sync
sleep 1

hdiutil detach "$VOLUME" -quiet

echo "▶ Converting to compressed read-only DMG..."
hdiutil convert "$DMG_RW" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FINAL"

rm -f "$DMG_RW"

# ── 8. Notarize and staple ────────────────────────────────────────────────────
echo "▶ Submitting to Apple notarization (this takes a minute)..."
xcrun notarytool submit "$DMG_FINAL" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait

echo "▶ Stapling notarization ticket..."
xcrun stapler staple "$DMG_FINAL"

echo ""
echo "✓  $DMG_FINAL  ($(du -sh "$DMG_FINAL" | awk '{print $1}')) — notarized & stapled"
