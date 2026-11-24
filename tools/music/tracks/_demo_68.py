"""_demo_68 - a tiny worked example in 6/8 with drums (not used by the game).

Files whose name starts with '_' are examples: `python -m tools.music build _demo_68`
renders them into tools/music/out/_demo_68/ only (no file in godot/assets/audio).

6/8 in this library:
  * a bar has 6 beats; a beat is an EIGHTH.  The felt pulses are beats 1 and 4.
  * durations are in eighths: 3 = dotted quarter, 6 = dotted half, 1.5 = dotted eighth.
  * Song(tempo=66) means 66 dotted quarters per minute.
  * two chords in a bar split it 3 + 3 ("E A/E").  Grids for chords() and
    grid() have 6 characters for eighths (12 for sixteenths).
  * the strong beats for the checks are 1 and 4.  swing is ignored in 6/8.
  * motif.notes() uses the 6/8 rhythm of the motif automatically.
  * part.walk() is for 4/4; in 6/8 write the bass with part.bass().

E major with a Lydian tint (A# over the E chord in bar 5, marked '*'), 8 bars:
  A  bars 1-4   E | C#m7 | Amaj7 | Bsus4 B
  A' bars 5-8   E | Aadd9 | F#7/A# (V of V) | Bsus4 B
Motif: bars 1-2 (flute, as written in 6/8), bars 5-6 a third higher (harp).

The one warning left on purpose: the motif's A on beat 6 of bar 1 is a
passing note over E while the harp and vibes hold G# (a minor 9th for one
eighth).  It passes quickly and resolves down to G#, so it stays.
"""
from tools.music import motif
from tools.music.score import Song


def song() -> Song:
    s = Song("_demo_68", tempo=66, key="E", mode="major", meter=(6, 8), bars=8,
             where="example only")
    s.section("A", 1, 4).section("A'", 5, 8)
    s.harmony(1, "E | C#m7 | Amaj7 | Bsus4 B | E | Aadd9 | F#7/A# | Bsus4 B")

    flute = s.part("flute", "flute", role="melody", pan=0, volume=108, reverb=0.35)
    harp = s.part("harp", "harp", role="counter", pan=-30, volume=96, reverb=0.40, gate=1.0)
    vib = s.part("vibes", "vibraphone", role="harmony", pan=30, volume=84, reverb=0.40, gate=1.0)
    strings = s.part("strings", "slow_strings", role="harmony", pan=-12, volume=78, reverb=0.45, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", volume=96, reverb=0.06)
    kit = s.drums("kit", "brush", volume=90, reverb=0.2)

    flute.dyn({1: 76, 3: 86, 4: 72, 5: 80, 7: 88, 8: 74})
    harp.dyn({1: 62, 8: 70})
    vib.dyn({1: 50, 3: 62, 5: 52, 7: 66, 8: 56})
    strings.dyn({1: 48, 3: 62, 4: 52, 7: 66, 8: 54})
    bass.dyn({1: 76, 3: 86, 5: 78, 7: 90, 8: 80})
    kit.dyn({1: 60, 4: 66, 8: 72})

    # melody: the motif in 6/8, then an answer; durations in eighths
    flute.place(1, 1, motif.notes(s, 5))
    flute.line(3, 1, "E5:2 D#5:1 C#5:3 | B4:3 r:3")
    flute.line(5, 1, "r:3 B5:2 A#5:1* | B5:3 C#6:2 B5:1 | A#5:3 F#5:2 E5:1 | F#5:6")
    flute.auto_swell(3)
    harp.place(5, 1, motif.notes(s, 4, shift=2))     # bars 5-6: the motif a third up, low
    harp.arp((1, 4), "012321", 1, low="E3", high="E5")
    harp.arp((7, 8), "012345", 1, low="E3", high="B5")

    vib.chords((1, 8), "x--.x-", voices=3, low="G#3", high="E5")
    strings.pad((1, 8), voices=3, low="B3", high="G#4")

    bass.bass((1, 8), "R:3 5:2 R:1")

    kit.grid((1, 7), {"kick": "x.....", "snare": "...x..", "hat": "x.xx.x"})
    kit.grid((8, 8), {"kick": "x.....", "hat": "x.x..."})
    kit.fill(8, 4, "snare:.5 snare:.5 snare:.5 low_tom:.5 floor_tom:1")
    return s
