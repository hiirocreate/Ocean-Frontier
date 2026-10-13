#!/usr/bin/env bash
# 実描画（Xvfb + OpenGL）でE2Eテストを実行し、build/screenshots/ に画面を保存する。
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --script res://tools/smoke_test.gd >"$LOG" 2>&1
status=$?
grep -E "  (OK|FAIL)|E2E|screenshot" "$LOG"
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Parameter \"[a-z_]+\" is null" "$LOG" >/dev/null; then
  echo "!! エラーを検出しました:"; grep -E "SCRIPT ERROR|Parse Error|Parameter \"" "$LOG" | sort | uniq -c | head
  status=1
fi
rm -f "$LOG"
exit $status
