#!/bin/bash
set -euo pipefail

APP_PATH=""        # -> path to Sigma.app (relative or absolute)
BACKGROUND_IMG="/Users/nikitabogatyrev/dmg-craft/Content_Area_2.png"                    # -> background (recommended size: 600x400 or 2x for Retina)
VOL_NAME="Sigma Installer"                                                              # name of the volume, will be displayed in /Volumes/
DMG_RW="sigma-temp.dmg"
DMG_FINAL="Sigma.dmg"

# working directory
WORKDIR="$(pwd)/dmgroot"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/.background"

# copy the application
cp -R "$APP_PATH" "$WORKDIR/"

# change the app icon
ICON_PATH="/Users/nikitabogatyrev/dmg-craft/sigma_browser_icon.png"
# if [ -f "$ICON_PATH" ]; then
#   # Convert PNG to ICNS format
#   sips -s format icns "$ICON_PATH" --out "$WORKDIR/Sigma.app/Contents/Resources/app.icns"
#   echo "The application icon has been changed to $ICON_PATH"
# else
#   echo "Warning: The file $ICON_PATH not found"
# fi

# copy the background and the arrow
cp "$BACKGROUND_IMG" "$WORKDIR/.background/background.png"
# if [ -n "${ARROW_IMG}" ] && [ -f "${ARROW_IMG}" ]; then
#   cp "$ARROW_IMG" "$WORKDIR/arrow.png"
# fi

# copy text labels
SIGMA_TEXT="/Users/nikitabogatyrev/dmg-craft/Sigma_Browser_text.png"
APP_TEXT="/Users/nikitabogatyrev/dmg-craft/Application_text.png"

# if [ -f "$SIGMA_TEXT" ]; then
#   cp "$SIGMA_TEXT" "$WORKDIR/Sigma_Browser_text.png"
#   echo "Added signature for Sigma.app"
# else
#   echo "Warning: The file $SIGMA_TEXT not found"
# fi

# if [ -f "$APP_TEXT" ]; then
#   cp "$APP_TEXT" "$WORKDIR/Application_text.png"
#   echo "Added signature for Applications"
# else
#   echo "Warning: The file $APP_TEXT not found"
# fi

# create Finder alias (correct icon "Applications") - make alias through AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
  set target_folder to POSIX file "$WORKDIR" as alias
  set theAlias to make new alias at target_folder to (POSIX file "/Applications" as alias)
  set name of theAlias to "Applications"
end tell
APPLESCRIPT

# create read-write dmg based on the folder
hdiutil create -srcfolder "$WORKDIR" -volname "$VOL_NAME" -ov -format UDRW "$DMG_RW"

# mount (do not use -nobrowse - it is needed to make the Finder window available)
hdiutil attach "$DMG_RW"
# give the system time to mount
sleep 1

# AppleScript for the window settings: view, background and icon positions
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    -- view in the form of icons and etc.
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    -- window size {left, top, right, bottom} in pixels of the screen
    set bounds of container window to {100, 100, 700, 500}

    set vopts to the icon view options of container window
    set arrangement of vopts to not arranged
    set icon size of vopts to 128
    -- specify the background file (relative path in the volume)
    set background picture of vopts to file ".background:background.png"

    delay 0.3 -- small pause so that Finder has time to apply the settings

    -- Positioning: adjust the numbers {x, y}
    try
      set position of item "Sigma.app" of it to {140, 200}
    end try
    try
      set position of item "Applications" of it to {450, 200}
    end try
    try
      set position of item "Sigma_Browser_text.png" of it to {140, 350}
    end try
    try
      set position of item "Application_text.png" of it to {450, 350}
    end try
    try
      set position of item "arrow.png" of it to {500, 300}
    end try

    close
  end tell
end tell
APPLESCRIPT

# give time and synchronize the changes
sync
sleep 1

# detach
hdiutil detach "/Volumes/$VOL_NAME"

# convert to compressed read-only (.dmg)
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"

echo "Done: $DMG_FINAL (in the current directory)."
