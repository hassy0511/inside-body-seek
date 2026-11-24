"""A small composing library: songs, parts, notes, chords, patterns.

Read docs/audio.md and tools/music/tracks/bgm_title.py first.

Time
----
* Bars are numbered from 1, like a printed score.
* A *beat* is the note value of the metre's denominator: a quarter in 4/4 and
  3/4, an eighth in 6/8 (so a 6/8 bar has beats 1..6, the felt pulses are on
  beats 1 and 4, a dotted quarter lasts 3 beats).
* Beats inside a bar are numbered from 1 too (``beat=1`` is the downbeat,
  ``beat=2.5`` is the "and" of 2 in 4/4).  Durations are in beats.
* ``Song(tempo=...)`` is the felt pulse: quarters per minute in 4/4 or 3/4,
  dotted quarters per minute in 6/8, 9/8 and 12/8.

Pitch
-----
A pitch is a MIDI number or a name: ``"C4"`` = 60 (middle C), ``"F#5"``,
``"Bb3"``.  ``song.deg(5, 4)`` is degree 5 of the key in octave 4 (degree 1 of
C major in octave 4 is C4; degrees above 7 go up: ``deg(9, 4)`` = D5).

Everything here only *describes* the music.  ``render.py`` turns a Song into
MIDI and audio, ``analyze.py`` checks it.
"""
from __future__ import annotations

import hashlib
import math
import re
from dataclasses import dataclass, field

import numpy as np

# ---------------------------------------------------------------------------
# Pitch names, scales, chords
# ---------------------------------------------------------------------------

_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
_NAMES_SHARP = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

MODES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],      # natural minor (V and vii are taken from the chords)
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
}


def pc_of(name: str) -> int:
    """'C' -> 0, 'F#' -> 6, 'Bb' -> 10."""
    m = re.fullmatch(r"([A-Ga-g])([#b]*)", name.strip())
    if not m:
        raise ValueError(f"not a pitch class: {name!r}")
    pc = _PC[m.group(1).upper()]
    pc += m.group(2).count("#") - m.group(2).count("b")
    return pc % 12


def p(x) -> int:
    """Pitch: a MIDI number or a name such as 'C4' (= 60), 'F#5', 'Bb3'."""
    if isinstance(x, (int, np.integer)):
        return int(x)
    m = re.fullmatch(r"([A-Ga-g][#b]*)(-?\d)", str(x).strip())
    if not m:
        raise ValueError(f"not a pitch: {x!r} (write e.g. 'C4', 'F#5', 'Bb3' or a MIDI number)")
    letter = m.group(1)
    base = _PC[letter[0].upper()] + letter.count("#") - letter[1:].count("b")
    return 12 * (int(m.group(2)) + 1) + base


def name_of(pitch: int) -> str:
    return f"{_NAMES_SHARP[pitch % 12]}{pitch // 12 - 1}"


# chord qualities: intervals above the root
QUALITIES = {
    "": [0, 4, 7], "maj": [0, 4, 7], "m": [0, 3, 7], "min": [0, 3, 7],
    "dim": [0, 3, 6], "aug": [0, 4, 8], "+": [0, 4, 8],
    "sus4": [0, 5, 7], "sus2": [0, 2, 7], "sus": [0, 5, 7],
    "5": [0, 7],
    "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9],
    "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "M7": [0, 4, 7, 11],
    "m7": [0, 3, 7, 10], "mMaj7": [0, 3, 7, 11], "m7b5": [0, 3, 6, 10], "ø": [0, 3, 6, 10],
    "dim7": [0, 3, 6, 9], "7sus4": [0, 5, 7, 10], "7sus": [0, 5, 7, 10],
    "add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14],
    "9": [0, 4, 7, 10, 14], "maj9": [0, 4, 7, 11, 14], "m9": [0, 3, 7, 10, 14],
    "6/9": [0, 4, 7, 9, 14], "69": [0, 4, 7, 9, 14],
    "7b9": [0, 4, 7, 10, 13], "maj7#11": [0, 4, 7, 11, 18], "13": [0, 4, 7, 10, 14, 21],
}


@dataclass(frozen=True)
class Chord:
    symbol: str
    root: int            # pitch class
    intervals: tuple     # above the root (may exceed 12 for tensions)
    bass: int            # pitch class of the bass note (slash chords)

    @property
    def pcs(self) -> set:
        """Pitch classes of the chord (the slash bass included)."""
        return {(self.root + i) % 12 for i in self.intervals} | {self.bass}

    def tone(self, which, near: int) -> int:
        """A chord tone as a MIDI pitch close to `near`.

        which: 'R' root, '3', '5', '7', '9' (the chord's own 3rd/5th/7th, so
        '3' is minor in a minor chord), 'B' the bass (slash) note, or an int
        index into the chord's intervals."""
        pc = self.tone_pc(which)
        return nearest(pc, near)

    def tone_pc(self, which) -> int:
        if isinstance(which, int):
            return (self.root + self.intervals[which % len(self.intervals)]) % 12
        w = str(which)
        if w in ("R", "1", "8"):
            return self.root
        if w == "B":
            return self.bass
        want = {"3": (3, 4, 5, 2), "5": (7, 6, 8), "7": (10, 11, 9), "9": (14, 13, 2), "6": (9,), "4": (5,)}[w]
        ivs = [i for i in self.intervals]
        for cand in want:
            if cand in ivs or cand + 12 in ivs or (cand - 12) in ivs:
                return (self.root + cand) % 12
        return (self.root + want[0]) % 12


def chord(symbol: str) -> Chord:
    """Parse a chord symbol: 'C', 'Am7', 'G7/B', 'Fsus4', 'D7', 'Bbmaj7', 'F#m7b5', 'Fm6'."""
    s = symbol.strip()
    bass = None
    if "/" in s and not s.endswith("6/9"):
        s, b = s.rsplit("/", 1)
        bass = pc_of(b)
    m = re.fullmatch(r"([A-G][#b]?)(.*)", s)
    if not m:
        raise ValueError(f"not a chord: {symbol!r}")
    root = pc_of(m.group(1))
    q = m.group(2)
    if q not in QUALITIES:
        raise ValueError(f"unknown chord quality {q!r} in {symbol!r}; known: {sorted(QUALITIES)}")
    return Chord(symbol, root, tuple(QUALITIES[q]), root if bass is None else bass)


def nearest(pc: int, near: int) -> int:
    """The MIDI pitch with pitch class `pc` closest to `near` (ties go down)."""
    base = near - ((near - pc) % 12)
    return base if near - base <= base + 12 - near else base + 12


# ---------------------------------------------------------------------------
# General MIDI names
# ---------------------------------------------------------------------------

GM = {
    "piano": 0, "bright_piano": 1, "epiano": 4, "fm_epiano": 5, "harpsichord": 6, "clavinet": 7,
    "celesta": 8, "glockenspiel": 9, "music_box": 10, "vibraphone": 11, "marimba": 12,
    "xylophone": 13, "tubular_bells": 14, "dulcimer": 15, "organ": 16, "accordion": 21,
    "harmonica": 22, "nylon_guitar": 24, "steel_guitar": 25, "jazz_guitar": 26, "clean_guitar": 27,
    "acoustic_bass": 32, "fingered_bass": 33, "picked_bass": 34, "fretless_bass": 35,
    "slap_bass": 36, "synth_bass": 38, "violin": 40, "viola": 41, "cello": 42, "contrabass": 43,
    "tremolo_strings": 44, "pizzicato": 45, "harp": 46, "timpani": 47, "strings": 48,
    "slow_strings": 49, "synth_strings": 50, "choir": 52, "voice_oohs": 53, "orchestra_hit": 55,
    "trumpet": 56, "trombone": 57, "tuba": 58, "muted_trumpet": 59, "french_horn": 60,
    "brass": 61, "synth_brass": 62, "soprano_sax": 64, "alto_sax": 65, "tenor_sax": 66,
    "bari_sax": 67, "oboe": 68, "english_horn": 69, "bassoon": 70, "clarinet": 71,
    "piccolo": 72, "flute": 73, "recorder": 74, "pan_flute": 75, "bottle": 76, "whistle": 78,
    "ocarina": 79, "square_lead": 80, "saw_lead": 81, "calliope": 82, "chiff_lead": 83,
    "warm_pad": 89, "polysynth": 90, "space_voice": 91, "bowed_glass": 92, "halo_pad": 94,
    "sweep_pad": 95, "crystal": 98, "kalimba": 108, "steel_drums": 114, "woodblock": 115,
    "taiko": 116, "melodic_tom": 117,
}

# drum kits (program numbers on the drum channel, MuseScore_General)
KITS = {"standard": 0, "room": 8, "power": 16, "electronic": 24, "jazz": 32, "brush": 40,
        "orchestra": 48}

# General MIDI drum notes.  In the brush kit the snare notes are brushes.
DRUMS = {
    "kick": 36, "kick2": 35, "stick": 37, "rim": 37, "snare": 38, "clap": 39, "snare2": 40,
    "floor_tom": 41, "low_tom": 45, "mid_tom": 47, "high_tom": 50, "tom_lo": 43, "tom_hi": 48,
    "hat": 42, "pedal_hat": 44, "open_hat": 46, "crash": 49, "crash2": 57, "ride": 51,
    "ride_bell": 53, "china": 52, "splash": 55, "tambourine": 54, "cowbell": 56,
    "vibraslap": 58, "bongo_hi": 60, "bongo_lo": 61, "conga_mute": 62, "conga_hi": 63,
    "conga_lo": 64, "timbale_hi": 65, "timbale_lo": 66, "agogo_hi": 67, "agogo_lo": 68,
    "cabasa": 69, "maracas": 70, "whistle_s": 71, "guiro_s": 73, "claves": 75,
    "block_hi": 76, "block_lo": 77, "cuica_mute": 78, "cuica_open": 79,
    "triangle_mute": 80, "triangle": 81, "shaker": 82, "jingle": 83, "bell_tree": 84,
    "castanets": 85, "surdo_mute": 86, "surdo": 87,
}

# ---------------------------------------------------------------------------
# Notes, parts, songs
# ---------------------------------------------------------------------------


@dataclass
class Note:
    t: float            # start, in beats from the start of the song (bar 1 beat 1 = 0)
    dur: float          # beats
    pitch: int
    vel: int | None = None   # None: taken from the part's dynamics
    gate: float | None = None  # sounding fraction of dur; None: the part's default
    accent: int = 0     # added to the velocity
    ok: bool = False    # True: an intended chromatic or non-chord note (no warning)


@dataclass
class CC:
    t: float
    cc: int
    value: int


class Part:
    """One instrument on its own MIDI channel.

    Make parts with ``song.part(...)`` or ``song.drums(...)``, not directly."""

    def __init__(self, song: "Song", name: str, program: int | str, *, role: str,
                 pan: int, volume: int, reverb: float, bank: int, drums: bool,
                 gate: float, humanize: tuple | None, swing: float | None,
                 expression: int, octave: int = 0):
        self.song = song
        self.name = name
        self.drums = drums
        if isinstance(program, str):
            table = KITS if drums else GM
            if program not in table:
                raise ValueError(f"unknown {'kit' if drums else 'instrument'} {program!r}; known: {sorted(table)}")
            program = table[program]
        self.program = int(program)
        self.bank = bank
        self.role = role
        self.pan = pan
        self.volume = volume
        self.reverb = reverb
        self.gate = gate
        self.notes: list[Note] = []
        self.ccs: list[CC] = []
        self.swing = swing
        self.humanize = humanize if humanize is not None else ((2.0, 4) if drums else (6.0, 4))
        # drums: the timing spread never moves the kick or the cymbal crashes (see render.realize)
        self.expression = expression
        self.octave = octave
        self._dyn: list[tuple[float, float]] = []
        self.accents = True

    # ----- where ---------------------------------------------------------
    def at(self, bar: float, beat: float = 1) -> float:
        return self.song.at(bar, beat)

    # ----- dynamics --------------------------------------------------------
    def dyn(self, points: dict | str):
        """Base velocity over time, interpolated between points.

        ``part.dyn({1: 70, 5: 88, 8: 64})`` (keys are bars, or (bar, beat)
        tuples) or ``part.dyn("1:70 5:88 8:64")``.  Notes without an explicit
        velocity take this value plus a small metric accent."""
        if isinstance(points, str):
            d = {}
            for tok in points.split():
                k, v = tok.split(":")
                d[float(k)] = int(v)
            points = d
        pts = []
        for k, v in points.items():
            t = self.at(*k) if isinstance(k, tuple) else self.at(k)
            pts.append((t, float(v)))
        self._dyn = sorted(pts)
        return self

    def base_vel(self, t: float) -> float:
        if not self._dyn:
            return 80.0
        ts = [a for a, _ in self._dyn]
        vs = [b for _, b in self._dyn]
        return float(np.interp(t, ts, vs))

    # ----- single notes ------------------------------------------------------
    def note(self, bar, beat, pitch, dur, vel=None, *, gate=None, accent=0, ok=False):
        """One note.  pitch: MIDI number or name ('E5').  Returns the part."""
        self.notes.append(Note(self.at(bar, beat), float(dur), p(pitch) + 12 * self.octave,
                               vel, gate, accent, ok))
        return self

    def hit(self, bar, beat, drum, vel=None, dur=0.25, accent=0):
        """One drum hit: drum is a name from DRUMS ('kick', 'snare', 'hat'...) or a note number."""
        n = DRUMS[drum] if isinstance(drum, str) else int(drum)
        self.notes.append(Note(self.at(bar, beat), dur, n, vel, 1.0, accent, True))
        return self

    # ----- melodies ------------------------------------------------------------
    def line(self, bar, beat, text: str, vel=None, *, transpose: int = 0):
        """A run of notes written as tokens ``pitch:dur``, separated by spaces.

        Pitch is a name ('E5'), a scale degree with an octave ('d3/5' = degree 3
        in octave 5), 'r' for a rest, or '~' to hold the previous note longer
        (a tie: "G5:2 | ~:1" holds G5 over the bar line for one more beat).
        Durations may be fractions: '1/3' (a triplet eighth in 4/4).
        Suffixes on a token (after the dur):
          '   staccato (sounds 45 %)      _  tenuto (sounds the full value)
          >   accent (+14 velocity)       -  soft (-14 velocity)
          *   intended: a chromatic or non-chord note on purpose (no warning)
        Example: ``lead.line(1, 1, "C5:1 G5:1.5 F5:.5 E5:1 | D5:.5 E5:.5 G5:2 r:1")``
        ('|' is ignored and only helps the eye).  Returns the end time in
        beats (absolute), so lines can be chained with ``song.where(t)``."""
        t = self.at(bar, beat)
        prev = None
        for tok in text.replace("|", " ").split():
            m = re.fullmatch(r"([^:]+):([0-9.]+(?:/[0-9]+)?)([' _>\-*]*)", tok)
            if not m:
                raise ValueError(f"bad token {tok!r} in line at bar {bar}; write e.g. 'E5:1' or 'r:.5'")
            ptxt, dtxt, flags = m.groups()
            dur = _num(dtxt)
            if ptxt == "~":
                if prev is None:
                    raise ValueError(f"tie '~' with nothing before it at bar {bar}")
                prev.dur += dur
                t += dur
                continue
            if ptxt.lower() == "r":
                t += dur
                prev = None
                continue
            pitch = self._pitch_token(ptxt, t) + transpose
            gate = 0.45 if "'" in flags else (1.0 if "_" in flags else None)
            acc = (14 if ">" in flags else 0) - (14 if "-" in flags else 0)
            n = Note(t, dur, pitch + 12 * self.octave, vel, gate, acc, "*" in flags)
            self.notes.append(n)
            prev = n
            t += dur
        return t

    def _pitch_token(self, ptxt: str, t: float) -> int:
        m = re.fullmatch(r"d(-?\d+)/(-?\d)", ptxt)
        if m:
            return self.song.deg(int(m.group(1)), int(m.group(2)), t=t)
        return p(ptxt)

    def place(self, bar, beat, notes, vel=None, *, ok=False):
        """Place a list of (offset_beats, dur_beats, pitch) - e.g. from motif.py."""
        t0 = self.at(bar, beat)
        for off, dur, pitch in notes:
            self.notes.append(Note(t0 + off, dur, int(pitch) + 12 * self.octave, vel, None, 0, ok))
        return self

    # ----- harmony ---------------------------------------------------------------
    def chords(self, bars, rhythm: str = "x...", *, voices: int = 3, low="E4", high="E5",
               vel=None, gate=None, drop_root=False, top=None):
        """Comp the song's chords (``song.harmony``) with smooth voice leading.

        bars: a range of bars, e.g. ``range(1, 9)`` or ``(1, 8)`` (inclusive).
        rhythm: one grid per bar, one character per equal step: 'x' play,
        'X' accented, 'o' soft, '-' hold the previous hit, '.' rest.  Examples
        for 4/4: "x..." whole-bar-ish hits, ".x.x" off-beat quarters,
        "x.x.x.x." eighths (8 steps).  A list of grids cycles over the bars.
        Each hit lasts until the next non-'-' character."""
        rhythms = [rhythm] if isinstance(rhythm, str) else list(rhythm)
        prev = None
        for i, b in enumerate(_bars(bars)):
            grid = rhythms[i % len(rhythms)]
            for t, dur, flag in self.song.grid_hits(b, grid):
                ch = self.song.chord_at(t)
                if ch is None:
                    continue
                voicing = voice(ch, voices, p(low), p(high), prev, drop_root=drop_root, top=top)
                prev = voicing
                acc = {"X": 12, "o": -16}.get(flag, 0)
                for q in voicing:
                    self.notes.append(Note(t, dur, q + 12 * self.octave, vel, gate, acc, True))
        return self

    def pad(self, bars, *, voices=3, low="C4", high="G5", vel=None, swell=True):
        """Sustained chords that change with the harmony (one per chord), and a
        CC 11 swell on each.  For strings, horns, choir, warm pads."""
        prev = None
        for t, dur, ch in self.song.chord_spans(bars):
            voicing = voice(ch, voices, p(low), p(high), prev)
            prev = voicing
            for q in voicing:
                self.notes.append(Note(t, dur, q + 12 * self.octave, vel, 1.0, 0, True))
            if swell:
                self.swell_at(t, dur)
        return self

    def arp(self, bars, order="0123", step: float = 0.5, *, low="C4", high="C6",
            vel=None, gate=None, rest: str = ""):
        """Arpeggiate the current chord.

        order: indexes into the chord's tones from low to high inside
        [low, high] (0 = lowest, '9' wraps); 'r' or '.' is a rest.  The order
        cycles at `step` beats per note over each bar.  The tones are re-read
        from the harmony on every note, so chord changes in mid-bar work."""
        for b in _bars(bars):
            t0, t1 = self.at(b), self.at(b + 1)
            k = 0
            t = t0
            while t < t1 - 1e-9:
                c = order[k % len(order)]
                k += 1
                if c in "r.":
                    t += step
                    continue
                ch = self.song.chord_at(t)
                tones = chord_tones_in(ch, p(low), p(high))
                if tones:
                    q = tones[int(c) % len(tones)]
                    self.notes.append(Note(t, step, q + 12 * self.octave, vel, gate, 0, True))
                t += step
        return self

    def bass(self, bars, pattern: str = "R:2 5:2", *, octave: int = 2, vel=None, gate=None):
        """A bass line from chord-relative tokens, repeated in every bar.

        Tokens ``what:dur``.  what: R (the chord's bass note; the root, or the
        slash note), 1 (always the root), 3, 5, 7 (chord tones), 8 (bass an
        octave up), -5 (fifth below), 'a' (chromatic approach to the next
        chord's bass, a half step below), 's' (scale step toward the next
        bass), 'r' rest.  Suffixes as in ``line`` (' _ > -).
        octave: the register: the R note lies from E of that octave up to the
        D# above (2: E2..D#3, the usual bass register; 1: E1..D#2, low tuba)."""
        lo = 12 * (octave + 1) + 4  # E of that octave
        for b in _bars(bars):
            t = self.at(b)
            for tok in pattern.split():
                m = re.fullmatch(r"([^:]+):([0-9.]+(?:/[0-9]+)?)([' _>\-]*)", tok)
                if not m:
                    raise ValueError(f"bad bass token {tok!r}")
                what, dtxt, flags = m.groups()
                dur = _num(dtxt)
                if what == "r":
                    t += dur
                    continue
                ch = self.song.chord_at(t)
                if ch is None:
                    t += dur
                    continue
                q = self._bass_pitch(what, ch, t, dur, lo)
                gate_ = 0.45 if "'" in flags else (1.0 if "_" in flags else gate)
                acc = (14 if ">" in flags else 0) - (14 if "-" in flags else 0)
                self.notes.append(Note(t, dur, q + 12 * self.octave, vel, gate_, acc,
                                       what in ("a", "s")))
                t += dur
        return self

    def _bass_pitch(self, what, ch: Chord, t, dur, lo) -> int:
        def in_reg(pc):
            return lo + ((pc - lo) % 12)
        if what in ("R", "B"):
            return in_reg(ch.bass)
        if what == "1":
            return in_reg(ch.root)
        if what == "8":
            return in_reg(ch.bass) + 12
        if what == "-5":
            r = in_reg(ch.bass)
            f = nearest(ch.tone_pc("5"), r - 6)
            return f if f < r else f - 12
        if what in ("3", "5", "7", "9", "6", "4"):
            r = in_reg(ch.bass)
            q = r + ((ch.tone_pc(what) - r) % 12)
            return q
        nxt = self.song.chord_at(t + dur)
        target = in_reg(nxt.bass if nxt else ch.bass)
        if what == "a":
            return target - 1
        if what == "s":
            cur = in_reg(ch.bass)
            sc = self.song.scale_pcs(t)
            if target >= cur:
                cands = [q for q in range(target - 2, target) if q % 12 in sc]
                return cands[-1] if cands else target - 2
            cands = [q for q in range(target + 1, target + 3) if q % 12 in sc]
            return cands[0] if cands else target + 2
        raise ValueError(f"unknown bass token {what!r}")

    def walk(self, bars, *, octave: int = 2, vel=None, gate=0.85):
        """A walking bass in quarter notes (4/4): beats 1-3 are chord tones
        (bass, 3rd or 5th), beat 4 is a chromatic approach (odd bars) or a
        scale step (even bars) into the next bar's bass.  With two chords in a
        bar each gets two notes."""
        for b in _bars(bars):
            spans = [s for s in self.song.chord_spans((b, b))]
            if len(spans) >= 2:
                pat = "R:1 5:1 R:1 a:1"
            else:
                pat = "R:1 3:1 5:1 a:1" if b % 2 else "R:1 5:1 3:1 s:1"
            self.bass((b, b), pat, octave=octave, vel=vel, gate=gate)
        return self

    # ----- drums ---------------------------------------------------------------
    def grid(self, bars, lanes: dict, *, vel=None):
        """Drum patterns as text grids, one lane per drum.

        ``kit.grid((1, 8), {"kick": "x...x...", "stick": "....x...", "hat": "x-x-x-x-"})``
        Each string covers one bar in equal steps (8 characters = eighths in
        4/4, 6 = eighths in 6/8, 16 = sixteenths).  'x' hit, 'X' accent,
        'o' ghost (soft), '-' or '.' nothing.  A lane may also be a list of
        strings, used bar by bar in turn."""
        for i, b in enumerate(_bars(bars)):
            for drum, g in lanes.items():
                grid = g[i % len(g)] if isinstance(g, list) else g
                for t, dur, flag in self.song.grid_hits(b, grid, hold=False):
                    acc = {"X": 14, "o": -22}.get(flag, 0)
                    n = DRUMS[drum] if isinstance(drum, str) else int(drum)
                    self.notes.append(Note(t, min(dur, 0.5), n, vel, 1.0, acc, True))
        return self

    def fill(self, bar, beat, text: str, vel=None):
        """A drum fill as tokens ``drum:dur`` (e.g. "snare:.5 snare:.5 mid_tom:.5 low_tom:.5")."""
        t = self.at(bar, beat)
        for tok in text.split():
            m = re.fullmatch(r"([^:]+):([0-9.]+(?:/[0-9]+)?)([>\-]*)", tok)
            if not m:
                raise ValueError(f"bad fill token {tok!r}")
            d, dtxt, flags = m.groups()
            dur = _num(dtxt)
            if d != "r":
                for one in d.split("+"):
                    n = DRUMS[one] if not one.isdigit() else int(one)
                    acc = (14 if ">" in flags else 0) - (14 if "-" in flags else 0)
                    self.notes.append(Note(t, min(dur, 0.5), n, vel, 1.0, acc, True))
            t += dur
        return self

    # ----- controllers -----------------------------------------------------------
    def cc(self, bar, beat, number: int, value: int):
        self.ccs.append(CC(self.at(bar, beat), number, int(value)))
        return self

    def curve(self, bar, beat, beats: float, start: int, end: int, number: int = 11, steps: int = 0):
        """A straight ramp of a controller (default CC 11, expression)."""
        t0 = self.at(bar, beat)
        self._ramp(t0, beats, start, end, number, steps)
        return self

    def _ramp(self, t0, beats, start, end, number, steps=0):
        steps = steps or max(2, int(beats * 4))
        for i in range(steps + 1):
            x = i / steps
            self.ccs.append(CC(t0 + beats * x, number, int(round(start + (end - start) * x))))

    def swell(self, bar, beat, beats: float, low: int = 78, high: int = 112):
        """CC 11 rises from low to high over the first 40 % and falls back to
        about 90 over the rest: breath on a long note or chord."""
        self.swell_at(self.at(bar, beat), beats, low, high)
        return self

    def swell_at(self, t0, beats, low=78, high=112):
        up = beats * 0.4
        self._ramp(t0, up, low, high, 11)
        self._ramp(t0 + up, beats - up, high, int(low + (high - low) * 0.55), 11)

    def auto_swell(self, min_beats: float = 2.0, low: int = 80, high: int = 112, bars=None):
        """A CC 11 swell on every note at least `min_beats` long (for one-line
        parts: lead, horn, clarinet).  Call it after writing the notes."""
        t0, t1 = (-1, 1e9) if bars is None else (self.at(_span(bars)[0]), self.at(_span(bars)[1] + 1))
        for n in self.notes:
            if n.dur >= min_beats and t0 <= n.t < t1:
                self.swell_at(n.t, n.dur, low, high)
        return self

    # ----- helpers -------------------------------------------------------------------
    def clear(self, bars):
        """Remove the notes inside these bars (e.g. after copying a section)."""
        b0, b1 = _span(bars)
        t0, t1 = self.at(b0), self.at(b1 + 1)
        self.notes = [n for n in self.notes if not (t0 <= n.t < t1)]
        return self

    def copy(self, src_bars, to_bar, *, transpose=0):
        """Copy the notes of bars src_bars to start at to_bar."""
        b0, b1 = _span(src_bars)
        t0, t1 = self.at(b0), self.at(b1 + 1)
        shift = self.at(to_bar) - t0
        new = [Note(n.t + shift, n.dur, n.pitch + transpose, n.vel, n.gate, n.accent, n.ok)
               for n in self.notes if t0 <= n.t < t1]
        self.notes.extend(new)
        return self


def _num(s: str) -> float:
    if "/" in s:
        a, b = s.split("/")
        return float(a) / float(b)
    return float(s)


def _span(bars):
    if isinstance(bars, range):
        return bars.start, bars.stop - 1
    if isinstance(bars, int):
        return bars, bars
    a, b = bars
    return int(a), int(b)


def _bars(bars):
    a, b = _span(bars)
    return range(a, b + 1)


def chord_tones_in(ch: Chord | None, low: int, high: int) -> list[int]:
    if ch is None:
        return []
    pcs = ch.pcs
    return [q for q in range(low, high + 1) if q % 12 in pcs]


def voice(ch: Chord, n: int, low: int, high: int, prev: list[int] | None = None,
          *, drop_root=False, top=None) -> list[int]:
    """Choose n chord tones inside [low, high] that move as little as possible
    from `prev` (smooth inner voices).  The chord's 3rd and 7th are kept when
    there is room; the root may be dropped (the bass has it)."""
    pcs = [(ch.root + i) % 12 for i in ch.intervals]
    pcs = list(dict.fromkeys(pcs))
    if drop_root and len(pcs) > n:
        pcs = pcs[1:]
    if len(pcs) > n:   # keep 3rd and 7th (guide tones), drop the 5th first
        prio = []
        for want in ("3", "7", "R", "9", "5"):
            pc = ch.tone_pc(want)
            if pc in pcs and pc not in prio:
                prio.append(pc)
        for pc in pcs:
            if pc not in prio:
                prio.append(pc)
        pcs = prio[:n]
    cands = [q for q in range(low, high + 1) if q % 12 in pcs]
    best, best_cost = None, None
    import itertools
    for combo in itertools.combinations(cands, n):
        got = {q % 12 for q in combo}
        need = min(n, len(pcs))
        if len(got) < need:
            continue
        if combo[-1] - combo[0] > 14:   # keep it compact
            continue
        if any(b - a < 2 for a, b in zip(combo, combo[1:])) and n <= 4:
            # avoid seconds inside a small voicing unless the chord has them
            pass
        if prev:
            cost = sum(abs(a - b) for a, b in zip(sorted(combo), sorted(prev)))
        else:
            mid = (low + high) / 2
            cost = abs(sum(combo) / n - mid)
        if top is not None:
            cost += 2 * abs(combo[-1] - p(top))
        # penalise seconds at the bottom (muddy)
        cost += sum(3 for a, b in zip(combo, combo[1:]) if b - a <= 2 and a < 60)
        if best_cost is None or cost < best_cost:
            best, best_cost = list(combo), cost
    if best is None:
        best = sorted(nearest(pc, (low + high) // 2) for pc in pcs[:n])
    return best


@dataclass
class Section:
    name: str
    start: int   # first bar
    end: int     # last bar (inclusive)


class Song:
    """A piece of music.

    name: the file name in godot/assets/audio (bgm_title -> bgm_title.ogg).
    loop: True for BGM loops (rendered seamless), False for jingles.
    output: 'ogg' (stereo) or 'wav_mono' (clear.wav).
    tail: seconds of ring after a non-looping piece's last bar.
    """

    def __init__(self, name: str, *, tempo: float, key: str = "C", mode: str = "major",
                 meter: tuple = (4, 4), bars: int, loop: bool = True, where: str = "",
                 output: str = "ogg", tail: float = 1.6, reverb_room: float = 1.0):
        self.name = name
        self.tempo = float(tempo)
        self.meter = tuple(meter)
        self.bars = int(bars)
        self.loop = loop
        self.where = where
        self.output = output
        self.tail = tail
        self.reverb_room = reverb_room
        self.parts: list[Part] = []
        self.sections: list[Section] = []
        self._keys: list[tuple[float, int, str]] = [(0.0, pc_of(key), mode)]
        self._chords: list[tuple[float, Chord]] = []
        self.key_name = key
        self.mode = mode

    # ----- metre -----------------------------------------------------------------
    @property
    def beats_per_bar(self) -> int:
        return self.meter[0]

    @property
    def compound(self) -> bool:
        n, d = self.meter
        return d == 8 and n % 3 == 0 and n > 3

    @property
    def quarter_bpm(self) -> float:
        """Quarter notes per minute (what MIDI needs)."""
        n, d = self.meter
        if self.compound:
            return self.tempo * 1.5
        return self.tempo * d / 4

    @property
    def beat_quarters(self) -> float:
        """Length of one beat in quarter notes."""
        return 4.0 / self.meter[1]

    @property
    def total_beats(self) -> float:
        return self.bars * self.beats_per_bar

    def strong_beats(self) -> list[float]:
        """Beat offsets (0-based, inside a bar) that count as strong."""
        n = self.beats_per_bar
        if self.compound:
            return [float(i) for i in range(0, n, 3)]
        if n == 4:
            return [0.0, 2.0]
        if n == 2:
            return [0.0]
        if n == 3:
            return [0.0]
        return [0.0]

    def at(self, bar: float, beat: float = 1) -> float:
        """Absolute time in beats of (bar, beat), both counted from 1."""
        return (bar - 1) * self.beats_per_bar + (beat - 1)

    def where_is(self, t: float) -> tuple[int, float]:
        """(bar, beat) of an absolute time in beats."""
        bar = int(t // self.beats_per_bar) + 1
        return bar, t - (bar - 1) * self.beats_per_bar + 1

    def grid_hits(self, bar: int, grid: str, hold: bool = True):
        """(t, dur, flag) for each hit of a one-bar grid string."""
        grid = grid.replace(" ", "").replace("|", "")
        steps = len(grid)
        step = self.beats_per_bar / steps
        t0 = self.at(bar)
        out = []
        i = 0
        while i < steps:
            c = grid[i]
            if c in "xXo":
                j = i + 1
                while j < steps and (grid[j] == "-" if hold else False):
                    j += 1
                if not hold:
                    j = i + 1
                    while j < steps and grid[j] not in "xXo":
                        j += 1
                out.append((t0 + i * step, (j - i) * step, c))
                i = j if hold else i + 1
            else:
                i += 1
        return out

    # ----- parts ---------------------------------------------------------------
    def part(self, name: str, program: int | str, *, role: str = "accomp", pan: int = 0,
             volume: int = 100, reverb: float = 0.25, bank: int = 0, gate: float = 0.9,
             humanize: tuple | None = None, swing: float | None = None,
             expression: int = 110, octave: int = 0) -> Part:
        """Add an instrument.

        program: a GM number or a name from GM ('flute', 'pizzicato', ...).
        role: 'melody' (the tune; checked to be on top), 'counter' (answering
          line), 'harmony', 'bass', 'perc', 'sparkle' or 'accomp'.
        pan: -64 (left) .. 0 (centre) .. +63 (right).
        volume: CC 7, 0..127 (the fader).   reverb: send 0..1.
        gate: how much of each written duration sounds (0.9 = slightly detached).
        humanize: (timing_ms, velocity) random spread, seeded; default (6, 4).
        swing: 0.5 straight .. 0.67 triplet swing on off-beat eighths (4/4).
        expression: starting CC 11.   octave: shift every note by octaves."""
        if len(self.parts) >= 15:
            raise ValueError("at most 15 parts (MIDI channels) in one song")
        prt = Part(self, name, program, role=role, pan=pan, volume=volume, reverb=reverb,
                   bank=bank, drums=False, gate=gate, humanize=humanize, swing=swing,
                   expression=expression, octave=octave)
        self.parts.append(prt)
        return prt

    def drums(self, name: str = "kit", kit: int | str = "standard", *, pan: int = 0,
              volume: int = 100, reverb: float = 0.18, humanize: tuple | None = None,
              swing: float | None = None) -> Part:
        """Add the drum part (MIDI channel 10).  kit: 'standard', 'room',
        'jazz', 'brush', 'orchestra', 'electronic' or a number.  Only one."""
        if any(x.drums for x in self.parts):
            raise ValueError("only one drum part per song (all drums share MIDI channel 10)")
        prt = Part(self, name, kit, role="drums", pan=pan, volume=volume, reverb=reverb,
                   bank=128, drums=True, gate=1.0, humanize=humanize, swing=swing,
                   expression=127)
        self.parts.append(prt)
        return prt

    # ----- form, key, harmony ------------------------------------------------------
    def section(self, name: str, start: int, end: int):
        """Name bars start..end (inclusive), e.g. song.section("A", 1, 8)."""
        self.sections.append(Section(name, start, end))
        return self

    def section_of(self, bar: int) -> str:
        for s in self.sections:
            if s.start <= bar <= s.end:
                return s.name
        return "-"

    def set_key(self, bar: int, key: str, mode: str = "major"):
        """Change key (the scale used by degrees and by the scale check) from `bar`."""
        self._keys.append((self.at(bar), pc_of(key), mode))
        self._keys.sort(key=lambda k: k[0])
        return self

    def key_at(self, t: float) -> tuple[int, str]:
        cur = self._keys[0]
        for k in self._keys:
            if k[0] <= t + 1e-9:
                cur = k
        return cur[1], cur[2]

    def scale_pcs(self, t: float) -> set:
        tonic, mode = self.key_at(t)
        return {(tonic + i) % 12 for i in MODES[mode]}

    def deg(self, degree: int, octave: int = 4, *, t: float = 0.0, sharp: int = 0) -> int:
        """Scale degree (1..7, may go beyond) of the key at time t, as a MIDI pitch.
        Degree 1 in octave 4 is the tonic in octave 4 (C4 in C major)."""
        tonic, mode = self.key_at(t)
        steps = MODES[mode]
        i = degree - 1
        octs, idx = divmod(i, 7)
        return 12 * (octave + 1) + tonic + steps[idx] + 12 * octs + sharp

    def harmony(self, bar: int, text: str):
        """Chords from `bar` on: bars separated by '|', chords inside a bar
        share it equally ('Dm7 G7' = two beats each in 4/4).  '%' repeats the
        previous bar's chords.  A chord may carry its length in beats:
        'C:3 G7:1'.

        ``song.harmony(1, "C | G/B | Am7 | Dm7 G7 | C/E | F Fm6 | C/G G7 | C C7")``"""
        b = bar
        last = None
        for chunk in text.split("|"):
            toks = chunk.split()
            if not toks:
                b += 1
                continue
            if toks == ["%"]:
                toks = last
            last = toks
            t0 = self.at(b)
            given = [(_num(x.split(":")[1]) if ":" in x else None) for x in toks]
            free = self.beats_per_bar - sum(g for g in given if g)
            nfree = sum(1 for g in given if g is None)
            t = t0
            for tok, g in zip(toks, given):
                dur = g if g is not None else free / nfree
                sym = tok.split(":")[0]
                self._set_chord(t, chord(sym))
                t += dur
            b += 1
        return self

    def _set_chord(self, t, ch):
        self._chords = [c for c in self._chords if abs(c[0] - t) > 1e-9]
        self._chords.append((t, ch))
        self._chords.sort(key=lambda c: c[0])

    def chord_at(self, t: float) -> Chord | None:
        """The chord sounding at time t (a loop wraps: after the last bar comes bar 1)."""
        if self.loop and t >= self.total_beats - 1e-9:
            t -= self.total_beats
        cur = None
        for ct, ch in self._chords:
            if ct <= t + 1e-9:
                cur = ch
            else:
                break
        return cur

    def chord_spans(self, bars):
        """(t, dur, chord) for every chord change inside the bars."""
        b0, b1 = _span(bars)
        t0, t1 = self.at(b0), self.at(b1 + 1)
        pts = [(t, c) for t, c in self._chords if t0 - 1e-9 <= t < t1 - 1e-9]
        first = self.chord_at(t0)
        if first is not None and (not pts or pts[0][0] > t0 + 1e-9):
            pts.insert(0, (t0, first))
        out = []
        for i, (t, c) in enumerate(pts):
            end = pts[i + 1][0] if i + 1 < len(pts) else t1
            out.append((t, end - t, c))
        return out

    # ----- small helpers -------------------------------------------------------------
    def seed(self, *names) -> int:
        h = hashlib.sha256(("|".join([self.name, *map(str, names)])).encode()).digest()
        return int.from_bytes(h[:8], "little")

    @property
    def seconds(self) -> float:
        return self.total_beats * self.beat_quarters * 60.0 / self.quarter_bpm

    def summary(self) -> str:
        return (f"{self.name}: {self.bars} bars of {self.meter[0]}/{self.meter[1]} at "
                f"{self.tempo:g} = {self.seconds:.1f} s, {self.key_name} {self.mode}, "
                f"{len(self.parts)} parts")
