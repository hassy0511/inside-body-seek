"""jingle_enter - the enter-the-body screen: the ship shrinks and dives in.

KEY AND METRE  C major (the main theme's key), 4/4, tempo 138, 2 bars + 0.5 s ring
               = about 4.0 s, does not loop.

FORM  one gesture in two halves
  bar 1, beats 1-2   the shrink: a bell-tree shimmer and a rising pentatonic run in
                     sixteenths (harp G3..B4, celesta an octave up) over soft strings
                     only (no bass yet); B4 is the leading note into the tune
  bar 1 beat 3 -     the dive: the motif's head (C5 G5 F5 E5) in the flute, its last
  bar 2              note held; the bass enters under it and steps C E G C and the chord lands on
                     C in bar 2 beat 2 with a soft bass drum, a triangle and a glocken-
                     spiel arpeggio that rises while the chord rings

CHORDS  C:3 Em:1 | G7sus4:1 C:3
        Em under the G5 of the motif; G7sus4 under its F5 (the 4th of the chord
        resolving to E with the C chord).

THE MOTIF  its head (bar 1 of the motif: C5 G5 F5 E5) from bar 1 beat 3, flute.

INSTRUMENTS (name: GM instrument, pan, role)
  flute: flute 73, centre, melody          harp: harp 46, -22, accompaniment (the run)
  cel: celesta 8, +26, sparkle (run)       glock: glockenspiel 9, +30, sparkle (last arpeggio)
  strings: slow strings 49, -12, harmony   bass: acoustic bass 32, centre, bass
  kit: orchestra kit (bell tree, triangle, bass drum)
"""
from tools.music import motif
from tools.music.score import Song


def song() -> Song:
    s = Song("jingle_enter", tempo=138, key="C", mode="major", bars=2, loop=False, tail=0.5,
             where="enter-the-body screen")
    s.section("all", 1, 2)
    s.harmony(1, "C:3 Em:1 | G7sus4:1 C:3")

    flute = s.part("flute", "flute", role="melody", pan=0, volume=112, reverb=0.32)
    harp = s.part("harp", "harp", role="accomp", pan=-22, volume=100, reverb=0.35, gate=1.0)
    cel = s.part("cel", "celesta", role="sparkle", pan=26, volume=92, reverb=0.40, gate=1.0)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=30, volume=86, reverb=0.45, gate=1.0)
    strings = s.part("strings", "slow_strings", role="harmony", pan=-12, volume=82, reverb=0.45, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", pan=0, volume=96, reverb=0.08)
    kit = s.drums("kit", "orchestra", volume=80, reverb=0.30)

    flute.dyn({1: 82, (1, 4): 92, (2, 2): 86})
    harp.dyn({1: 62, (1, 2.5): 80})
    cel.dyn({1: 56, (1, 2.5): 72})
    glock.dyn({2: 66})
    strings.dyn({1: 48, (1, 3): 60, 2: 72})
    bass.dyn({1: 74, 2: 82})

    # the shrink: a rising pentatonic run (passing notes on purpose)
    run = "G3:.25* A3:.25* C4:.25* D4:.25* E4:.25* G4:.25* A4:.25* B4:.25*"
    harp.line(1, 1, run)
    cel.line(1, 1, run, transpose=12)
    kit.hit(1, 1, "bell_tree", 74)

    # the dive: the motif's head, its last note held
    flute.place(1, 3, motif.head(s, 5)[:3])          # C5 G5 F5
    flute.line(2, 2, "E5:3_")                         # E5 held over the C chord
    flute.auto_swell(2.0)

    strings.pad((1, 2), voices=3, low="E3", high="G4")
    harp.line(2, 2, "C4:.5 E4:.5 G4:.5 C5:1.5")
    glock.line(2, 2, "G5:.5 C6:.5 E6:.5 G6:1.5")
    bass.line(1, 1, "r:2 C2:1 E2:1 | G2:1 C2:3_")       # enters with the tune
    kit.hit(2, 2, "kick", 70)
    kit.hit(2, 2, "triangle", 66)
    return s
