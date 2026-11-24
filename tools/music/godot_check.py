"""python -m tools.music godot [names]: ask Godot whether the files loop.

Needs $GODOT (the Godot 4.7 binary).  Imports the project, then for each
piece loads the OGG, reads its loop flag, plays it from one second before the
end and checks that the playback position wraps to the start while it keeps
playing.  Writes a temporary script into godot/ named after the pieces and
removes it again.
"""
from __future__ import annotations

import hashlib
import os
import subprocess

from . import render

SCRIPT = '''extends SceneTree
var names := %s
var i := -1
var p: AudioStreamPlayer
var t := 0.0
var maxpos := 0.0
var wrapped := false
var failed := 0
func _init():
	p = AudioStreamPlayer.new()
	root.add_child(p)
func _next():
	i += 1
	if i >= names.size():
		print("GODOT LOOPS: ", "OK" if failed == 0 else "FAIL")
		quit(1 if failed else 0)
		return
	var s = load("res://assets/audio/%%s.ogg" %% names[i])
	if s == null:
		print("  ", names[i], ": cannot load"); failed += 1; _next(); return
	t = 0.0; maxpos = 0.0; wrapped = false
	p.stream = s
	p.play(s.get_length() - 1.0)
func _process(delta):
	if i < 0:
		_next(); return false
	t += delta
	var pos = p.get_playback_position()
	maxpos = max(maxpos, pos)
	if maxpos > p.stream.get_length() - 1.5 and pos < 1.5:
		wrapped = true
	if t > 2.5:
		var ok = p.stream.loop and wrapped and p.playing
		if not ok: failed += 1
		print("  ", names[i], ": loop=", p.stream.loop, " length=%%.3f s" %% p.stream.get_length(), " played across the loop point=", wrapped, " still playing=", p.playing, " -> ", "ok" if ok else "FAIL")
		_next()
	return false
'''


def run(names) -> int:
    godot = os.environ.get("GODOT")
    if not godot:
        print("set GODOT to the Godot 4.7 binary")
        return 2
    loops = [n for n in names if not render.is_example(n) and render.load_song(n).loop]
    tag = hashlib.sha1(",".join(loops).encode()).hexdigest()[:8]
    path = render.ROOT / "godot" / f"zz_music_loopcheck_{tag}.gd"
    path.write_text(SCRIPT % ("[" + ", ".join(f'"{n}"' for n in loops) + "]"))
    try:
        subprocess.run([godot, "--headless", "--path", str(render.ROOT / "godot"), "--import"],
                       capture_output=True, timeout=600)
        res = subprocess.run([godot, "--headless", "--path", str(render.ROOT / "godot"),
                              "--script", f"res://{path.name}"], capture_output=True, text=True, timeout=600)
        for line in res.stdout.splitlines():
            if line.startswith("  ") or line.startswith("GODOT"):
                print(line)
        return res.returncode
    finally:
        path.unlink(missing_ok=True)
        for extra in (path.with_name(path.name + ".uid"),):
            extra.unlink(missing_ok=True)
