## Build and Package Clippy

This script builds the application, packages it into a `.app` bundle, and creates a distributable `.dmg` file.

The DMG will contain the application and a shortcut to the `/Applications` folder to guide users on how to install it.

### Usage

You can run the commands one by one, or save the content of the script block into a file (e.g., `build.sh`), make it executable (`chmod +x build.sh`), and run it (`./build.sh`).

### Build Script

```bash
#!/bin/bash

# Exit on error
set -e

# --- Configuration ---
APP_NAME="Clippy"
SCHEME_NAME="Clippy"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR"
EXPORT_OPTIONS_PLIST="Source/exportOptions.plist"
DMG_NAME="$APP_NAME.dmg"
FINAL_DMG_PATH="$BUILD_DIR/$DMG_NAME"
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

# 5. Create the DMG
echo "--- Creating DMG ---"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_CONTENT_DIR" \
    -ov \
    -format UDZO \
    "$FINAL_DMG_PATH"

# 6. Clean up temporary content
echo "--- Cleaning up temporary files ---"
rm -rf "$DMG_CONTENT_DIR"

echo "--- Build successful! ---"
echo "DMG created at: $FINAL_DMG_PATH"
```
