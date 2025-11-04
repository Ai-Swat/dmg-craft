#!/bin/bash
set -euo pipefail

# Configuration
SIGNING_IDENTITY="494F2BABFCB3A862B25BB157B6EF9C0E81968455"
DMG_IDENTIFIER="Sigma-141.0.7391.44"
DMG_PATH="/Users/nikitabogatyrev/dmg-craft/Sigma.dmg"
KEYCHAIN_PROFILE="sigmabrowser-notary"

echo "=== Starting Sigma DMG Build Pipeline ==="
echo ""

# Step 1: Sign the application
echo "[1/5] Signing the application..."
./sign_app.sh
echo "✓ Application signed successfully"
echo ""

# Step 2: Create DMG
echo "[2/5] Creating DMG..."
./make_dmg.sh
echo "✓ DMG created successfully"
echo ""

# Step 3: Code sign the DMG
echo "[3/5] Code signing the DMG..."
codesign --sign "$SIGNING_IDENTITY" --timestamp --identifier "$DMG_IDENTIFIER" "$DMG_PATH"
echo "✓ DMG signed successfully"
echo ""

# Step 4: Submit for notarization
echo "[4/5] Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
echo "✓ Notarization completed successfully"
echo ""

# Step 5: Staple the notarization ticket
echo "[5/5] Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"
echo "✓ Notarization ticket stapled successfully"
echo ""

echo "=== Pipeline completed successfully! ==="
echo "Final DMG: $DMG_PATH"

