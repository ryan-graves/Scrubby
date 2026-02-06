# FileScrubby Releases

This directory contains release artifacts and update information for FileScrubby.

## Contents

- **appcast.xml** - Sparkle update feed (read by app to check for updates)
- **FileScrubby.dmg** - Latest release DMG (older versions are replaced)
- **FileScrubby-{version}.dmg** - Version-specific DMGs for history

## Release Process

### Automated (Recommended)

```bash
# From project root
./scripts/create-release.sh
```

The script will:
1. Build the app in Release configuration
2. Create a DMG
3. Generate signatures using your Sparkle private key
4. Update appcast.xml automatically
5. Provide git commands to complete the release

### Manual Process

If you need to do it manually:

#### 1. Build & Export App
```bash
# Archive in Xcode
# Product → Archive → Distribute App → Copy App
```

#### 2. Create DMG
```bash
# Using hdiutil
hdiutil create -volname "FileScrubby" -srcfolder /path/to/FileScrubby.app -ov -format UDZO FileScrubby.dmg

# Or use create-dmg tool (better looking)
brew install create-dmg
create-dmg \
  --volname "FileScrubby" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "FileScrubby.app" 200 190 \
  --hide-extension "FileScrubby.app" \
  --app-drop-link 600 185 \
  "FileScrubby.dmg" \
  "/path/to/FileScrubby.app"
```

#### 3. Sign Update
```bash
# Install Sparkle tools
brew install sparkle

# Sign the DMG
sign_update FileScrubby.dmg --ed-key-file ~/.sparkle_private_key

# This outputs: sparkle:edSignature="..." and length="..."
```

#### 4. Update appcast.xml
Add a new `<item>` to appcast.xml:

```xml
<item>
    <title>1.2</title>
    <pubDate>Mon, 10 Feb 2025 12:00:00 -0600</pubDate>
    <sparkle:version>11</sparkle:version>
    <sparkle:shortVersionString>1.2</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>15.2</sparkle:minimumSystemVersion>
    <enclosure
        url="https://raw.githubusercontent.com/ryan-graves/Scrubby/refs/heads/main/Releases/FileScrubby-1.2.dmg"
        length="[SIZE_FROM_STEP_3]"
        type="application/octet-stream"
        sparkle:edSignature="[SIGNATURE_FROM_STEP_3]"/>
</item>
```

Or use Sparkle's generate_appcast tool:
```bash
cd Releases
generate_appcast --ed-key-file ~/.sparkle_private_key \
  --download-url-prefix "https://raw.githubusercontent.com/ryan-graves/Scrubby/refs/heads/main/Releases/" \
  .
```

#### 5. Commit & Push
```bash
git add Releases/
git commit -m "Release version 1.2 (build 11)"
git push origin main
```

## Version Numbering

- **CFBundleShortVersionString** (User-facing version): `1.0`, `1.1`, `1.2`
- **CFBundleVersion** (Build number): Increment for each release: `9`, `10`, `11`

Update these in Xcode:
- Target → General → Identity → Version / Build

## Sparkle Configuration

### Keys
- **Public key** (in FileScrubby-Info.plist): `leaOOoTlpm3GlrcL/GQtnYskall1rMRX6aWtWyy8/qg=`
- **Private key**: Store securely at `~/.sparkle_private_key` (NEVER commit!)

### Feed URL
```
https://raw.githubusercontent.com/ryan-graves/Scrubby/refs/heads/main/Releases/appcast.xml
```

### Entitlements Required
```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Testing Updates

1. Build and run the app
2. Go to menu: FileScrubby → Check for Updates...
3. Should detect the latest version from appcast.xml

### Testing with a local server
```bash
# Serve appcast locally
cd Releases
python3 -m http.server 8000

# Update SUFeedURL in Info.plist temporarily
<string>http://localhost:8000/appcast.xml</string>
```

## Troubleshooting

### "Update check failed"
- Check internet connection
- Verify appcast.xml is accessible at the URL
- Check Xcode console for Sparkle errors

### "Invalid signature"
- Signature in appcast.xml must match the DMG
- Re-sign the DMG with `sign_update`
- Ensure public key in Info.plist matches your private key

### "App won't update"
- Check app is code-signed
- Check sandbox entitlements include network access
- Verify DMG URL is correct and accessible

## Additional Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle 2 Migration Guide](https://sparkle-project.org/documentation/sparkle-2/)
- [Appcast Format](https://sparkle-project.org/documentation/publishing/)
