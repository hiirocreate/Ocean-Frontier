#!/usr/bin/env bash
# Android 用 APK を作成する（デバッグ署名）。
# 前提: Godot 4.3 / エクスポートテンプレート 4.3.stable / Android SDK（platform-tools, build-tools 34）/ JDK 17以上
#       エディタ設定（~/.config/godot/editor_settings-4.3.tres）に SDK・JDK・デバッグキーストアのパスを設定済み
# 使い方: tools/build_android.sh [debug|release]
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MODE="${1:-debug}"
mkdir -p build/android
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
OUT="build/android/ocean_frontier_${MODE}.apk"
if [ "$MODE" = "release" ]; then
  # リリース署名には GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD 環境変数が必要（リポジトリには保存しない）
  "$GODOT" --headless --path . --export-release "Android" "$OUT"
else
  "$GODOT" --headless --path . --export-debug "Android" "$OUT"
fi
ls -la "$OUT"
echo "APK: $OUT"
