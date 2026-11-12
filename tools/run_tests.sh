#!/usr/bin/env bash
# Godot をヘッドレスで起動して、インポート → 床プローブ → 自動プレイ（全カルテ ＋ 全部の 場所）→ ダッシュボードの 試し作り を行う。
#   使い方: GODOT=/path/to/godot tools/run_tests.sh [--stage=mouth | --episode=ep03]
#   合格: 「PROBE RESULT: OK」「RESULT: OK」「DASHBOARD: OK」が 出て、「SCRIPT ERROR」が 1 つも 出ない こと。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOG="${LOG:-/tmp/inside-body-seek-test.log}"
cd "$ROOT/godot"
echo "== import =="
"$GODOT" --headless --path . --import >"$LOG.import" 2>&1 || true
grep -E "SCRIPT ERROR|ERROR:" "$LOG.import" | grep -v -E "Draco|MeshOptimizer" | head -20
echo "== floor probe =="
"$GODOT" --headless --path . --script res://tests/probe.gd 2>&1 | grep -E "probe|PROBE|==" | head -40
echo "== smoke =="
"$GODOT" --headless --fixed-fps 60 --path . res://tests/smoke.tscn -- "$@" >"$LOG" 2>&1
code=$?
grep -E "SCRIPT ERROR|ERROR:|WARNING: .*(gd|tscn)|\[SMOKE FAIL\]" "$LOG" | sort | uniq -c | sort -rn | head -40
echo "---"
sed -n '/SMOKE SUMMARY/,$p' "$LOG"
# ダッシュボードを 試しに 作る（episode_db.gd / stage_db.gd の 書きかたが パーサと 合わなく なったら ここで 落ちる）
echo "== dashboard =="
if python3 "$ROOT/tools/build_dashboard.py" --html "$LOG.dash.html" --test-log "$LOG" >"$LOG.dash" 2>&1; then
  echo "DASHBOARD: OK"
else
  echo "DASHBOARD: FAILED"; tail -5 "$LOG.dash"; code=1
fi
if [ $code -ne 0 ]; then echo "exit code: $code"; fi
if grep -q -E "SCRIPT ERROR" "$LOG"; then echo "script errors found"; exit 1; fi
exit $code
