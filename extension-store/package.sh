#!/bin/bash
# Package the ScholarSync browser extension for Chrome Web Store submission.
# Run from the project root: bash extension-store/package.sh

set -e

SRC="ios-app/ScholarSync/ScholarSync Extension/Resources"
OUT="extension-store/scholarsync-extension"

rm -rf "$OUT" extension-store/scholarsync-extension.zip
mkdir -p "$OUT/images"

# Copy extension files
cp "$SRC/manifest.json" "$OUT/"
cp "$SRC/background.js" "$OUT/"
cp "$SRC/content.js" "$OUT/"
cp "$SRC/popup.html" "$OUT/"
cp "$SRC/popup.js" "$OUT/"

# Generate placeholder icons (replace with real icons before submission)
for size in 16 32 48 128; do
    # Create a simple SVG icon and convert concept — replace these with real PNGs
    echo "Placeholder: replace extension-store/scholarsync-extension/images/icon-${size}.png with a real ${size}x${size} PNG icon"
done

echo ""
echo "=== Extension packaged to: $OUT ==="
echo ""
echo "Before submitting to Chrome Web Store:"
echo "  1. Add icon PNGs to $OUT/images/ (icon-16.png, icon-32.png, icon-48.png, icon-128.png)"
echo "  2. Update the Supabase URL in popup.js if needed"
echo "  3. Zip the folder: cd $OUT && zip -r ../scholarsync-extension.zip ."
echo "  4. Upload at https://chrome.google.com/webstore/devconsole"
echo ""
echo "Store listing requirements:"
echo "  - Developer account: \$5 one-time at https://chrome.google.com/webstore/devconsole"
echo "  - Privacy policy URL: https://your-domain.com/privacy"
echo "  - At least 1 screenshot (1280x800 or 640x400)"
echo "  - Detailed description (see extension-store/STORE_LISTING.md)"
