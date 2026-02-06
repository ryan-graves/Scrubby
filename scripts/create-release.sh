#!/bin/bash
set -e

# FileScrubby Release Script
# This script automates the process of creating a new release with Sparkle updates

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="FileScrubby"
RELEASES_DIR="$PROJECT_ROOT/Releases"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/ryan-graves/Scrubby/refs/heads/main/Releases"

echo -e "${GREEN}🚀 FileScrubby Release Script${NC}"
echo "================================"

# Check if Sparkle's tools are available
# First check standard PATH, then check Homebrew Caskroom location
if command -v generate_appcast &> /dev/null; then
    GENERATE_APPCAST="generate_appcast"
elif [ -f "/opt/homebrew/Caskroom/sparkle/2.8.1/bin/generate_appcast" ]; then
    GENERATE_APPCAST="/opt/homebrew/Caskroom/sparkle/2.8.1/bin/generate_appcast"
elif [ -f "/usr/local/Caskroom/sparkle/2.8.1/bin/generate_appcast" ]; then
    GENERATE_APPCAST="/usr/local/Caskroom/sparkle/2.8.1/bin/generate_appcast"
else
    # Try to find it anywhere in Homebrew
    SPARKLE_BIN=$(find /opt/homebrew/Caskroom/sparkle -name generate_appcast 2>/dev/null | head -1)
    if [ -n "$SPARKLE_BIN" ]; then
        GENERATE_APPCAST="$SPARKLE_BIN"
    else
        echo -e "${RED}❌ Sparkle tools not found!${NC}"
        echo "Install Sparkle CLI tools:"
        echo "  brew install sparkle"
        echo "  Or download from: https://sparkle-project.org"
        exit 1
    fi
fi

echo -e "${GREEN}Using Sparkle tool: $GENERATE_APPCAST${NC}"

# Get version from user
read -p "Enter version number (e.g., 1.2): " VERSION
read -p "Enter build number (e.g., 11): " BUILD

if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo -e "${RED}❌ Version and build number are required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📦 Version: $VERSION (Build $BUILD)${NC}"
echo ""

# Step 1: Build the app
echo -e "${GREEN}Step 1: Building app...${NC}"
xcodebuild -project "$PROJECT_ROOT/FileScrubby.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$PROJECT_ROOT/build" \
    clean build

APP_PATH="$PROJECT_ROOT/build/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Build failed - app not found at $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

# Step 2: Create DMG
echo -e "${GREEN}Step 2: Creating DMG...${NC}"
DMG_PATH="$RELEASES_DIR/${APP_NAME}-${VERSION}.dmg"
TEMP_DMG="$RELEASES_DIR/temp.dmg"

# Remove old DMG if exists
rm -f "$DMG_PATH" "$TEMP_DMG"

# Create DMG using hdiutil
mkdir -p "$RELEASES_DIR/dmg-temp"
cp -R "$APP_PATH" "$RELEASES_DIR/dmg-temp/"

hdiutil create -volname "$APP_NAME $VERSION" \
    -srcfolder "$RELEASES_DIR/dmg-temp" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$RELEASES_DIR/dmg-temp"

echo -e "${GREEN}✅ DMG created: $DMG_PATH${NC}"

# Step 3: Generate appcast
echo -e "${GREEN}Step 3: Generating appcast...${NC}"

# Check for private key
PRIVATE_KEY="$HOME/.sparkle_private_key"
if [ ! -f "$PRIVATE_KEY" ]; then
    echo -e "${YELLOW}⚠️  Private key not found at $PRIVATE_KEY${NC}"
    echo "Looking for sparkle_key in project..."
    PRIVATE_KEY="$PROJECT_ROOT/sparkle_key"
    if [ ! -f "$PRIVATE_KEY" ]; then
        echo -e "${RED}❌ Cannot find Sparkle private key!${NC}"
        echo "Place your private key at: $HOME/.sparkle_private_key"
        echo "Or at: $PROJECT_ROOT/sparkle_key"
        exit 1
    fi
fi

# Generate appcast using Sparkle's tool
cd "$RELEASES_DIR"
"$GENERATE_APPCAST" --ed-key-file "$PRIVATE_KEY" \
    --download-url-prefix "$GITHUB_RAW_BASE/" \
    --full-release-notes-url "$GITHUB_RAW_BASE/release-notes-$VERSION.html" \
    "$RELEASES_DIR"

echo -e "${GREEN}✅ Appcast generated${NC}"

# Step 4: Get file size and signature (from generated appcast)
DMG_SIZE=$(stat -f%z "$DMG_PATH")
echo -e "${GREEN}✅ DMG size: $DMG_SIZE bytes${NC}"

# Step 5: Show next steps
echo ""
echo -e "${GREEN}🎉 Release prepared successfully!${NC}"
echo "================================"
echo ""
echo "Next steps:"
echo "1. Review the updated appcast.xml"
echo "2. Commit changes:"
echo "   git add Releases/appcast.xml Releases/${APP_NAME}-${VERSION}.dmg"
echo "   git commit -m 'Release version $VERSION (build $BUILD)'"
echo "3. Push to GitHub:"
echo "   git push origin main"
echo "4. Create a GitHub release (optional):"
echo "   gh release create v$VERSION Releases/${APP_NAME}-${VERSION}.dmg"
echo ""
echo "Update URL: $GITHUB_RAW_BASE/${APP_NAME}-${VERSION}.dmg"
echo ""
