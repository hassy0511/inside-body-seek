"""The table of pieces in docs/audio.md (python -m tools.music table).

Only this command writes docs/audio.md; a build never does, so several
composers can build at the same time.  The numbers come from the committed
files in godot/assets/audio (not from the work folder), so the table can be
made on any machine that has the files.
"""
from __future__ import annotations

import re

import numpy as np
import soundfile as sf

from . import render
from .analyze import decode_ogg, music_files

DOC = render.ROOT / "docs" / "audio.md"
START = "<!-- music-table:start (python -m tools.music table) -->"
END = "<!-- music-table:end -->"


def rows():
    out = []
    for name in render.track_names():
        song = render.load_song(name)
        f = render.final_path(song)
        if not f.exists():
            out.append((song, None, None, None, None))
            continue
        if f.suffix == ".ogg":
            x = decode_ogg(f).astype(np.float64)
        else:
            x = sf.read(str(f), always_2d=True)[0]
        lu = render.loudness(np.repeat(x, 2, axis=1) if x.shape[1] == 1 else x)
        tp = render.true_peak_db(x)
        out.append((song, len(x) / render.SR, lu, tp, f.stat().st_size))
    return out


def markdown() -> str:
    L = [START, "",
         "| name | where | tempo | metre | key | bars | seconds | LUFS | true peak (dBTP) | bytes |",
         "|---|---|---|---|---|---|---|---|---|---|"]
    total = 0
    for song, sec, lu, tp, size in rows():
        key = f"{song.key_name} {song.mode}"
        if sec is None:
            L.append(f"| {song.name} | {song.where} | {song.tempo:g} | {song.meter[0]}/{song.meter[1]} | {key} | "
                     f"{song.bars} | (not built) | | | |")
            continue
        total += size
        L.append(f"| {song.name} | {song.where} | {song.tempo:g} | {song.meter[0]}/{song.meter[1]} | {key} | "
                 f"{song.bars} | {sec:.2f} | {lu:.1f} | {tp:.1f} | {size:,} |")
    all_bytes = sum(f.stat().st_size for f in music_files())
    L += ["", f"All music files in godot/assets/audio: {all_bytes:,} bytes (budget 8,000,000).", "", END]
    return "\n".join(L)


def write():
    text = DOC.read_text() if DOC.exists() else f"# Music\n\n{START}\n{END}\n"
    if START not in text:
        text += f"\n\n{START}\n{END}\n"
    new = re.sub(re.escape(START) + r".*?" + re.escape(END), lambda m: markdown(), text, flags=re.S)
    DOC.write_text(new)
    print(f"wrote the table in {DOC.relative_to(render.ROOT)}")
