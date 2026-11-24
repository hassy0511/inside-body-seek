"""jingle_karte - the karte is complete: a warm cadence.

KEY AND METRE  G major (the key of bgm_karte), 4/4, tempo 92 (bgm_karte's tempo),
               1 bar + 0.7 s ring = about 3.3 s, does not loop.

FORM  one bar, a ii - V - I cadence
  beats 1-2  the motif's tail (A5 B5 D6, "short-short-looong") in the flute over
             Am9 and D7sus4 to D7; electric piano chords, strings swelling
  beats 3-4  the home chord G6/9 held: the flute settles on B5 (the third: warm, at
             rest), the glockenspiel rises D6 G6 B6 above it, a triangle, the bass lands on G2

CHORDS  Am9:1 D7sus4:.5 D7:.5 G6/9:2

THE MOTIF  its tail (in G: A B D) on beats 1-2, flute; the cadence answers its open
           ending by stepping down to B.

INSTRUMENTS (name: GM instrument, pan, role)
  flute: flute 73, centre, melody         ep: electric piano 4, -22, harmony
  strings: slow strings 49, +20, harmony  glock: glockenspiel 9, +30, sparkle
  bass: acoustic bass 32, centre, bass    kit: orchestra kit (triangle)
"""
from tools.music import motif
from tools.music.score import Song


def song() -> Song:
    s = Song("jingle_karte", tempo=92, key="G", mode="major", bars=1, loop=False, tail=0.7,
             where="karte complete")
    s.section("all", 1, 1)
    s.harmony(1, "Am9:1 D7sus4:.5 D7:.5 G6/9:2")

    flute = s.part("flute", "flute", role="melody", pan=0, volume=110, reverb=0.34)
    ep = s.part("ep", "epiano", role="harmony", pan=-22, volume=92, reverb=0.35, gate=1.0)
    strings = s.part("strings", "slow_strings", role="harmony", pan=20, volume=80, reverb=0.45, gate=1.0)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=30, volume=112, reverb=0.45, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", pan=0, volume=96, reverb=0.08)
    kit = s.drums("kit", "orchestra", volume=74, reverb=0.35)

    flute.dyn({1: 80, (1, 3): 86})
    ep.dyn({1: 64})
    strings.dyn({1: 60})
    glock.dyn({1: 70})
    bass.dyn({1: 76})

    tail = motif.tail(s, 5)                      # A5 B5 D6 (short, short, long)
    flute.place(1, 1, [(o, d if i < 2 else 1.0, q) for i, (o, d, q) in enumerate(tail)])
    flute.line(1, 3, "B5:2_")
    flute.auto_swell(1.5)

    ep.chords((1, 1), "x-xxx---", voices=4, low="E3", high="D5")
    strings.pad((1, 1), voices=3, low="D4", high="B4")
    glock.line(1, 3, "D6:.25 G6:.25 B6:1.5")     # above the flute's B5, not on it
    bass.line(1, 1, "A2:1 D2:1 G2:2_")
    kit.hit(1, 3, "triangle", 70)
    return s
