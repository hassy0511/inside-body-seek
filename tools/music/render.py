"""Song -> MIDI -> FluidSynth stems -> mix with a room -> master -> WAV/OGG/.import.

One build writes only the files of its own piece:
  godot/assets/audio/<name>.ogg and <name>.ogg.import   (or clear.wav for output='wav_mono')
  tools/music/out/<name>/...  (work WAV, stems, MIDI, score.json, pictures, report)
Temporary files live in tools/music/out/<name>/tmp/ and carry the piece's name.
"""
from __future__ import annotations

import concurrent.futures as cf
import hashlib
import importlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import mido
import numpy as np
import pyloudnorm
import soundfile as sf
from scipy import ndimage, signal

from .score import Song

SR = 44100
PPQ = 960
ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "godot" / "assets" / "audio"
OUTROOT = Path(__file__).resolve().parent / "out"
SOUNDFONT = Path(os.environ.get("MUSIC_SOUNDFONT", "/usr/share/sounds/sf3/MuseScore_General_Full.sf3"))

LOOP_LUFS = -18.0
SHORT_LUFS = -16.0
CEILING_DBTP = -2.0      # the limiter aims here; the check allows up to -1.5
OGG_QUALITY = 2          # libvorbis -q:a (the brief's minimum; keeps 10 loops + jingles under 8 MB)
FLUID_GAIN = 0.5
LOOP_TAIL_S = 4.0        # ring rendered after the second pass
SHORT_FADE_S = 0.3       # a short piece's last 0.3 s fade out (raised cosine), so the cut is inaudible
SEAM_LEAD = 32           # a loop starts this many samples before the downbeat, so the
                         # loop point lies in continuous sound and not on a drum's first sample
FLUID_OFFSET = 64        # samples between tick 0 and the first sound (measured: FluidSynth starts one 64-sample block late)


def load_song(name: str) -> Song:
    mod_name = f"tools.music.tracks.{name}"
    if mod_name in sys.modules:
        mod = importlib.reload(sys.modules[mod_name])
    else:
        mod = importlib.import_module(mod_name)
    s = mod.song()
    if s.name != name:
        raise ValueError(f"tracks/{name}.py makes a song named {s.name!r}; the names must match")
    return s


def track_names(include_examples: bool = False) -> list[str]:
    d = Path(__file__).resolve().parent / "tracks"
    out = []
    for f in sorted(d.glob("*.py")):
        if f.stem == "__init__":
            continue
        if f.stem.startswith("_") and not include_examples:
            continue
        out.append(f.stem)
    return out


def is_example(name: str) -> bool:
    return name.startswith("_")


def out_dir(name: str) -> Path:
    d = OUTROOT / name
    d.mkdir(parents=True, exist_ok=True)
    return d


def final_path(song: Song) -> Path:
    """Where the committed file goes (examples stay in the work folder)."""
    if is_example(song.name):
        d = out_dir(song.name)
        return d / (f"{song.name}.final.wav" if song.output == "wav_mono" else f"{song.name}.ogg")
    if song.output == "wav_mono":
        return AUDIO / f"{song.name}.wav"
    return AUDIO / f"{song.name}.ogg"


# ---------------------------------------------------------------------------
# Realise: swing, humanise, velocities, gates -> concrete events in beats
# ---------------------------------------------------------------------------

def _swing_warp(t: float, s: float, unit: float = 1.0) -> float:
    """Move off-beat eighths later: inside each beat, 0..0.5 -> 0..s, 0.5..1 -> s..1."""
    if s is None or abs(s - 0.5) < 1e-6:
        return t
    k = np.floor(t / unit + 1e-9)
    f = t / unit - k
    if f < 0.5:
        f2 = f / 0.5 * s
    else:
        f2 = s + (f - 0.5) / 0.5 * (1 - s)
    return (k + f2) * unit


STEADY_DRUMS = {35, 36, 49, 52, 55, 57}   # kicks and crash cymbals: never moved in time


def realize(song: Song) -> list[dict]:
    """Every part's final notes: dicts with t, dur, pitch, vel (beats, ints)."""
    beat_s = 60.0 / song.quarter_bpm * song.beat_quarters
    strong = song.strong_beats()
    parts = []
    for ch_i, part in enumerate(song.parts):
        rng = np.random.default_rng(song.seed("humanize", part.name))
        t_ms, v_j = part.humanize
        notes = []
        for n in sorted(part.notes, key=lambda n: (n.t, n.pitch)):
            t0, t1 = n.t, n.t + n.dur
            gate = 1.0 if part.drums else (n.gate if n.gate is not None else part.gate)
            end = t0 + max(0.06, n.dur * gate) if not part.drums else t0 + n.dur
            if part.swing and not song.compound:
                t0s, ends = _swing_warp(t0, part.swing), _swing_warp(end, part.swing)
            else:
                t0s, ends = t0, end
            # velocity
            if n.vel is not None:
                vel = float(n.vel)
            else:
                vel = part.base_vel(n.t)
                if part.accents:
                    pos = round((n.t % song.beats_per_bar) * 1000) / 1000
                    if pos == 0:
                        vel += 6
                    elif pos in strong:
                        vel += 3
                    elif abs(pos - round(pos)) > 1e-6:
                        vel -= 3 if abs((pos % 1) - 0.5) < 1e-6 else 5
            vel += n.accent
            # humanise (seeded)
            jt = rng.normal(0, t_ms / 1000.0 / beat_s) if t_ms > 0 else 0.0
            # drums: at most +-1.5 x the spread, and the kick and crashes stay on the grid
            lim = (1.5 if part.drums else 2.5) * t_ms / 1000 / beat_s
            jt = float(np.clip(jt, -lim, lim)) if t_ms > 0 else 0.0
            if part.drums and n.pitch in STEADY_DRUMS:
                jt = 0.0
            jv = int(rng.integers(-v_j, v_j + 1)) if v_j > 0 else 0
            vel = int(np.clip(round(vel + jv), 1, 127))
            ts = max(0.0, t0s + jt)
            te = max(ts + 0.03, ends + jt)
            notes.append({"t": ts, "end": te, "pitch": int(n.pitch), "vel": vel,
                          "t_written": n.t, "dur_written": n.dur, "ok": bool(n.ok)})
        ccs = sorted([(c.t, c.cc, c.value) for c in part.ccs])
        parts.append({"name": part.name, "notes": notes, "ccs": ccs})
    return parts


# ---------------------------------------------------------------------------
# MIDI
# ---------------------------------------------------------------------------

def _channel(song: Song, idx: int) -> int:
    part = song.parts[idx]
    if part.drums:
        return 9
    melodic = [i for i, p in enumerate(song.parts) if not p.drums]
    c = melodic.index(idx)
    return c if c < 9 else c + 1


def beats_to_ticks(song: Song, beats: float) -> int:
    return int(round(beats * song.beat_quarters * PPQ))


def tempo_us(song: Song) -> int:
    return int(round(60_000_000 / song.quarter_bpm))


def loop_samples(song: Song) -> int:
    """Exact length of one pass in samples (from the integer MIDI tempo)."""
    ticks = beats_to_ticks(song, song.total_beats)
    return int(round(ticks / PPQ * tempo_us(song) / 1e6 * SR))


def write_midi(song: Song, real: list[dict], path: Path, only: int | None = None,
               passes: int = 1, tail_s: float = 0.0):
    mf = mido.MidiFile(type=1, ticks_per_beat=PPQ)
    t0 = mido.MidiTrack()
    t0.append(mido.MetaMessage("set_tempo", tempo=tempo_us(song), time=0))
    t0.append(mido.MetaMessage("time_signature", numerator=song.meter[0],
                               denominator=song.meter[1], time=0))
    mf.tracks.append(t0)
    pass_ticks = beats_to_ticks(song, song.total_beats)
    tail_ticks = int(round(tail_s * 1e6 / tempo_us(song) * PPQ))
    end_tick = pass_ticks * passes + tail_ticks
    for i, part in enumerate(song.parts):
        if only is not None and i != only:
            continue
        ch = _channel(song, i)
        ev = []   # (tick, order, msg)
        ev.append((0, 0, mido.Message("control_change", channel=ch, control=121, value=0)))
        if not part.drums:
            ev.append((0, 1, mido.Message("control_change", channel=ch, control=0, value=part.bank)))
            ev.append((0, 1, mido.Message("control_change", channel=ch, control=32, value=0)))
        ev.append((0, 2, mido.Message("program_change", channel=ch, program=part.program)))
        ev.append((0, 3, mido.Message("control_change", channel=ch, control=7, value=part.volume)))
        ev.append((0, 3, mido.Message("control_change", channel=ch, control=10,
                                      value=int(np.clip(part.pan + 64, 0, 127)))))
        ev.append((0, 3, mido.Message("control_change", channel=ch, control=91, value=0)))
        ev.append((0, 3, mido.Message("control_change", channel=ch, control=93, value=0)))
        r = real[i]
        for k in range(passes):
            off = k * pass_ticks
            ev.append((off, 4, mido.Message("control_change", channel=ch, control=11,
                                            value=part.expression)))
            for (t, cc, val) in r["ccs"]:
                ev.append((off + beats_to_ticks(song, t), 5,
                           mido.Message("control_change", channel=ch, control=cc, value=int(np.clip(val, 0, 127)))))
            for n in r["notes"]:
                a = off + beats_to_ticks(song, n["t"])
                b = off + max(beats_to_ticks(song, n["end"]), beats_to_ticks(song, n["t"]) + 1)
                ev.append((a, 7, ("on", n["pitch"], n["vel"], ch)))
                ev.append((b, 6, ("off", n["pitch"], 0, ch)))
        ev.append((end_tick, 9, mido.Message("control_change", channel=ch, control=7, value=part.volume)))
        ev.sort(key=lambda e: (e[0], e[1]))
        # resolve overlapping notes of the same pitch: a new note-on ends the old one
        sounding: dict[int, int] = {}
        msgs = []
        for tick, order, m in ev:
            if isinstance(m, tuple):
                kind, pitch, vel, c = m
                if kind == "on":
                    if sounding.get(pitch, 0) > 0:
                        msgs.append((tick, mido.Message("note_off", channel=c, note=pitch, velocity=0)))
                        sounding[pitch] -= 1
                        sounding.setdefault(("skip", pitch), 0)
                        sounding[("skip", pitch)] = sounding.get(("skip", pitch), 0) + 1
                    sounding[pitch] = sounding.get(pitch, 0) + 1
                    msgs.append((tick, mido.Message("note_on", channel=c, note=pitch, velocity=vel)))
                else:
                    if sounding.get(("skip", pitch), 0) > 0:
                        sounding[("skip", pitch)] -= 1
                        continue
                    if sounding.get(pitch, 0) > 0:
                        sounding[pitch] -= 1
                        msgs.append((tick, mido.Message("note_off", channel=c, note=pitch, velocity=0)))
            else:
                msgs.append((tick, m))
        tr = mido.MidiTrack()
        tr.append(mido.MetaMessage("track_name", name=part.name, time=0))
        last = 0
        for tick, m in msgs:
            tr.append(m.copy(time=tick - last))
            last = tick
        mf.tracks.append(tr)
    mf.save(str(path))
    return end_tick


# ---------------------------------------------------------------------------
# FluidSynth
# ---------------------------------------------------------------------------

def fluid_render(mid: Path, wav: Path):
    if not SOUNDFONT.exists():
        raise SystemExit(f"soundfont missing: {SOUNDFONT} (apt install musescore-general-soundfont)")
    cmd = ["fluidsynth", "-n", "-i", "-q", "-r", str(SR), "-g", str(FLUID_GAIN),
           "-o", "synth.reverb.active=0", "-o", "synth.chorus.active=0",
           "-o", "synth.polyphony=512", "-o", "synth.cpu-cores=1",
           "-F", str(wav), "-O", "float", "-T", "wav", str(SOUNDFONT), str(mid)]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0 or not wav.exists():
        raise RuntimeError(f"fluidsynth failed for {mid.name}: {res.stderr[-800:]}")


# ---------------------------------------------------------------------------
# Room (a synthetic stereo impulse response, seeded) and mix
# ---------------------------------------------------------------------------

def room_ir(seconds: float = 1.15, seed: int = 7, predelay: float = 0.014) -> np.ndarray:
    """A small friendly room: early reflections, then a diffuse tail whose
    highs die faster than its lows.  Low end below 200 Hz is cut from the
    return so the reverb never muddies the bass."""
    rng = np.random.default_rng(seed)
    n = int(SR * (seconds * 1.6 + predelay))
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    bands = [(None, 500, 1.15), (500, 2500, 1.0), (2500, 6000, 0.7), (6000, None, 0.42)]
    for ch in range(2):
        tail = np.zeros(n)
        for lo, hi, k in bands:
            noise = rng.standard_normal(n)
            if lo is None:
                sos = signal.butter(4, hi, "lowpass", fs=SR, output="sos")
            elif hi is None:
                sos = signal.butter(4, lo, "highpass", fs=SR, output="sos")
            else:
                sos = signal.butter(4, [lo, hi], "bandpass", fs=SR, output="sos")
            bandn = signal.sosfilt(sos, noise)
            rt = seconds * k
            tail += bandn * np.exp(-6.91 * np.maximum(t - predelay, 0) / rt)
        tail[: int(predelay * SR)] = 0
        # fade the diffuse tail in over 30 ms after the pre-delay
        ramp = np.clip((t - predelay) / 0.03, 0, 1)
        tail *= ramp
        er = np.zeros(n)
        for _ in range(10):
            d = rng.uniform(0.004, 0.032)
            er[int((predelay * 0.4 + d) * SR)] += rng.uniform(0.25, 0.6) * (1 - d * 12)
        ir[:, ch] = tail / np.sqrt(np.sum(tail ** 2)) + 0.35 * er / max(1e-9, np.sqrt(np.sum(er ** 2)))
    sos = signal.butter(2, 200, "highpass", fs=SR, output="sos")
    ir = signal.sosfilt(sos, ir, axis=0)
    sos = signal.butter(2, 9000, "lowpass", fs=SR, output="sos")
    ir = signal.sosfilt(sos, ir, axis=0)
    ir /= np.sqrt(np.mean(np.sum(ir ** 2, axis=0)))
    return ir


def wet_of(dry: np.ndarray, send: float, ir: np.ndarray) -> np.ndarray:
    if send <= 0:
        return np.zeros_like(dry)
    mono = dry.mean(axis=1) * send
    out = np.zeros((len(dry), 2))
    for ch in range(2):
        out[:, ch] = signal.oaconvolve(mono, ir[:, ch])[: len(dry)]
    return out


# ---------------------------------------------------------------------------
# Mastering
# ---------------------------------------------------------------------------

def true_peak_env(x: np.ndarray) -> np.ndarray:
    """Per-sample true peak (4x oversampled, max over channels)."""
    n = len(x)
    out = np.zeros(n)
    chunk, pad = 1 << 18, 64
    for s in range(0, n, chunk):
        a, b = max(0, s - pad), min(n, s + chunk + pad)
        up = signal.resample_poly(x[a:b], 4, 1, axis=0)
        m = np.abs(up).max(axis=1).reshape(-1, 4).max(axis=1)
        out[s:min(n, s + chunk)] = m[s - a: s - a + min(chunk, n - s)]
    return out


def true_peak_db(x: np.ndarray) -> float:
    if x.ndim == 1:
        x = x[:, None]
    return float(20 * np.log10(max(1e-12, true_peak_env(x).max())))


def limit(x: np.ndarray, ceiling_db: float) -> np.ndarray:
    """Gentle look-ahead limiter: gain never above what keeps the true peak
    under the ceiling; reductions are held and eased over ~60 ms."""
    c = 10 ** (ceiling_db / 20)
    tp = true_peak_env(x)
    g = np.minimum(1.0, c / np.maximum(tp, 1e-12))
    if g.min() >= 1.0:
        return x
    la = 66
    g = ndimage.minimum_filter1d(g, 2 * la + 1, mode="nearest")
    g = ndimage.uniform_filter1d(g, la + 1, mode="nearest")
    rel = int(0.06 * SR)
    g = ndimage.minimum_filter1d(g, rel, mode="nearest")
    g = ndimage.uniform_filter1d(g, rel // 2, mode="nearest")
    return x * g[:, None]


def _circular(fn, x: np.ndarray, pad: int) -> np.ndarray:
    ext = np.concatenate([x[-pad:], x, x[:pad]])
    return fn(ext)[pad: pad + len(x)]


def loudness(x: np.ndarray) -> float:
    meter = pyloudnorm.Meter(SR)
    return float(meter.integrated_loudness(x))


def master(x: np.ndarray, *, loop: bool, target: float) -> tuple[np.ndarray, float]:
    """High-pass 30 Hz, gain to the loudness target, limit.  Loops are
    processed circularly so the seam stays seamless.  Returns (audio, gain)."""
    sos = signal.butter(2, 30, "highpass", fs=SR, output="sos")
    pad = SR
    if loop:
        y = _circular(lambda z: signal.sosfilt(sos, z, axis=0), x, pad)
        meas = loudness
    else:
        y = signal.sosfilt(sos, np.concatenate([np.zeros((pad, x.shape[1])), x]), axis=0)[pad:]
        meas = loudness
    gain = 10 ** ((target - meas(y)) / 20)
    z = y
    for _ in range(5):
        if loop:
            z = _circular(lambda q: limit(q, CEILING_DBTP), y * gain, int(0.2 * SR))
        else:
            z = limit(y * gain, CEILING_DBTP)
        err = target - meas(z)
        if abs(err) < 0.05:
            break
        gain *= 10 ** (err / 20)
    # last safety: never above the ceiling after the gain tweak
    tp = true_peak_db(z)
    if tp > CEILING_DBTP + 0.2:
        z = z * 10 ** ((CEILING_DBTP - tp) / 20)
    return z, gain


def to_int16(x: np.ndarray) -> np.ndarray:
    return np.clip(np.round(x * 32767.0), -32768, 32767).astype(np.int16)


# ---------------------------------------------------------------------------
# Godot .import
# ---------------------------------------------------------------------------

def _uid(name: str) -> str:
    v = int.from_bytes(hashlib.sha256(("music:" + name).encode()).digest()[:8], "little") & ((1 << 63) - 1)
    chars = "abcdefghijklmnopqrstuvwxy" + "012345678"   # Godot's ResourceUID alphabet (base 34)
    s = ""
    while True:
        s = chars[v % 34] + s
        v //= 34
        if v == 0:
            break
    return "uid://" + s


def write_import(song: Song, path: Path):
    imp = path.with_name(path.name + ".import")
    res = f"res://assets/audio/{path.name}"
    md5 = hashlib.md5(res.encode()).hexdigest()
    if path.suffix == ".ogg":
        dest = f"res://.godot/imported/{path.name}-{md5}.oggvorbisstr"
        beats = song.meter[0] if not song.compound else song.meter[0] // 3
        text = (
            "[remap]\n\n"
            'importer="oggvorbisstr"\n'
            'type="AudioStreamOggVorbis"\n'
            f'uid="{_uid(song.name)}"\n'
            f'path="{dest}"\n\n'
            "[deps]\n\n"
            f'source_file="{res}"\n'
            f'dest_files=["{dest}"]\n\n'
            "[params]\n\n"
            f"loop={'true' if song.loop else 'false'}\n"
            "loop_offset=0\n"
            "bpm=0\n"
            "beat_count=0\n"
            f"bar_beats={beats}\n"
        )
    else:
        if imp.exists():
            return imp      # keep the existing import (and its uid)
        dest = f"res://.godot/imported/{path.name}-{md5}.sample"
        text = (
            "[remap]\n\n"
            'importer="wav"\n'
            'type="AudioStreamWAV"\n'
            f'uid="{_uid(song.name)}"\n'
            f'path="{dest}"\n\n'
            "[deps]\n\n"
            f'source_file="{res}"\n'
            f'dest_files=["{dest}"]\n\n'
            "[params]\n\n"
            "force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\n"
            "edit/trim=false\nedit/normalize=false\n"
            f"edit/loop_mode={1 if song.loop else 0}\nedit/loop_begin=0\nedit/loop_end=-1\n"
            "compress/mode=2\n"
        )
    tmp = imp.with_name(imp.name + f".{song.name}.tmp")
    tmp.write_text(text)
    tmp.replace(imp)
    return imp


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

OGG_LOOP_EXTRA = 4096     # samples of the loop's own start encoded after its end (see oggtrim.py)
OGG_TP_MAX = -1.6        # the decoded OGG's true peak must stay under this (the check allows -1.5)


def encode_ogg(wav: Path, ogg: Path, quality: float = OGG_QUALITY, tag: str = "", *,
               loop: bool = False) -> str:
    """Encode the work WAV to Vorbis.  For a loop, the encoder is given the loop
    followed by its first OGG_LOOP_EXTRA samples, so its last block sees the real
    continuation; the packets that only carry those extra samples are removed
    afterwards and the stream ends at exactly the loop length (oggtrim.py).
    Returns how it was encoded ("loop+extra" or "plain")."""
    # temporary files go to tools/music/out/<name>/tmp/ (not next to the OGG: a
    # leftover there would be committed, counted and published); same filesystem,
    # so the final replace() is still atomic
    tmpd = out_dir(tag or ogg.stem) / "tmp"
    tmpd.mkdir(exist_ok=True)
    tmp = tmpd / f"{ogg.stem}.tmp.ogg"
    src = wav
    how = "plain"
    ext = None
    if loop:
        x, sr = sf.read(str(wav), dtype="int16", always_2d=True)
        ext = tmpd / f"{wav.stem}.ext.tmp.wav"
        sf.write(str(ext), np.concatenate([x, x[:OGG_LOOP_EXTRA]]), sr, subtype="PCM_16")
        src = ext
    cmd = ["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", str(src),
           "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
           "-c:a", "libvorbis", "-q:a", str(quality), str(tmp)]
    subprocess.run(cmd, check=True)
    if loop:
        from . import oggtrim
        try:
            tmp.write_bytes(oggtrim.trim(tmp.read_bytes(), len(x)))
            how = "loop+extra"
        except ValueError as e:      # not plain libvorbis output: encode the loop alone
            print(f"  (ogg: {e}; encoding without the extra samples)", flush=True)
            subprocess.run([c if c != str(src) else str(wav) for c in cmd], check=True)
        ext.unlink(missing_ok=True)
    tmp.replace(ogg)
    return how


def _decoded_tp(ogg: Path) -> float:
    from .analyze import decode_ogg
    return true_peak_db(decode_ogg(ogg).astype(np.float64))


def score_hash(song: Song) -> str:
    real = realize(song)
    h = hashlib.sha256(json.dumps(real, sort_keys=True).encode())
    h.update(json.dumps([(p.name, p.program, p.bank, p.pan, p.volume, p.reverb, p.role)
                         for p in song.parts]).encode())
    return h.hexdigest()[:16]


def save_score(song: Song, real: list[dict], path: Path):
    data = {
        "name": song.name, "tempo": song.tempo, "meter": list(song.meter), "bars": song.bars,
        "key": song.key_name, "mode": song.mode, "loop": song.loop, "where": song.where,
        "beats_per_bar": song.beats_per_bar, "hash": score_hash(song),
        "sections": [[s.name, s.start, s.end] for s in song.sections],
        "chords": [[t, c.symbol] for t, c in song._chords],
        "parts": [{"name": p.name, "program": p.program, "drums": p.drums, "role": p.role,
                   "pan": p.pan, "volume": p.volume, "reverb": p.reverb,
                   "notes": r["notes"]} for p, r in zip(song.parts, real)],
    }
    path.write_text(json.dumps(data, indent=1))


def fold(x: np.ndarray, L: int) -> np.ndarray:
    """x[:L] with everything after L added back onto the start (circularly)."""
    out = x[:L].copy()
    rest = x[L:]
    while len(rest):
        k = min(L, len(rest))
        out[:k] += rest[:k]
        rest = rest[k:]
    return out


def build(name: str, *, quiet: bool = False, keep_tmp: bool = False) -> dict:
    """Build one piece.  Writes only this piece's files."""
    song = load_song(name)
    od = out_dir(name)
    tmpd = od / "tmp"
    if tmpd.exists():
        shutil.rmtree(tmpd)
    tmpd.mkdir()
    stemd = od / "stems"
    stemd.mkdir(exist_ok=True)
    for old in stemd.glob("*.wav"):
        old.unlink()
    log = (lambda *a: None) if quiet else (lambda *a: print(f"[{name}]", *a, flush=True))
    log(song.summary())

    real = realize(song)
    save_score(song, real, od / "score.json")
    write_midi(song, real, od / f"{name}.mid", passes=1, tail_s=0)

    L = loop_samples(song)
    two_pass = song.loop and os.environ.get("MUSIC_LOOP_METHOD") == "twopass"
    passes = 2 if two_pass else 1
    tail = LOOP_TAIL_S if song.loop else song.tail + 0.5
    jobs = []
    for i, part in enumerate(song.parts):
        mid = tmpd / f"{name}.{i:02d}.mid"
        wav = tmpd / f"{name}.{i:02d}.wav"
        write_midi(song, real, mid, only=i, passes=passes, tail_s=tail)
        jobs.append((mid, wav))
    workers = int(os.environ.get("MUSIC_JOBS", "3"))
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        list(ex.map(lambda j: fluid_render(*j), jobs))
    log(f"rendered {len(jobs)} parts with FluidSynth")

    ir = room_ir(1.05 * song.reverb_room, seed=song.seed("room") % (2 ** 31))
    lens = [sf.info(str(wav)).frames for _, wav in jobs]
    n_total = max(lens + [L * passes + int(tail * SR)])
    fade = int(SHORT_FADE_S * SR)
    ramp = (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fade)))[:, None]   # raised cosine

    def cut_of(x):
        if song.loop and two_pass:
            # the literal method: cut the second of two passes (kept for comparison;
            # FluidSynth's player dispatches events on 64-sample blocks timed by a
            # whole-millisecond clock, so pass 2 drifts against pass 1 by up to 63
            # samples and the ring at the seam no longer matches - see docs/audio.md)
            a = L + FLUID_OFFSET - SEAM_LEAD
            return x[a: a + L].copy()
        if song.loop:
            # one pass plus its ring; the ring after the last bar is laid over the
            # start, which is exactly what the second pass of a two-pass render
            # holds - but exact to the sample
            return fold(x[FLUID_OFFSET - SEAM_LEAD:], L)
        c = x[FLUID_OFFSET: FLUID_OFFSET + L + int(song.tail * SR)].copy()
        c[-fade:] *= ramp
        return c

    cut = None
    first_pass = None
    cuts = []
    for (mid, wav), part in zip(jobs, song.parts):     # one part at a time (memory)
        dry, sr = sf.read(str(wav), dtype="float64", always_2d=True)
        assert sr == SR
        d = np.zeros((n_total, 2))
        d[: len(dry)] = dry
        x = d + wet_of(d, part.reverb, ir)
        c = cut_of(x)
        cut = c.copy() if cut is None else cut + c
        cuts.append(c.astype(np.float32))
        if song.loop:
            fp = x[FLUID_OFFSET - SEAM_LEAD: FLUID_OFFSET - SEAM_LEAD + L - 1000]
            first_pass = fp.copy() if first_pass is None else first_pass + fp
        del dry, d, x

    target = LOOP_LUFS if song.loop else SHORT_LUFS
    if song.output == "wav_mono":
        cut = np.repeat(cut.mean(axis=1, keepdims=True), 2, axis=1)
    mastered, gain = master(cut, loop=song.loop, target=target)
    if song.output == "wav_mono":
        mastered = mastered[:, :1]

    work_wav = od / f"{name}.wav"
    sf.write(str(work_wav), to_int16(mastered), SR, subtype="PCM_16")
    for c, part in zip(cuts, song.parts):
        safe = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in part.name)
        sf.write(str(stemd / f"{safe}.wav"), to_int16(np.clip(c.astype(np.float64) * gain, -1, 1)), SR, subtype="PCM_16")
    if song.loop:
        # a deliberately broken loop for `python -m tools.music seamtest`: the FIRST
        # pass (no ring from a previous pass at its start), cut 1000 samples short
        bad = first_pass * gain
        sf.write(str(od / "broken_loop.wav"), to_int16(np.clip(bad, -1, 1)), SR, subtype="PCM_16")
    log(f"master gain {20*np.log10(gain):+.1f} dB, wrote {work_wav.relative_to(ROOT)}")

    final = final_path(song)
    if song.output == "wav_mono":
        tmpw = tmpd / f"{final.stem}.tmp.wav"
        sf.write(str(tmpw), to_int16(mastered), SR, subtype="PCM_16")
        tmpw.replace(final)
    else:
        encode_ogg(work_wav, final, tag=name, loop=song.loop)
        # Vorbis overshoots the limiter's ceiling a little; if the decoded file is
        # too hot, lower the master by the excess (+0.2 dB) and encode once more
        tp = _decoded_tp(final)
        if tp > OGG_TP_MAX:
            k = 10 ** (-(tp - OGG_TP_MAX + 0.2) / 20)
            mastered = mastered * k
            sf.write(str(work_wav), to_int16(mastered), SR, subtype="PCM_16")
            encode_ogg(work_wav, final, tag=name, loop=song.loop)
            log(f"the OGG peaked at {tp:.2f} dBTP: master lowered {20*np.log10(k):.2f} dB and encoded again")
    if not is_example(name):
        write_import(song, final)
    log(f"wrote {final.relative_to(ROOT)} ({final.stat().st_size} bytes)")
    if not keep_tmp:
        shutil.rmtree(tmpd)
    return {"song": song, "wav": work_wav, "final": final}
