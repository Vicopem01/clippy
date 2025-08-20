#!/bin/bash

# Exit on error
set -e

# Log file
LOG_FILE="build.log"
exec > >(tee "$LOG_FILE") 2>&1

# --- Configuration ---
APP_NAME="Clippy"
SCHEME_NAME="Clippy"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR"
EXPORT_OPTIONS_PLIST="Source/exportOptions.plist"
DMG_NAME="$APP_NAME.dmg"
FINAL_DMG_PATH="$BUILD_DIR/$DMG_NAME"
TEMP_DMG_PATH="$BUILD_DIR/temp.$DMG_NAME"
DMG_CONTENT_DIR="$BUILD_DIR/dmg_content"

# --- Build Steps ---

# 1. Clean previous build artifacts
echo "--- Cleaning up old build artifacts ---"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 2. Archive the application
echo "--- Archiving the application ---"
xcodebuild archive \
    -scheme "$SCHEME_NAME" \
    -archivePath "$ARCHIVE_PATH"

# 3. Export the .app from the archive
echo "--- Exporting the .app from the archive ---"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

# 4. Prepare for DMG creation
echo "--- Preparing content for DMG ---"
mkdir -p "$DMG_CONTENT_DIR"
cp -R "$EXPORT_PATH/$APP_NAME.app" "$DMG_CONTENT_DIR/"
ln -s /Applications "$DMG_CONTENT_DIR/Applications"

# 5. Create a temporary DMG
echo "--- Creating temporary DMG ---"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_CONTENT_DIR" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$TEMP_DMG_PATH"

# 6. Mount the DMG and apply styling
# Use grep to reliably extract the mount point
MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG_PATH" | grep -o '/Volumes/Clippy[^ ]*')
if [ -z "$MOUNT_POINT" ]; then
    echo "[ERROR] Could not determine DMG mount point. Aborting." | tee -a "$LOG_FILE"
    exit 1
fi

echo "[INFO] DMG mounted at $MOUNT_POINT" | tee -a "$LOG_FILE"

# Hide all top-level items that are not symlinks, then unhide the app.
# This avoids "operation not permitted" on the Applications symlink.
find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 ! -type l -exec chflags hidden {} +
chflags nohidden "$MOUNT_POINT/$APP_NAME.app"

# AppleScript: only position Clippy.app and Applications, smaller window size
osascript <<EOT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 100, 1000, 500}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 110
    set background color of theViewOptions to {12000, 12000, 12000}
    set position of item "$APP_NAME.app" of container window to {150, 180}
    set position of item "Applications" of container window to {450, 180}
    update without registering applications
    close
  end tell
end tell
EOT

# 7. Unmount the DMG
echo "--- Unmounting DMG ---"
hdiutil detach "$MOUNT_POINT" -force

# Add a small delay to allow the system to release the DMG file
sleep 2

# 8. Convert to compressed DMG
echo "--- Converting to compressed DMG ---"
hdiutil convert "$TEMP_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG_PATH"

# 9. Clean up temporary files
echo "--- Cleaning up temporary files ---"
rm -rf "$TEMP_DMG_PATH"
rm -rf "$DMG_CONTENT_DIR"

echo "--- Build successful! ---"
echo "DMG created at: $FINAL_DMG_PATH"
