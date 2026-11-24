"""Checks and a report for one built piece.

Audio checks FAIL the build (they guard what the player hears: clicks, gaps,
loudness, peaks, length, file size).  Score checks are WARNINGS in the report
(they point at places worth a second look; music may break a rule on purpose).

Writes tools/music/out/<name>/report.md, stats.json, roll.png,
spectrogram.png and seam.png.
"""
from __future__ import annotations

import json
import subprocess
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

from . import render
from .render import SR, ROOT, AUDIO, load_song, out_dir, final_path, loop_samples
from .score import name_of, chord as parse_chord

BUDGET_TOTAL = 8_000_000           # all music files together (bytes)
LOOP_BYTES_PER_S = 12_000          # a loop's share of the budget (~96 kbit/s)
SHORT_BYTES = {"ogg": 90_000, "wav_mono": 330_000}
TP_MAX = -1.5
LU_TOL = 0.5
SILENCE_MAX_S = 0.4

# practical sounding ranges (MIDI) per GM program, for the range warning
RANGES = {
    0: (21, 108), 1: (21, 108), 2: (21, 108), 4: (28, 103), 5: (28, 103), 6: (29, 89),
    7: (36, 89), 8: (60, 108), 9: (79, 108), 10: (60, 100), 11: (53, 89), 12: (45, 96),
    13: (65, 108), 14: (60, 77), 15: (48, 96), 16: (36, 96), 21: (41, 89), 22: (60, 84),
    24: (40, 83), 25: (40, 84), 26: (40, 84), 27: (40, 86), 32: (28, 60), 33: (28, 67),
    34: (28, 67), 35: (28, 67), 36: (28, 67), 38: (24, 60), 40: (55, 100), 41: (48, 88),
    42: (36, 76), 43: (28, 60), 44: (28, 100), 45: (28, 96), 46: (24, 103), 47: (38, 57),
    48: (28, 100), 49: (28, 100), 50: (28, 100), 52: (48, 81), 53: (48, 81), 56: (52, 86),
    57: (40, 72), 58: (28, 58), 59: (52, 79), 60: (34, 77), 61: (34, 82), 64: (56, 88),
    65: (49, 81), 66: (44, 76), 67: (36, 69), 68: (58, 91), 69: (52, 81), 70: (34, 75),
    71: (50, 94), 72: (74, 108), 73: (60, 96), 74: (72, 98), 75: (60, 96), 78: (72, 96),
    79: (60, 86), 80: (36, 96), 81: (36, 96), 82: (48, 96), 83: (48, 96), 89: (36, 96),
    90: (36, 96), 91: (36, 96), 94: (36, 96), 98: (48, 96), 108: (60, 88), 114: (55, 88),
}


def _rms_db(x):
    return 20 * np.log10(max(1e-12, float(np.sqrt(np.mean(np.square(x))))))


# ---------------------------------------------------------------------------
# Audio checks
# ---------------------------------------------------------------------------

def _lpc_click(end: np.ndarray, start: np.ndarray, p: int = 24, n: int = 2205,
               nref: int = 8820) -> float:
    """How unpredictable the first samples after a join are.

    A linear predictor (order p) is fitted on the 50 ms before the join and
    run over the 200 ms before it and across it.  The result is the largest
    prediction error in the first 4 samples after the join, divided by six
    times the median error over the 200 ms before the join (a median, so a
    drum roll at the end of the loop cannot raise the reference and hide a
    jump).  Continuous sound gives about 0.1..1; a click gives 2 to 20."""
    from scipy.linalg import solve_toeplitz
    worst = 0.0
    nref = max(nref, n)
    for ch in range(end.shape[1]):
        j = np.concatenate([end[-nref:, ch], start[:n, ch]]).astype(np.float64)
        fit = j[nref - n:nref]
        r = np.correlate(fit, fit, "full")[n - 1: n + p]
        r[0] = r[0] * 1.0001 + 1e-12
        a = solve_toeplitz(r[:p], r[1:p + 1])
        pred = np.zeros_like(j)
        for k in range(1, p + 1):
            pred[p:] += a[k - 1] * j[p - k: len(j) - k]
        e = np.abs(j - pred)
        seam = e[nref: nref + 4].max()
        ref = 6.0 * np.median(e[p:nref])
        worst = max(worst, float(seam / max(ref, 1e-9)))
    return worst


def _onset_env(m: np.ndarray, hop: int = 32, win: int = 512):
    """Spectral flux (positive log-magnitude increase), one value per hop."""
    _, _, Z = signal.stft(m, SR, window="hann", nperseg=win, noverlap=win - hop,
                          boundary=None, padded=False)
    M = np.log1p(1000 * np.abs(Z))
    d = np.maximum(0, np.diff(M, axis=1)).sum(axis=0)
    return (np.arange(len(d)) + 1) * hop + win / 2, d


def _best_shift(c, d, pos, w, lim):
    """The shift (samples, within +-lim) that puts the most onset energy under pos."""
    dl = np.arange(-lim, lim, 2.0)
    sc = (np.interp(pos[:, None] + dl[None, :], c, d) * w[:, None]).sum(axis=0)
    return float(dl[int(np.argmax(sc))])


def seam_timing(x: np.ndarray, song, data: dict) -> dict | None:
    """Do the drums of the last bar sit on the beat grid counted back from the
    END of the file?  (A loop cut short, or shifted, moves them off it.)

    Each drum sound reaches its onset peak a little after its note-on, and
    that delay differs per sound, so it is measured first for each drum used
    in the last bar, from all its notes in bars 2..N-1 (positions counted
    from the start of the file).  Then the last bar's notes, at their written
    (realised) times counted from the end of the file plus their sound's
    delay, are matched against the onset curve across the loop point.
    Returns {"timing_ms": offset} or None when the last bar has no drums."""
    if x.ndim == 1:
        x = x[:, None]
    beat = SR * 60.0 / song.quarter_bpm * song.beat_quarters
    bpb, total = song.beats_per_bar, song.total_beats
    n = len(x)
    W = int(beat * (bpb + 1))
    m = x.mean(axis=1)
    c, d = _onset_env(np.concatenate([m[-W:], m, m[:W]]))
    lead = render.SEAM_LEAD
    notes = [q for p in data["parts"] if p["drums"] for q in p["notes"]]
    last0 = total - bpb
    lim = beat / 4
    bias = {}
    for pc in {q["pitch"] for q in notes if q["t_written"] >= last0}:
        ev = [q for q in notes if q["pitch"] == pc and bpb <= q["t_written"] < last0]
        if len(ev) < 4:
            continue
        pos = np.array([W + lead + q["t"] * beat for q in ev])
        w = np.array([q["vel"] / 127 for q in ev])
        bias[pc] = _best_shift(c, d, pos, w, lim)
    ev = [q for q in notes if q["t_written"] >= last0 and q["pitch"] in bias]
    if not ev:
        return None
    pos = np.array([W + n + lead + (q["t"] - total) * beat + bias[q["pitch"]] for q in ev])
    w = np.array([q["vel"] / 127 for q in ev])
    return {"timing_ms": _best_shift(c, d, pos, w, lim) / SR * 1000, "drum_notes": len(ev)}


def seam_metrics(x: np.ndarray, song=None, data: dict | None = None) -> dict:
    """How the end of a loop joins its start.

    click: prediction error just after the loop point against the error
      before it (see _lpc_click).  Fails above SEAM_CLICK_MAX.
    drop: dB of the first 2 ms after the loop point minus the last 2 ms
      before it.  A loop whose ring is missing at the start (the first pass
      used instead of the second) drops by 20 dB or more.  Fails below -10.
    timing: (with song and score data) how far the last bar's drums sit off
      the beat grid counted from the end of the file (seam_timing).  Fails
      beyond SEAM_TIMING_MS.
    jump: the step from the last sample to the first divided by the largest
      step between neighbours in the 50 ms around (for information).
    level: dB of the 20 ms after the start minus the 20 ms before the end
      (for information: positive when the downbeat is louder)."""
    if x.ndim == 1:
        x = x[:, None]
    n = int(0.05 * SR)
    around = np.concatenate([x[-n:], x[:n]])
    d1 = np.abs(np.diff(around, axis=0))
    seam1 = d1[n - 1].max()
    ref1 = np.delete(d1, n - 1, axis=0).max()
    w2 = int(0.002 * SR)
    w = int(0.02 * SR)
    out = {"click": _lpc_click(x, x),
           "drop": float(_rms_db(x[:w2]) - _rms_db(x[-w2:])),
           "jump": float(seam1 / max(ref1, 1e-9)),
           "level": float(_rms_db(x[:w]) - _rms_db(x[-w:]))}
    if song is not None and data is not None:
        t = seam_timing(x, song, data)
        if t is not None:
            out["timing"] = t["timing_ms"]
    return out


SEAM_CLICK_MAX = 2.0
SEAM_DROP_MIN = -10.0
SEAM_TIMING_MS = 3.0


def seam_fails(m: dict, what: str = "loop seam") -> list[str]:
    out = []
    if m["click"] > SEAM_CLICK_MAX:
        out.append(f"{what}: the sound after the loop point is {m['click']:.1f}x less predictable "
                   f"than the sound before it (limit {SEAM_CLICK_MAX}) - a click")
    if m["drop"] < SEAM_DROP_MIN:
        out.append(f"{what}: the level drops {-m['drop']:.1f} dB across the loop point "
                   f"(limit {-SEAM_DROP_MIN:g}) - the ring of the end is missing at the start")
    if "timing" in m and abs(m["timing"]) > SEAM_TIMING_MS:
        out.append(f"{what}: the drums of the last bar sit {m['timing']:+.1f} ms off the beat grid "
                   f"counted from the end of the file (limit {SEAM_TIMING_MS:g} ms) - the loop is cut "
                   "at the wrong place")
    return out


def longest_silence(x: np.ndarray) -> float:
    """Longest run (seconds) of digital silence (all channels below 1 LSB of 16 bit)."""
    quiet = (np.abs(x).max(axis=1) < 1.0 / 32768)
    if not quiet.any():
        return 0.0
    q = np.concatenate([[0], quiet.astype(np.int8), [0]])
    d = np.diff(q)
    starts, ends = np.where(d == 1)[0], np.where(d == -1)[0]
    return float((ends - starts).max() / SR)


def band_shares(x: np.ndarray) -> dict:
    mid = x.mean(axis=1)
    f, pxx = signal.welch(mid, SR, nperseg=8192)
    tot = pxx[(f >= 20)].sum()

    def share(a, b):
        return float(pxx[(f >= a) & (f < b)].sum() / tot)
    return {"low": share(20, 250), "mid": share(250, 4000), "high": share(4000, 20000),
            "harsh": share(2000, 5000), "sub": share(20, 60)}


def decode_ogg(path: Path) -> np.ndarray:
    res = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", str(path),
                          "-f", "f32le", "-acodec", "pcm_f32le", "-"], capture_output=True, check=True)
    ch = int(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                             "stream=channels", "-of", "csv=p=0", str(path)],
                            capture_output=True, text=True, check=True).stdout.strip())
    return np.frombuffer(res.stdout, dtype=np.float32).reshape(-1, ch)


def music_files() -> list[Path]:
    """Every music file in godot/assets/audio (BGM, jingles, clear.wav)."""
    out = sorted(AUDIO.glob("bgm_*.ogg")) + sorted(AUDIO.glob("jingle_*.ogg"))
    if (AUDIO / "clear.wav").exists():
        out.append(AUDIO / "clear.wav")
    return out


def audio_checks(song, x: np.ndarray, final: Path, data: dict | None = None) -> tuple[list, list, dict]:
    fails, warns, st = [], [], {}
    want = loop_samples(song) if song.loop else loop_samples(song) + int(song.tail * SR)
    st["samples"] = len(x)
    st["seconds"] = len(x) / SR
    if len(x) != want:
        fails.append(f"length: {len(x)} samples, the bars need {want}")
    # a mono file plays from both speakers: measure it as two equal channels
    lu = render.loudness(np.repeat(x, 2, axis=1) if x.shape[1] == 1 else x)
    st["lufs"] = lu
    target = render.LOOP_LUFS if song.loop else render.SHORT_LUFS
    st["target"] = target
    if not abs(lu - target) <= LU_TOL:
        fails.append(f"loudness {lu:.2f} LUFS, target {target} +-{LU_TOL}")
    tp = render.true_peak_db(x)
    st["true_peak"] = tp
    st["sample_peak"] = float(20 * np.log10(max(1e-12, np.abs(x).max())))
    if tp > TP_MAX:
        fails.append(f"true peak {tp:.2f} dBTP (limit {TP_MAX})")
    if song.loop:
        m = seam_metrics(x, song, data)
        st["seam"] = m
        fails += seam_fails(m)
        sil = longest_silence(x)
    else:
        body = x[: loop_samples(song)]
        sil = longest_silence(body)
    st["longest_silence"] = sil
    if sil > SILENCE_MAX_S:
        fails.append(f"digital silence of {sil:.2f} s inside the music (limit {SILENCE_MAX_S})")
    dc = float(np.abs(x.mean(axis=0)).max())
    st["dc"] = dc
    if dc > 0.002:
        fails.append(f"DC offset {dc:.4f}")
    if song.output != "wav_mono":
        if x.shape[1] < 2:
            fails.append("mono file (stereo wanted)")
        else:
            side = _rms_db((x[:, 0] - x[:, 1]) / 2)
            midd = _rms_db((x[:, 0] + x[:, 1]) / 2)
            st["side_db"] = side - midd
            if side - midd < -40:
                fails.append(f"practically mono: side is {side - midd:.1f} dB below mid")
    bands = band_shares(x)
    st["bands"] = bands
    if bands["low"] > 0.85 or bands["mid"] < 0.08 or bands["high"] < 0.002 or bands["high"] > 0.35:
        fails.append("energy spread: low {low:.0%} mid {mid:.0%} high {high:.1%} (limits: low <= 85%, "
                     "mid >= 8%, high 0.2%..35%)".format(**bands))
    if bands["harsh"] > 0.10:
        warns.append(f"mix: {bands['harsh']:.0%} of the energy is in 2-5 kHz (above 10 %: may tire the ear)")
    if bands["low"] > 0.70:
        warns.append(f"mix: {bands['low']:.0%} of the energy is below 250 Hz (heavy low end)")
    if bands["sub"] > 0.15:
        warns.append(f"mix: {bands['sub']:.0%} of the energy is below 60 Hz (rumble)")
    # the committed file
    if not final.exists():
        fails.append(f"missing {final}")
    else:
        size = final.stat().st_size
        st["bytes"] = size
        if final.suffix == ".ogg":
            y = decode_ogg(final)
            st["ogg_samples"] = len(y)
            if len(y) != len(x):
                fails.append(f"OGG decodes to {len(y)} samples, the WAV has {len(x)}")
            yf = y.astype(np.float64)
            st["ogg_true_peak"] = render.true_peak_db(yf)
            if st["ogg_true_peak"] > TP_MAX:
                fails.append(f"the OGG's true peak is {st['ogg_true_peak']:.2f} dBTP after encoding (limit {TP_MAX})")
            if song.loop and len(y) == len(x):
                # the seam the game plays is the OGG's, not the WAV's
                mo = seam_metrics(yf)
                st["ogg_seam"] = mo
                fails += seam_fails({k: v for k, v in mo.items() if k != "timing"}, "OGG loop seam")
            if song.loop:
                allow = int(LOOP_BYTES_PER_S * len(x) / SR)
            else:
                allow = SHORT_BYTES["ogg"]
        else:
            y, _ = sf.read(str(final), always_2d=True)
            if len(y) != len(x):
                fails.append(f"{final.name} has {len(y)} samples, the work WAV {len(x)}")
            if song.output == "wav_mono" and y.shape[1] != 1:
                fails.append(f"{final.name} must be mono")
            allow = SHORT_BYTES["wav_mono"]
        st["allowance"] = allow
        if size > allow and not render.is_example(song.name):
            fails.append(f"size {size} bytes, this piece's share of the budget is {allow}")
        imp = final.with_name(final.name + ".import")
        if not render.is_example(song.name):
            if not imp.exists():
                fails.append(f"missing {imp.name}")
            else:
                t = imp.read_text()
                want_loop = "true" if song.loop else "false"
                if final.suffix == ".ogg" and f"loop={want_loop}" not in t:
                    fails.append(f"{imp.name}: loop should be {want_loop}")
    total = sum(f.stat().st_size for f in music_files())
    st["budget_total"] = total
    if total > BUDGET_TOTAL:
        fails.append(f"all music files together are {total} bytes (budget {BUDGET_TOTAL})")
    return fails, warns, st


# ---------------------------------------------------------------------------
# Score checks (warnings)
# ---------------------------------------------------------------------------

def score_checks(song, data: dict) -> tuple[list, dict]:
    warns, st = [], {}
    bpb = song.beats_per_bar
    strong = song.strong_beats()

    def where(t):
        b, beat = song.where_is(t)
        return f"bar {b} beat {beat:g}"

    parts = data["parts"]
    mel = [p for p in parts if p["role"] == "melody"]
    pitched = [p for p in parts if not p["drums"]]
    if not mel:
        warns.append("no part has role='melody' (the melody checks are skipped)")

    # 1. out of the scale, not marked and not in the chord
    out = []
    for p in pitched:
        for n in p["notes"]:
            t = n["t_written"]
            if n["ok"]:
                continue
            ch = song.chord_at(t)
            if n["pitch"] % 12 in song.scale_pcs(t):
                continue
            if ch is not None and n["pitch"] % 12 in ch.pcs:
                continue
            out.append(f"{p['name']} {name_of(n['pitch'])} at {where(t)}")
    if out:
        warns.append(f"{len(out)} note(s) outside the scale and the chord, not marked '*': " + "; ".join(out[:8]))
    st["out_of_scale"] = len(out)

    # 2. melody on strong beats: chord tones?
    nct = []
    for p in mel:
        for n in p["notes"]:
            t = n["t_written"]
            pos = round((t % bpb) * 1000) / 1000
            if pos in strong and not n["ok"]:
                ch = song.chord_at(t)
                if ch is not None and n["pitch"] % 12 not in ch.pcs:
                    nct.append(f"{name_of(n['pitch'])} over {ch.symbol} at {where(t)}")
    if nct:
        warns.append(f"{len(nct)} melody note(s) on strong beats are not chord tones (mark '*' if meant): " + "; ".join(nct[:8]))
    st["melody_nct_strong"] = len(nct)

    # 3. minor 2nds / minor 9ths held (an eighth note or longer) against the melody
    clashes = []
    for p in mel:
        for n in p["notes"]:
            a0, a1 = n["t_written"], n["t_written"] + n["dur_written"]
            for o in pitched:
                if o is p:
                    continue
                for m in o["notes"]:
                    b0, b1 = m["t_written"], m["t_written"] + m["dur_written"]
                    ov = min(a1, b1) - max(a0, b0)
                    if ov >= 0.5 / song.beat_quarters - 1e-6 and \
                            abs(n["pitch"] - m["pitch"]) in (1, 13, 25):
                        clashes.append(f"{name_of(n['pitch'])} vs {o['name']} {name_of(m['pitch'])} at {where(max(a0, b0))}")
    if clashes:
        warns.append(f"{len(clashes)} minor 2nd/9th held against the melody: " + "; ".join(clashes[:8]))
    st["clashes"] = len(clashes)

    # 4. bass against the chord
    bad_bass = []
    for p in parts:
        if p["role"] != "bass":
            continue
        for n in p["notes"]:
            t = n["t_written"]
            pos = round((t % bpb) * 1000) / 1000
            if pos in strong:
                ch = song.chord_at(t)
                if ch is not None and n["pitch"] % 12 not in ch.pcs:
                    bad_bass.append(f"{name_of(n['pitch'])} under {ch.symbol} at {where(t)}")
    if bad_bass:
        warns.append(f"{len(bad_bass)} bass note(s) on strong beats outside the chord: " + "; ".join(bad_bass[:8]))
    st["bass_outside"] = len(bad_bass)

    # 5. ranges
    rng_w = []
    for p in pitched:
        r = RANGES.get(p["program"])
        if not r or not p["notes"]:
            continue
        lo = min(n["pitch"] for n in p["notes"])
        hi = max(n["pitch"] for n in p["notes"])
        if lo < r[0] or hi > r[1]:
            rng_w.append(f"{p['name']} plays {name_of(lo)}..{name_of(hi)}, real range {name_of(r[0])}..{name_of(r[1])}")
    if rng_w:
        warns.append("outside the instrument's range: " + "; ".join(rng_w))

    # 6. melody range
    if mel:
        allp = [n["pitch"] for p in mel for n in p["notes"]]
        if allp:
            lo, hi = min(allp), max(allp)
            st["melody_range"] = [name_of(lo), name_of(hi), hi - lo]
            if hi - lo > 19:
                warns.append(f"melody spans {hi - lo} semitones ({name_of(lo)}..{name_of(hi)}): hard to hum")
            if hi > 96:
                warns.append(f"melody reaches {name_of(hi)}: may turn shrill")

    # 7. repeated bars
    sigs = []
    for b in range(1, song.bars + 1):
        t0, t1 = song.at(b), song.at(b + 1)
        sig = []
        for p in parts:
            for n in p["notes"]:
                if t0 - 1e-6 <= n["t_written"] < t1 - 1e-6:
                    sig.append((p["name"], round(n["t_written"] - t0, 3), round(n["dur_written"], 3), n["pitch"]))
        sigs.append(tuple(sorted(sig)))
    same_prev = [b + 1 for b in range(1, len(sigs)) if sigs[b] == sigs[b - 1] and sigs[b]]
    distinct = len(set(sigs))
    st["distinct_bars"] = distinct
    if same_prev:
        warns.append(f"bars that repeat the bar before exactly (all parts): {same_prev}")
    if distinct < song.bars * 0.6:
        warns.append(f"only {distinct} different bars out of {song.bars}")
    for p in mel:
        ms = []
        for b in range(1, song.bars + 1):
            t0, t1 = song.at(b), song.at(b + 1)
            ms.append(tuple((round(n["t_written"] - t0, 3), n["pitch"]) for n in p["notes"] if t0 <= n["t_written"] < t1))
        rep = [b + 1 for b in range(1, len(ms)) if ms[b] and ms[b] == ms[b - 1]]
        if rep:
            warns.append(f"melody {p['name']}: bars equal to the bar before: {rep}")

    # 8. density per section
    dens = {}
    for s in data["sections"] or [["all", 1, song.bars]]:
        nm, a, b = s
        t0, t1 = song.at(a), song.at(b + 1)
        row = {}
        tot = 0
        active = 0
        for p in parts:
            c = sum(1 for n in p["notes"] if t0 <= n["t_written"] < t1)
            row[p["name"]] = round(c / (b - a + 1), 1)
            tot += c
            active += 1 if c else 0
        row["_total"] = round(tot / (b - a + 1), 1)
        row["_parts"] = active
        dens[f"{nm} ({a}-{b})"] = row
    st["density"] = dens
    if len(dens) >= 2:
        tots = [r["_total"] for r in dens.values()]
        if min(tots) > 0 and max(tots) / min(tots) < 1.2 and len({r["_parts"] for r in dens.values()}) == 1:
            warns.append("every section is about as full as the others (thin and full should alternate)")

    # 9. velocity variety
    for p in pitched:
        v = [n["vel"] for n in p["notes"]]
        if len(v) >= 16 and np.std(v) < 4:
            warns.append(f"{p['name']}: velocities hardly vary (sd {np.std(v):.1f})")
    st["velocity_sd"] = {p["name"]: round(float(np.std([n["vel"] for n in p["notes"]])), 1)
                         for p in parts if p["notes"]}
    return warns, st


def stem_checks(song, data: dict) -> tuple[list, dict]:
    """Is the melody at least as loud as each accompaniment part, section by section?"""
    warns, st = [], {}
    import pyloudnorm
    meter = pyloudnorm.Meter(SR)
    od = out_dir(song.name) / "stems"
    stems = {}
    for p in data["parts"]:
        safe = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in p["name"])
        f = od / f"{safe}.wav"
        if f.exists():
            stems[p["name"]] = sf.read(str(f), always_2d=True)[0]
    mel_names = [p["name"] for p in data["parts"] if p["role"] == "melody"]
    if not mel_names or not stems:
        return warns, st
    sec_s = 60.0 / song.quarter_bpm * song.beat_quarters
    secs = data["sections"] or [["all", 1, song.bars]]
    table = {}

    def lufs(x):
        if np.max(np.abs(x)) < 1e-5 or len(x) < int(0.5 * SR):
            return None
        v = meter.integrated_loudness(x)
        return None if not np.isfinite(v) else float(v)
    for nm, a, b in secs:
        s0 = int(song.at(a) * sec_s * SR)
        s1 = int(song.at(b + 1) * sec_s * SR)
        mel = sum(stems[m][s0:s1] for m in mel_names if m in stems)
        ml = lufs(mel) if isinstance(mel, np.ndarray) else None
        row = {"melody": ml}
        for p in data["parts"]:
            if p["name"] in mel_names or p["name"] not in stems:
                continue
            v = lufs(stems[p["name"]][s0:s1])
            row[p["name"]] = v
            if ml is not None and v is not None and v > ml + 0.0:
                warns.append(f"section {nm}: {p['name']} ({v:.1f} LUFS) is louder than the melody ({ml:.1f})")
        table[nm] = row
    st["stem_lufs"] = table
    return warns, st


# ---------------------------------------------------------------------------
# Pictures
# ---------------------------------------------------------------------------

def pictures(song, data: dict, x: np.ndarray, od: Path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Rectangle

    bpb = song.beats_per_bar
    # piano roll
    fig, ax = plt.subplots(figsize=(24, 10), dpi=70)
    cmap = plt.get_cmap("tab10")
    pitched = [p for p in data["parts"] if not p["drums"]]
    allp = [n["pitch"] for p in pitched for n in p["notes"]] or [60]
    lo, hi = min(allp) - 2, max(allp) + 2
    drum_rows = {}
    for i, p in enumerate(data["parts"]):
        col = cmap(i % 10)
        for n in p["notes"]:
            x0 = n["t"] / bpb + 1
            w = max(0.02, (n["end"] - n["t"]) / bpb)
            if p["drums"]:
                row = drum_rows.setdefault(n["pitch"], len(drum_rows))
                y = lo - 3 - row * 1.2
                ax.add_patch(Rectangle((x0, y), 0.03, 1.0, color=col, alpha=0.4 + 0.6 * n["vel"] / 127))
            else:
                ax.add_patch(Rectangle((x0, n["pitch"] - 0.45), w, 0.9, facecolor=col,
                                       edgecolor="black" if p["role"] == "melody" else "none",
                                       linewidth=0.8, alpha=0.35 + 0.65 * n["vel"] / 127))
        ax.plot([], [], color=col, linewidth=6, label=f"{p['name']} ({p['role']})")
    ybottom = lo - 4 - 1.2 * len(drum_rows)
    for b in range(1, song.bars + 2):
        ax.axvline(b, color="#999", linewidth=0.5 if (b - 1) % 4 else 1.2, zorder=0)
    for k, (nm, a, b) in enumerate(data["sections"]):
        ax.axvspan(a, b + 1, color="#f2f2f2" if k % 2 else "#e6eef8", zorder=-1)
        ax.text(a + 0.1, hi + 3.2, nm, fontsize=14, weight="bold")
    for t, sym in data["chords"]:
        ax.text(t / bpb + 1.02, hi + 0.8, sym, fontsize=8, color="#444")
    for c in range(12 * (lo // 12), hi + 1, 12):
        ax.axhline(c, color="#ccc", linewidth=0.4, zorder=0)
        ax.text(0.55, c, name_of(c), fontsize=7, color="#888", va="center")
    ax.set_xlim(0.5, song.bars + 1.1)
    ax.set_ylim(ybottom, hi + 5)
    ax.set_xticks(range(1, song.bars + 1))
    ax.set_xlabel("bar")
    ax.set_title(f"{song.name}: {song.key_name} {song.mode}, {song.meter[0]}/{song.meter[1]}, tempo {song.tempo:g}")
    ax.legend(loc="upper right", fontsize=8, ncol=2)
    fig.tight_layout()
    fig.savefig(od / "roll.png")
    plt.close(fig)

    # spectrogram
    mid = x.mean(axis=1)
    f, t, S = signal.spectrogram(mid, SR, nperseg=4096, noverlap=3072)
    S = 10 * np.log10(S + 1e-12)
    fig, ax = plt.subplots(figsize=(20, 6), dpi=70)
    keep = (f >= 30) & (f <= 16000)
    sec_per_bar = 60.0 / song.quarter_bpm * song.beat_quarters * bpb
    vmax = S[keep].max()
    ax.pcolormesh(t / sec_per_bar + 1, f[keep], S[keep], vmin=vmax - 80, vmax=vmax, cmap="magma", shading="auto")
    ax.set_yscale("log")
    ax.set_ylim(30, 16000)
    ax.set_xlim(1, song.bars + 1)
    for nm, a, b in data["sections"]:
        ax.axvline(a, color="white", linewidth=1)
        ax.text(a + 0.1, 12000, nm, color="white", fontsize=12)
    for y in (250, 2000, 5000):
        ax.axhline(y, color="cyan", linewidth=0.5, linestyle=":")
    ax.set_xlabel("bar")
    ax.set_ylabel("Hz")
    ax.set_title(f"{song.name}: spectrogram (dotted: 250 Hz, 2 kHz, 5 kHz)")
    fig.tight_layout()
    fig.savefig(od / "spectrogram.png")
    plt.close(fig)

    # seam
    if song.loop:
        fig, axs = plt.subplots(3, 1, figsize=(14, 9), dpi=70)
        n = int(0.015 * SR)
        j = np.concatenate([x[-n:], x[:n]])
        tt = (np.arange(len(j)) - n) / SR * 1000
        axs[0].plot(tt, j[:, 0], linewidth=0.7, label="L")
        axs[0].plot(tt, j[:, 1], linewidth=0.7, label="R")
        axs[0].axvline(0, color="red")
        axs[0].set_title("last 15 ms | first 15 ms (red: loop point)")
        axs[0].set_xlabel("ms")
        axs[0].legend()
        k = 60
        z = np.concatenate([x[-k:], x[:k]])
        axs[1].plot(np.arange(-k, k), z[:, 0], ".-", linewidth=0.7)
        axs[1].plot(np.arange(-k, k), z[:, 1], ".-", linewidth=0.7)
        axs[1].axvline(-0.5, color="red")
        axs[1].set_title("60 samples each side")
        m = int(3 * SR)
        e = np.concatenate([x[-m:], x[:m]]).mean(axis=1)
        w = int(0.005 * SR)
        env = 10 * np.log10(np.convolve(e ** 2, np.ones(w) / w, mode="same") + 1e-12)
        axs[2].plot((np.arange(len(env)) - m) / SR, env, linewidth=0.7)
        axs[2].axvline(0, color="red")
        axs[2].set_title("level (5 ms RMS, dB): last 3 s | first 3 s")
        axs[2].set_xlabel("s")
        fig.tight_layout()
        fig.savefig(od / "seam.png")
        plt.close(fig)


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def check(name: str, *, pics: bool = True) -> dict:
    song = load_song(name)
    od = out_dir(name)
    res = {"name": name, "fails": [], "warns": [], "stats": {}}
    wav = od / f"{name}.wav"
    sj = od / "score.json"
    final = final_path(song)
    if not wav.exists() or not sj.exists():
        res["fails"].append(f"not built yet: run python -m tools.music build {name}")
        return res
    data = json.loads(sj.read_text())
    if data.get("hash") != render.score_hash(song):
        res["fails"].append("the track file changed after the last build: build it again")
    x, sr = sf.read(str(wav), always_2d=True)
    f, w, st = audio_checks(song, x, final, data)
    res["fails"] += f
    res["warns"] += w
    res["stats"].update(st)
    w2, st2 = score_checks(song, data)
    res["warns"] += w2
    res["stats"].update(st2)
    w3, st3 = stem_checks(song, data)
    res["warns"] += w3
    res["stats"].update(st3)
    if pics:
        pictures(song, data, x, od)
    write_report(song, res, od)
    return res


def write_report(song, res, od: Path):
    st = res["stats"]
    L = []
    L.append(f"# {song.name}\n")
    L.append(f"{song.summary()}  ")
    L.append(f"where: {song.where}\n")
    L.append(f"**{'FAIL' if res['fails'] else 'OK'}** - {len(res['fails'])} failure(s), {len(res['warns'])} warning(s)\n")
    if res["fails"]:
        L.append("## Failures\n")
        L += [f"- {x}" for x in res["fails"]]
        L.append("")
    L.append("## Warnings\n")
    L += [f"- {x}" for x in res["warns"]] or ["- none"]
    L.append("")
    L.append("## Measurements\n")
    for k in ("seconds", "samples", "lufs", "true_peak", "sample_peak", "ogg_true_peak", "side_db",
              "longest_silence", "dc", "bytes", "allowance", "budget_total", "melody_range", "distinct_bars"):
        if k in st:
            v = st[k]
            L.append(f"- {k}: {v:.3f}" if isinstance(v, float) else f"- {k}: {v}")
    if "bands" in st:
        L.append("- energy: " + ", ".join(f"{k} {v:.1%}" for k, v in st["bands"].items()))
    if "seam" in st:
        L.append("- seam: " + ", ".join(f"{k} {v:.2f}" for k, v in st["seam"].items()))
    if "ogg_seam" in st:
        L.append("- seam of the decoded OGG: " + ", ".join(f"{k} {v:.2f}" for k, v in st["ogg_seam"].items()))
    L.append("")
    if "density" in st:
        names = [p.name for p in song.parts]
        L.append("## Notes per bar, by section\n")
        L.append("| section | " + " | ".join(names) + " | total | parts |")
        L.append("|---" * (len(names) + 3) + "|")
        for sec, row in st["density"].items():
            L.append(f"| {sec} | " + " | ".join(str(row.get(n, 0)) for n in names) +
                     f" | {row['_total']} | {row['_parts']} |")
        L.append("")
    if st.get("stem_lufs"):
        L.append("## Loudness of each part alone, by section (LUFS; melody = all melody parts)\n")
        cols = sorted({k for r in st["stem_lufs"].values() for k in r}, key=lambda k: (k != "melody", k))
        L.append("| section | " + " | ".join(cols) + " |")
        L.append("|---" * (len(cols) + 1) + "|")
        for sec, row in st["stem_lufs"].items():
            L.append(f"| {sec} | " + " | ".join("-" if row.get(c) is None else f"{row[c]:.1f}" for c in cols) + " |")
        L.append("")
    if "velocity_sd" in st:
        L.append("velocity spread (sd): " + ", ".join(f"{k} {v}" for k, v in st["velocity_sd"].items()) + "\n")
    L.append("Pictures: roll.png, spectrogram.png" + (", seam.png" if song.loop else "") + " (this folder).\n")
    (od / "report.md").write_text("\n".join(L))
    (od / "stats.json").write_text(json.dumps(res, indent=1, default=str))


def seamtest(name: str) -> bool:
    """Prove the seam check: the real loop must pass, broken loops must fail."""
    song = load_song(name)
    if not song.loop:
        print(f"{name}: not a loop (skipped)")
        return True
    od = out_dir(name)
    sj = od / "score.json"
    data = json.loads(sj.read_text()) if sj.exists() else None
    good, _ = sf.read(str(od / f"{name}.wav"), always_2d=True)
    cases = [("the built loop", good, True)]
    final = final_path(song)
    if final.suffix == ".ogg" and final.exists():
        cases.append(("the decoded OGG", decode_ogg(final).astype(np.float64), True))
    bad = od / "broken_loop.wav"
    if bad.exists():
        cases.append(("first pass instead of second, 1000 samples short", sf.read(str(bad), always_2d=True)[0], False))
    for k in (200, 1000, 5000):
        cases.append((f"the built loop cut {k} samples short", good[:-k], False))
    cases.append(("the built loop with 20 ms cut from its start", good[int(0.02 * SR):], False))
    ok = True
    for label, x, should_pass in cases:
        m = seam_metrics(x, song, data)
        f = seam_fails(m)
        passed = not f
        right = passed == should_pass
        ok &= right
        tm = f", timing {m['timing']:+.1f} ms" if "timing" in m else ""
        print(f"{'right' if right else 'WRONG'}: {label}: {'passes' if passed else 'fails'} "
              f"(click {m['click']:.2f}, drop {m['drop']:+.1f} dB{tm}, jump {m['jump']:.2f})")
    print("SEAMTEST: OK" if ok else "SEAMTEST: FAIL")
    return ok
