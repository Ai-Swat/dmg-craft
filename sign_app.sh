#!/bin/bash

# SCRIPT TO SIGN CHROMIUM-BASED APPLICATION (Sigma.app)
# SIGN ALL COMPONENTS IN THE CORRECT ORDER FOR NOTARIZATION

set -e

# ============ SETTINGS ============
APP_PATH="/Users/nikitabogatyrev/Sigma-AI-Browser/src/out/mac/Sigma.app"
IDENTITY="494F2BABFCB3A862B25BB157B6EF9C0E81968455"  # Developer ID Application

# CHECK IF THE APPLICATION EXISTS
if [ ! -d "$APP_PATH" ]; then
    echo "❌ ERROR: Application not found at path: $APP_PATH"
    exit 1
fi

echo "🔐 STARTING SIGNING $APP_PATH"
echo "📝 USING CERTIFICATE: $IDENTITY"
echo ""

# FUNCTION TO SIGN WITH THE CORRECT FLAGS
sign_binary() {
    local file="$1"
    local identifier="$2"
    
    if [ -z "$identifier" ]; then
        codesign --sign "$IDENTITY" \
                 --force \
                 --timestamp \
                 --options runtime \
                 "$file"
    else
        codesign --sign "$IDENTITY" \
                 --force \
                 --timestamp \
                 --options runtime \
                 --identifier "$identifier" \
                 "$file"
    fi
    
    echo "  ✓ SIGNED: $(basename "$file")"
}

# 1. SIGN DYNAMIC LIBRARIES
echo "📚 SIGNING LIBRARIES..."
FRAMEWORK_PATH="$APP_PATH/Contents/Frameworks/Sigma Framework.framework"
VERSION_PATH="$FRAMEWORK_PATH/Versions/141.0.7391.44"

if [ -d "$VERSION_PATH/Libraries" ]; then
    for dylib in "$VERSION_PATH/Libraries"/*.dylib; do
        if [ -f "$dylib" ]; then
            sign_binary "$dylib"
        fi
    done
fi

# 2. SIGN HELPER UTILITIES
echo ""
echo "🔧 SIGNING HELPER UTILITIES..."
if [ -d "$VERSION_PATH/Helpers" ]; then
    for helper in "$VERSION_PATH/Helpers"/*; do
        if [ -f "$helper" ] && [ -x "$helper" ]; then
            sign_binary "$helper"
        fi
    done
fi

# 3. CREATE TEMPORARY FILE ENTITLEMENTS FOR HELPER APPLICATIONS (WILL BE USED LATER)
HELPER_ENTITLEMENTS_TEMP="/tmp/sigma_helper_entitlements_temp.plist"
cat > "$HELPER_ENTITLEMENTS_TEMP" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF

# 4. SIGN HELPER APPLICATIONS
echo ""
echo "🤝 SIGNING HELPER APPLICATIONS..."
HELPERS_DIR="$VERSION_PATH/Helpers"

for helper_app in "$HELPERS_DIR"/*.app; do
    if [ -d "$helper_app" ]; then
        helper_name=$(basename "$helper_app")
        echo "  SIGNING: $helper_name"
        
        # SIGN EXECUTABLE FILE INSIDE HELPER.APP WITH ENTITLEMENTS
        executable="$helper_app/Contents/MacOS/$(basename "$helper_app" .app)"
        if [ -f "$executable" ]; then
            codesign --sign "$IDENTITY" \
                     --force \
                     --timestamp \
                     --options runtime \
                     --entitlements "$HELPER_ENTITLEMENTS_TEMP" \
                     "$executable"
            echo "    ✓ SIGNED EXECUTABLE: $(basename "$executable")"
        fi
        
        # SIGN ENTIRE HELPER.APP BUNDLE WITH ENTITLEMENTS
        codesign --sign "$IDENTITY" \
                 --force \
                 --timestamp \
                 --options runtime \
                 --entitlements "$HELPER_ENTITLEMENTS_TEMP" \
                 "$helper_app"
        echo "    ✓ SIGNED BUNDLE: $helper_name"
    fi
done

# 5. SIGN SPARKLE FRAMEWORK COMPONENTS
echo ""
echo "⚡ SIGNING SPARKLE FRAMEWORK..."
SPARKLE_PATH="$VERSION_PATH/Frameworks/Sparkle.framework"

if [ -d "$SPARKLE_PATH" ]; then
    # Sign Sparkle XPC Services
    if [ -d "$SPARKLE_PATH/Versions/B/XPCServices" ]; then
        for xpc in "$SPARKLE_PATH/Versions/B/XPCServices"/*.xpc; do
            if [ -d "$xpc" ]; then
                xpc_name=$(basename "$xpc")
                echo "  Signing XPC: $xpc_name"
                
                # Sign executable inside XPC
                xpc_exec="$xpc/Contents/MacOS/$(basename "$xpc" .xpc)"
                if [ -f "$xpc_exec" ]; then
                    sign_binary "$xpc_exec"
                fi
                
                # Sign entire XPC bundle
                sign_binary "$xpc"
            fi
        done
    fi
    
    # Sign Sparkle Updater.app
    if [ -d "$SPARKLE_PATH/Versions/B/Updater.app" ]; then
        echo "  Signing Updater.app"
        updater_exec="$SPARKLE_PATH/Versions/B/Updater.app/Contents/MacOS/Updater"
        if [ -f "$updater_exec" ]; then
            sign_binary "$updater_exec"
        fi
        sign_binary "$SPARKLE_PATH/Versions/B/Updater.app"
    fi
    
    # Sign Sparkle Autoupdate binary
    if [ -f "$SPARKLE_PATH/Versions/B/Autoupdate" ]; then
        sign_binary "$SPARKLE_PATH/Versions/B/Autoupdate"
    fi
    
    # Sign main Sparkle binary
    if [ -f "$SPARKLE_PATH/Versions/B/Sparkle" ]; then
        sign_binary "$SPARKLE_PATH/Versions/B/Sparkle"
    fi
    
    # Sign entire Sparkle Framework
    sign_binary "$SPARKLE_PATH"
    echo "  ✓ Sparkle Framework signed"
fi

# 6. SIGN SIGMA FRAMEWORK
echo ""
echo "📦 SIGNING SIGMA FRAMEWORK..."
if [ -f "$VERSION_PATH/Sigma Framework" ]; then
    sign_binary "$VERSION_PATH/Sigma Framework"
fi

# SIGN ENTIRE FRAMEWORK
sign_binary "$FRAMEWORK_PATH" "com.sigmabrowser.SigmaFramework"

# 7. SIGN LIBSIGMA_ADBLOCK_BRIDGE.DYLIB
echo ""
echo "🛡️  SIGNING ADBLOCK BRIDGE..."
if [ -f "$APP_PATH/Contents/Frameworks/libsigma_adblock_bridge.dylib" ]; then
    sign_binary "$APP_PATH/Contents/Frameworks/libsigma_adblock_bridge.dylib"
fi

# 8. SIGN MAIN EXECUTABLE FILE
echo ""
echo "⚙️  SIGNING MAIN EXECUTABLE FILE..."
sign_binary "$APP_PATH/Contents/MacOS/Sigma" "com.sigmabrowser.sigmabrowser"

# 9. CREATE FILE ENTITLEMENTS FOR MAIN APPLICATION
ENTITLEMENTS_FILE="/tmp/sigma_entitlements.plist"
cat > "$ENTITLEMENTS_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.personal-information.location</key>
    <true/>
	<key>com.apple.security.device.bluetooth</key>
	<true/>
	<key>com.apple.security.device.print</key>
	<true/>
	<key>com.apple.security.device.usb</key>
	<true/>
	<key>com.apple.security.personal-information.photos-library</key>
	<true/>
</dict>
</plist>
EOF

# 10. SIGN ENTIRE APPLICATION
echo ""
echo "📱 SIGNING ENTIRE APPLICATION..."
codesign --sign "$IDENTITY" \
         --force \
         --timestamp \
         --options runtime \
         --entitlements "$ENTITLEMENTS_FILE" \
         "$APP_PATH"

echo "  ✓ SIGNED: Sigma.app"

# DELETE TEMPORARY FILES
rm -f "$ENTITLEMENTS_FILE" "$HELPER_ENTITLEMENTS_TEMP"

# 11. CHECK SIGNATURE
echo ""
echo "🔍 CHECKING SIGNATURE..."
if codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1; then
    echo ""
    echo "✅ SIGNATURE IS VALID AND SUCCESSFUL!"
    echo ""
    echo "📊 INFORMATION ABOUT THE SIGNATURE:"
    codesign --display --verbose=4 "$APP_PATH" 2>&1 | grep -E "(Identifier|Authority|Timestamp|Runtime)"
else
    echo ""
    echo "⚠️  WARNING: THERE ARE PROBLEMS WITH THE SIGNATURE"
    exit 1
fi

echo ""
echo "🎉 DONE! THE APPLICATION IS SIGNED AND READY FOR CREATING DMG."

