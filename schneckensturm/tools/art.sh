#!/usr/bin/env bash
# Raw Flux images → game. art_raw/<category>/<name>.png (see ASSETS.md) are keyed,
# scaled and turned into tilesets/icons, imported and wired into the content .tres.
# Usage: bash tools/art.sh [--all]     (--all reprocesses unchanged images too)
# Godot binary: GODOT env var, default E:/Godot/Godot_v4.4-stable_win64_console.exe
cd "$(dirname "$0")/.."
GODOT="${GODOT:-E:/Godot/Godot_v4.4-stable_win64_console.exe}"
"$GODOT" --headless --path . --import >/dev/null 2>&1   # class cache (ChromaKey, IsoTiles)
"$GODOT" --headless --path . --script res://tools/process_art.gd -- "$@" 2>&1 | grep -E "wrote|PROCESS_ART_DONE|ERROR"
"$GODOT" --headless --path . --import >/dev/null 2>&1   # the new PNG/JPG files
"$GODOT" --headless --path . --script res://tools/link_art.gd 2>&1 | grep -E "LINK_ART_DONE|ERROR"
echo "Fertig – Spiel mit F5 starten."
