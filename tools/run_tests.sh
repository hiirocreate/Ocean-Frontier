#!/usr/bin/env bash
# 全自動テスト（データ検証 + ユニット/統合テスト）を実行する。
# 使い方: tools/run_tests.sh   （GODOT 環境変数で実行ファイルを指定可能）
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TIMEOUT="${TEST_TIMEOUT:-300}"
LOG="$(mktemp)"
status=0

timeout "$TIMEOUT" "$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== データ検証 =="
timeout "$TIMEOUT" "$GODOT" --headless --path . --script res://tools/validate_data.gd 2>&1 | tee "$LOG"
[ "${PIPESTATUS[0]}" -ne 0 ] && status=1

echo "== テスト =="
timeout "$TIMEOUT" "$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee -a "$LOG"
[ "${PIPESTATUS[0]}" -ne 0 ] && status=1

echo "== E2E（ヘッドレス） =="
timeout "$TIMEOUT" "$GODOT" --headless --path . --script res://tools/smoke_test.gd 2>&1 | grep -v 'Parameter "m" is null\|mesh_storage.h' | tee -a "$LOG"
[ "${PIPESTATUS[0]}" -ne 0 ] && status=1

# 実行時エラーはテストが成功扱いになるのを防ぐため検出して失敗にする
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG" >/dev/null; then
  echo "!! スクリプトエラーを検出しました"
  status=1
fi
rm -f "$LOG"
[ $status -eq 0 ] && echo "ALL OK" || echo "FAILED"
exit $status
