#!/usr/bin/env bash
# Godot をヘッドレスで起動して、インポート → 全ステージ自動プレイのテストを行う。
#   使い方: GODOT=/path/to/godot tools/run_tests.sh [--stage=mouth]
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
if [ $code -ne 0 ]; then echo "exit code: $code"; fi
if grep -q -E "SCRIPT ERROR" "$LOG"; then echo "script errors found"; exit 1; fi
exit $code
