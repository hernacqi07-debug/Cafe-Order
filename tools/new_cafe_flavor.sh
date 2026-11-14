#!/usr/bin/env bash
#
# Adds a new white-label cafe flavor (Model B).
#
# Usage:
#   tools/new_cafe_flavor.sh <slug> "<App Name>" <application_id> \
#       [api_base_url] [primary_color] [secondary_color]
#
# Example:
#   tools/new_cafe_flavor.sh kopikenangan "Kopi Kenangan" com.serve.kopikenangan \
#       https://api.kopikenangan.serve.id "#6F4E37" "#C8A97E"
#
set -euo pipefail

SLUG="${1:?slug required, e.g. kopikenangan}"
APP_NAME="${2:?app name required, e.g. \"Kopi Kenangan\"}"
APP_ID="${3:?application id required, e.g. com.serve.kopikenangan}"
API_URL="${4:-https://api.example.com}"
PRIMARY="${5:-#6F4E37}"
SECONDARY="${6:-#C8A97E}"

if [[ ! "$SLUG" =~ ^[a-z0-9_]+$ ]]; then
  echo "error: slug must be lowercase alphanumeric/underscore" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

GRADLE_FILE="android/app/build.gradle.kts"
MARKER="__NEW_CAFE_FLAVORS__"

if grep -q "create(\"$SLUG\")" "$GRADLE_FILE"; then
  echo "error: flavor '$SLUG' already exists in $GRADLE_FILE" >&2
  exit 1
fi

read -r -d '' FLAVOR_BLOCK <<EOF || true
        create("$SLUG") {
            dimension = "default"
            applicationId = "$APP_ID"
            manifestPlaceholders["appName"] = "$APP_NAME"
        }
EOF

awk -v block="$FLAVOR_BLOCK" -v marker="$MARKER" '
  { if (index($0, marker)) print block; print }
' "$GRADLE_FILE" > "$GRADLE_FILE.tmp" && mv "$GRADLE_FILE.tmp" "$GRADLE_FILE"

mkdir -p "android/app/src/$SLUG"
cat > "android/app/src/$SLUG/README.md" <<EOF
# Flavor \`$SLUG\`

- App name: $APP_NAME
- Application ID: $APP_ID
- API base URL: $API_URL (inject via --dart-define at build time)

Per-flavor Android resources (custom launcher icon, etc.) go here,
e.g. \`res/mipmap-*/ic_launcher.png\`. Generate icons with
\`flutter_launcher_icons\` per flavor, or drop them in manually.
EOF

cat <<EOF

Flavor '$SLUG' added to $GRADLE_FILE.

Build it with:
  flutter build apk --flavor $SLUG --release \\
    --dart-define=APP_NAME="$APP_NAME" \\
    --dart-define=APP_ID=$APP_ID \\
    --dart-define=API_BASE_URL=$API_URL \\
    --dart-define=PRIMARY_COLOR=$PRIMARY \\
    --dart-define=SECONDARY_COLOR=$SECONDARY \\
    --dart-define=CAFE_NAME="$APP_NAME"

See docs/WHITE_LABEL.md for signing & Play Store checklist.
EOF
