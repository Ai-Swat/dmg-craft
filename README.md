# Script to run:

./pipeline.sh

# Or manually:

1) ./sign_app.sh

2) ./make_dmg.sh

3) codesign --force --sign '(identity)' --timestamp --identifier Sigma-(VERSION) Sigma.dmg

4) xcrun notarytool submit Sigma.dmg --keychain-profile sigmabrowser-notary --wait

5) xcrun stapler staple Sigma.dmg