# FileScrubby Release Guide

Quick reference for creating new releases.

## 🚀 Quick Start

### Option 1: Automated Script (Easiest)

```bash
./scripts/create-release.sh
```

Follow the prompts and it handles everything!

### Option 2: GitHub Actions (Best for CI/CD)

1. Go to GitHub Actions tab
2. Select "Create Release" workflow
3. Click "Run workflow"
4. Enter version and build number
5. Done! The release is created automatically

### Option 3: Manual

See `Releases/README.md` for detailed manual steps.

---

## 📋 Pre-Release Checklist

- [ ] All changes committed and pushed
- [ ] Tests passing
- [ ] Update version numbers in Xcode:
  - Target → General → Identity
  - Version: `1.2` (user-facing)
  - Build: `11` (increment each release)
- [ ] Update release notes if needed
- [ ] Test the app locally

---

## 🔐 First-Time Setup

### 1. Install Sparkle Tools
```bash
brew install sparkle
```

### 2. Locate Your Private Key
Your Sparkle EdDSA private key should be at one of these locations:
- `~/.sparkle_private_key` (recommended)
- `~/sparkle_key`

**⚠️ IMPORTANT:** Never commit this key to git!

If you don't have it:
```bash
# Generate a new key pair (only if you lost the original)
generate_keys

# This creates:
# - Public key (add to Info.plist as SUPublicEDKey)
# - Private key (keep secret!)
```

**Note:** If you generate a new key pair, existing installations won't be able to update! Only do this for a new app or if absolutely necessary.

### 3. For GitHub Actions (Optional)
Add your private key as a GitHub secret:
1. Go to repo Settings → Secrets and variables → Actions
2. Create secret: `SPARKLE_PRIVATE_KEY`
3. Paste your entire private key

---

## 📝 Version Numbering Strategy

- **Major release** (breaking changes): `1.0` → `2.0`
- **Minor release** (new features): `1.0` → `1.1`
- **Patch release** (bug fixes): `1.1` → `1.1.1`

Build numbers always increment: `9`, `10`, `11`, `12`...

---

## 🧪 Testing Updates Locally

### Test before releasing:
1. Build your new version
2. Install the current production version
3. Run the new build
4. Check: FileScrubby menu → Check for Updates...

### Serve appcast locally for testing:
```bash
cd Releases
python3 -m http.server 8000

# Temporarily change SUFeedURL in FileScrubby-Info.plist:
# <string>http://localhost:8000/appcast.xml</string>
```

---

## 🐛 Common Issues

### "Command not found: generate_appcast"
```bash
brew install sparkle
# or download from: https://sparkle-project.org
```

### "Cannot find private key"
Place your key at `~/.sparkle_private_key` or `./sparkle_key`

### "Signature verification failed"
- Re-sign the DMG: `sign_update YourApp.dmg --ed-key-file ~/.sparkle_private_key`
- Ensure public key in Info.plist matches your private key

### Updates not showing in app
- Check appcast.xml is accessible at the feed URL
- Verify new version number is higher than current
- Check Xcode console for Sparkle error messages

---

## 📚 More Information

- Detailed manual process: `Releases/README.md`
- Sparkle docs: https://sparkle-project.org/documentation/
- Script source: `scripts/create-release.sh`

---

## 🎯 Typical Release Workflow

1. **Develop** on feature branch
2. **Merge** to main
3. **Update** version/build in Xcode
4. **Run** `./scripts/create-release.sh`
5. **Review** generated files
6. **Commit & push**:
   ```bash
   git add Releases/
   git commit -m "Release v1.2"
   git push
   ```
7. **Announce** 🎉

---

## 📫 Distribution URLs

- **Appcast feed:** https://raw.githubusercontent.com/ryan-graves/Scrubby/refs/heads/main/Releases/appcast.xml
- **Latest DMG:** https://raw.githubusercontent.com/ryan-graves/Scrubby/refs/heads/main/Releases/FileScrubby.dmg
- **Version-specific:** https://raw.githubusercontent.com/ryan-graves/Scrubby/refs/heads/main/Releases/FileScrubby-{version}.dmg
