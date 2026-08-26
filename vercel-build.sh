#!/usr/bin/env bash
# Vercel build step for this Flutter web app. Vercel has no Flutter/Dart
# preset and no Flutter SDK preinstalled in its build image, so this script
# fetches the SDK fresh, then runs the real build. Invoked via vercel.json's
# "buildCommand": "bash vercel-build.sh".
set -euo pipefail

# Fail loudly at build time (not with a silent "configuration missing"
# screen at runtime — see lib/core/config/app_config.dart /
# ConfigMissingApp) if these weren't set in the Vercel dashboard.
: "${SUPABASE_URL:?SUPABASE_URL is not set — add it in Vercel Project Settings > Environment Variables}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is not set — add it in Vercel Project Settings > Environment Variables}"

# Pinned to the `stable` channel rather than an exact release so this
# keeps working as pubspec.yaml's `sdk: ^3.10.4` constraint is satisfied by
# whatever the current stable release is. For fully reproducible builds,
# pin an exact tag instead, e.g. `--branch 3.35.5`.
git clone https://github.com/flutter/flutter.git --branch stable --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter config --no-analytics --enable-web
flutter --version
flutter pub get

flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
