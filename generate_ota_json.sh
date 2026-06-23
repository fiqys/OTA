#!/bin/bash

set -e

GITHUB_USER="fiqys"
GITHUB_REPO="OTA"
BUILDS_FILE="$(dirname "$0")/builds/a55x.json"
CHANGELOG_FILE="$(dirname "$0")/changelogs/a55x.txt"

ZIP_PATH="$1"
CI_MODE=false
TAG=""

if [[ "$2" == "--ci" ]]; then
    CI_MODE=true
    TAG="$3"
fi

if [[ -z "$ZIP_PATH" ]]; then
    echo "Usage (local): $0 <path_to_zip>"
    echo "Usage (CI):    $0 <path_to_zip> --ci <tag>"
    exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Error: File not found: $ZIP_PATH"
    exit 1
fi

if $CI_MODE && [[ -z "$TAG" ]]; then
    echo "Error: --ci mode requires a tag as the third argument."
    exit 1
fi

if ! $CI_MODE; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  LineageOS OTA Generator — fiqys/OTA"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Changelog
    echo "Enter changelog (type your changes, then press Ctrl+D when done):"
    echo "─────────────────────────────────────────"
    CHANGELOG_INPUT=$(cat)

    if [[ -n "$CHANGELOG_INPUT" ]]; then
        echo "$CHANGELOG_INPUT" > "$CHANGELOG_FILE"
        echo "✓ Changelog saved to changelogs/a55.txt"
    else
        echo "⚠ No changelog entered — keeping existing file."
    fi
    echo ""

    read -rp "Enter release tag (e.g. 23.2-20250623): " TAG
    if [[ -z "$TAG" ]]; then
        echo "Error: Tag cannot be empty."
        exit 1
    fi
fi

FILENAME=$(basename "$ZIP_PATH")
echo "Processing: $FILENAME"

BUILD_PROP=$(unzip -p "$ZIP_PATH" system/build.prop 2>/dev/null || true)

get_prop() {
    local key="$1"
    echo "$BUILD_PROP" | grep "^${key}=" | cut -d'=' -f2 | tr -d '\r'
}


VERSION=$(get_prop "ro.lineage.version")
if [[ -z "$VERSION" ]]; then
    VERSION=$(echo "$FILENAME" | sed -E 's/lineage-([0-9.]+)-.*/\1/')
fi

TIMESTAMP=$(get_prop "ro.build.date.utc")
if [[ -z "$TIMESTAMP" ]]; then
    TIMESTAMP=$(stat -c '%Y' "$ZIP_PATH" 2>/dev/null || stat -f '%m' "$ZIP_PATH" 2>/dev/null)
fi

echo "Computing MD5..."
if command -v md5sum &>/dev/null; then
    MD5=$(md5sum "$ZIP_PATH" | awk '{print $1}')
elif command -v md5 &>/dev/null; then
    MD5=$(md5 -q "$ZIP_PATH")
else
    echo "Error: neither md5sum nor md5 found."
    exit 1
fi

SIZE=$(stat -c '%s' "$ZIP_PATH" 2>/dev/null || stat -f '%z' "$ZIP_PATH" 2>/dev/null)

DOWNLOAD_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/${TAG}/${FILENAME}"

mkdir -p "$(dirname "$BUILDS_FILE")"

cat > "$BUILDS_FILE" <<EOF
{
	"response": [
		{
			"filename": "${FILENAME}",
			"download": "${DOWNLOAD_URL}",
			"timestamp": ${TIMESTAMP},
			"md5": "${MD5}",
			"size": ${SIZE},
			"version": "${VERSION}"
		}
	]
}
EOF

echo ""
echo "✓ Updated: builds/a55x.json"
echo ""
cat "$BUILDS_FILE"
