#!/usr/bin/env bash
# Runs every headless test suite. Usage: tests/run_tests.sh [godot-binary]
# Default binary: E:/Godot/Godot_v4.4-stable_win64_console.exe (override with GODOT env var).
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-E:/Godot/Godot_v4.4-stable_win64_console.exe}}"
fail=0
"$GODOT" --headless --path . --import >/dev/null 2>&1
for scene in tests/*_test.tscn tests/scene_harness.tscn; do
	[ -f "$scene" ] || continue
	out=$("$GODOT" --headless --path . "res://$scene" 2>&1)
	code=$?
	if [ $code -ne 0 ]; then
		echo "FAIL $scene (exit $code)"; echo "$out" | grep -E "CHECK FAILED|MISSING|ERROR|SCRIPT ERROR|_FAILED" | head -40; fail=1
	else
		echo "ok   $scene  $(echo "$out" | grep -oE '[A-Z_]+_OK' | tail -1)"
	fi
done
out=$("$GODOT" --headless --path . --script res://tests/loc_test.gd 2>&1) || { echo "FAIL loc_test"; echo "$out"; fail=1; }
[ $fail -eq 0 ] && echo "$out" | grep -q LOC_OK && echo "ok   tests/loc_test.gd  LOC_OK"
exit $fail
