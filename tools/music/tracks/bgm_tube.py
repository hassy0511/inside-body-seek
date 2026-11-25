"""bgm_tube - the tubes (esophagus, blood vessel): flowing, sliding forward.

KEY AND METRE  A major, 4/4, tempo 132, 32 bars = 58.2 s, loops.
MOOD  flowing and smooth but exciting: rolling harp eighths (sixteenths in C)
carry everything forward like a current; the tune floats on top in long
breaths; a half-time backbeat (snare on 3 only) keeps it gliding, not running.

LEAD  The table suggests piccolo or whistle.  In this soundfont the piccolo
starts at D5 and the whistle at C5, so the motif (A4 E5 ...) would sit an
octave higher, around E6-G#6: shrill after three minutes.  The lead is
therefore the ocarina (GM 79), a soft whistle-like vessel flute that plays
the motif at A4-D6.  The piccolo is kept as a quiet octave double of the
motif in A' only (a sparkle, not a lead).

FORM (8-bar phrases)               thin/full and what changes
  A   bars  1-8   theme             ocarina tune; harp eighths rolling up and
                                    down; bass bouncing (root, root, 5th, octave);
                                    shaker eighths, kick, side stick on 3;
                                    glockenspiel blinks in the motif's rests
  B   bars  9-16  contrast          the strings take the tune in long legato
                                    notes, higher (top D6); harp in quarters,
                                    a low string pad; bass in long notes;
                                    only shaker (kick back from bar 13); the
                                    harp and glockenspiel answer in the rests
  A'  bars 17-24  theme again       fullest: ocarina + piccolo an octave up
                                    (17-20), a cello counter-line answering in
                                    the gaps, marimba off-beat chords, harp
                                    eighths in a new order (rising thirds), bass
                                    octave bounce with scale steps into each
                                    bar, hats + snare on 3, open hat lifts
  C   bars 25-32  the slide         thin at first (25-28): the strings play the
                                    motif in augmentation (twice as slow), a cello
                                    doubles it an octave lower, the harp runs in
                                    sixteenths, long bass, shaker only; from bar 29
                                    the ocarina answers, pad + marimba + kit build
                                    to the fill and the pickup B4 that steps
                                    into the A4 of bar 1

CHORDS (one bar each; two in a bar share it)
  A   A | C#m7 | F#m7 | Bm7 E7 | Dmaj7 | C#m7 F#7 | Bm7 E7sus4 | A A7
      I - iii - vi - ii V; F#7 = V of ii (secondary dominant); A7 = V of IV,
      it pulls into the Dmaj7 that opens B.
  B   Dmaj7 | E/D | C#m7 | F#m7 | Bm7 | C#7 | F#m7 B7 | E7sus4 E7
      E/D (V over a held D in the bass), C#7 = V of vi, B7 = V of V; ends on a
      dominant sus -> 7 that opens A'.
  A'  as A, but bar 21 is Dadd9 (the E on top instead of the C# of Dmaj7, which
      rubbed against the ocarina's high D6) and bar 24 is A E7: the E7 makes a
      deceptive cadence into the F#m7 of bar 25, so C starts away from home.
  C   F#m7 | Dmaj7 | Bm7 E7sus4 | C#m7 F#7 | Bm7 | D Dm6 | A/E F#m7 | Bm7 E7
      Dm6 = IV to iv (borrowed from A minor; the ocarina sings its F
      natural); ii-V in bar 32 back to A.

THE MOTIF (tools/music/motif.py; in A: A E D C# | B C# E)
  bars 1-2    as written (ocarina, A4)          bars 3-4    the tube's own answer: long
                                                gliding notes C#5 E5 A5 | F#5 D5 B4 C#5 E5
  bars 17-20  again in A' (ocarina, piccolo an octave above); bar 20 ends E5 G#5 into A5
  bar 14      its tail rhythm (short-short-long) in the strings, on G# F G#
  bars 25-28  augmentation (stretch 2) in the strings at A5, cello at A4

HIGH POINTS  A: C#6 in bar 5.  B: D6 in bar 13 (strings).  A': D6 in bar 21.
             C: E6 in bars 25-26 (strings, the long E of the augmented motif).

INSTRUMENTS (name: GM instrument, pan, role)
  oca: ocarina 79, centre, melody             sings: strings 48, +6, melody (B, C)
  pic: piccolo 72, +24, sparkle (A' double)   glock: glockenspiel 9, +30, sparkle
  cello: cello 42, -20, counter (A', C)       harp: harp 46, -30, accompaniment
  mar: marimba 12, +34, accompaniment         pad: slow strings 49, -14, harmony
  bass: fingered bass 33, centre              kit: standard kit, centre
"""
from tools.music import motif
from tools.music.score import Song


def grid_bars(kit, first: int, patterns: list):
    """One drum pattern (a dict of lanes) per bar, from bar `first` on."""
    for i, pat in enumerate(patterns):
        kit.grid((first + i, first + i), pat)


def song() -> Song:
    s = Song("bgm_tube", tempo=132, key="A", mode="major", meter=(4, 4), bars=32,
             where="esophagus, blood vessel")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24).section("C", 25, 32)
    s.harmony(1, "A | C#m7 | F#m7 | Bm7 E7 | Dmaj7 | C#m7 F#7 | Bm7 E7sus4 | A A7")
    s.harmony(9, "Dmaj7 | E/D | C#m7 | F#m7 | Bm7 | C#7 | F#m7 B7 | E7sus4 E7")
    s.harmony(17, "A | C#m7 | F#m7 | Bm7 E7 | Dadd9 | C#m7 F#7 | Bm7 E7sus4 | A E7")
    s.harmony(25, "F#m7 | Dmaj7 | Bm7 E7sus4 | C#m7 F#7 | Bm7 | D Dm6 | A/E F#m7 | Bm7 E7")

    # --- parts ----------------------------------------------------------------
    oca = s.part("oca", "ocarina", role="melody", pan=0, volume=110, reverb=0.32)
    sings = s.part("sings", "strings", role="melody", pan=6, volume=124, reverb=0.42, gate=1.0)
    pic = s.part("pic", "piccolo", role="sparkle", pan=24, volume=70, reverb=0.40)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=30, volume=96, reverb=0.40, gate=1.0)
    cello = s.part("cello", "cello", role="counter", pan=-20, volume=90, reverb=0.40, gate=1.0)
    harp = s.part("harp", "harp", role="accomp", pan=-30, volume=96, reverb=0.30, gate=1.0)
    mar = s.part("marimba", "marimba", role="accomp", pan=34, volume=84, reverb=0.26, gate=1.0)
    pad = s.part("pad", "slow_strings", role="harmony", pan=-14, volume=70, reverb=0.48, gate=1.0)
    bass = s.part("bass", "fingered_bass", role="bass", pan=0, volume=100, reverb=0.06)
    kit = s.drums("kit", "standard", volume=80, reverb=0.17)

    oca.dyn({1: 80, 5: 92, 8: 74, 17: 84, 21: 96, 24: 78, 28: 80, 29: 84, 31: 94, 32: 84})
    sings.dyn({9: 82, 13: 98, 14: 92, 16: 80, 25: 82, 26: 94, 28: 84, 29: 70})
    pic.dyn({17: 56, 20: 60})
    glock.dyn({1: 58, 4: 70, 8: 78, 12: 60, 16: 72, 26: 60, 28: 70, 32: 80})
    cello.dyn({17: 66, 21: 76, 24: 66, 25: 64, 28: 72})
    harp.dyn({1: 70, 8: 74, 9: 64, 16: 68, 17: 70, 24: 74, 25: 60, 28: 74, 29: 66, 32: 74})
    mar.dyn({17: 56, 21: 70, 23: 60, 24: 66, 29: 52, 31: 66, 32: 74})
    pad.dyn({9: 48, 12: 60, 13: 66, 15: 58, 16: 50, 29: 46, 31: 62, 32: 70})
    bass.dyn({1: 84, 8: 80, 9: 66, 13: 72, 16: 66, 17: 88, 24: 82, 25: 66, 28: 72, 29: 82, 32: 88})
    kit.dyn({1: 66, 8: 72, 9: 52, 13: 58, 16: 64, 17: 74, 24: 80, 25: 54, 29: 66, 32: 80})

    # --- melody: A (ocarina) -------------------------------------------------------
    oca.place(1, 1, motif.notes(s, 4))                         # A4 E5 D5 C#5 | B4 C#5 E5
    # bars 3-4: the tube's own continuation (long gliding notes), not the title's sequence
    oca.line(3, 1, "C#5:1.5 E5:.5 A5:2 | F#5:1 D5:1 B4:.5 C#5:.5 E5:1")
    oca.line(5, 1, "A5:1 F#5:.5 A5:.5 C#6:1.5 B5:.5 | G#5:1 E5:.5 G#5:.5 A#5:1.5* G#5:.5 |"
                   " F#5:1 D5:.5 F#5:.5 E5:1.5 D5:.5 | C#5:2 r:1 E5:.5 G5:.5*")
    # --- melody: B (strings, long legato notes, higher) --------------------------------
    sings.line(9, 1, "F#5:2 A5:1 C#6:1 | B5:3 G#5:1 | G#5:2 E5:1 G#5:1 | F#5:3 r:1 |"
                     " B5:1 D6:2 B5:.5 A5:.5 | G#5:1.5 F5:.5* G#5:2 | A5:2 D#5:1* F#5:1 |"
                     " E5:2 D5:1 r:1")
    # --- melody: A' (ocarina again, D6 at the top) -----------------------------------
    oca.place(17, 1, motif.notes(s, 4))
    oca.line(19, 1, "C#5:1.5 E5:.5 A5:2 | F#5:1 D5:1 B4:.5 C#5:.5 E5:.5 G#5:.5")   # G#5 leads up into A5
    oca.line(21, 1, "A5:1 F#5:.5 A5:.5 D6:1 C#6:1 | B5:1 G#5:.5 E5:.5 F#5:1 A#5:1* |"
                    " B5:1.5 F#5:.5 E5:1 D5:1 | C#5:2 B4:1 r:1")
    pic.place(17, 1, motif.notes(s, 5))
    pic.line(19, 1, "C#6:1.5 E6:.5 A6:2 | F#6:1 D6:1 B5:.5 C#6:.5 E6:.5 G#6:.5")
    # --- melody: C (augmented motif in the strings, then the ocarina answers) ---------
    sings.place(25, 1, motif.notes(s, 5, stretch=2))           # A5 E6 D6 C#6 | B5 C#6 E6, slow
    cello.place(25, 1, motif.notes(s, 4, stretch=2))           # the same an octave lower
    oca.line(28, 3, "E5:.5 F#5:.5 G#5:.5 A#5:.5* |"
                    " B5:1.5 A5:.5 F#5:1 D5:1 | F#5:1.5 E5:.5 F5:1* D5:1 |"
                    " E5:1 C#5:.5 E5:.5 A5:1 C#6:1 | B5:1 A5:.5 F#5:.5 E5:1 D5:.5 B4:.5")
    oca.auto_swell(2.0)
    sings.auto_swell(1.5)

    # --- counter-line: cello answers in A' ------------------------------------------
    cello.line(17, 1, "E4:2 A3:2 | B3:3 G#3:.5 B3:.5 | A3:2 C#4:2 | B3:2 D4:1 E4:.5 F#4:.5 |"
                      " F#4:4 | E4:2 A#3:2* | D4:2 A3:2 | C#4:2 D4:1 E4:.5 D4:.5")

    # --- sparkle -------------------------------------------------------------------------
    glock.line(2, 4, "C#6:.5 E6:.5")
    glock.line(4, 4, "G#6:.5 B6:.5")
    glock.line(8, 3, "E6:.5 A6:.5 C#7:.5 A6:.5")
    glock.line(12, 4, "A6:.5 C#7:.5")
    glock.line(16, 4, "B6:.5 G#6:.5")
    glock.line(26, 4, "F#6:.5 A6:.5")
    glock.line(28, 4, "E6:.5 G#6:.5")
    glock.line(32, 4, "G#6:.5 B6:.5")

    # --- harmony -----------------------------------------------------------------------
    harp.arp((1, 8), "01234321", 0.5, low="A3", high="A5")
    harp.arp((9, 16), "0213", 1.0, low="A3", high="E5")
    harp.line(12, 4, "C#5:.5 E5:.5")                            # answers in the strings' rest
    harp.line(16, 4, "G#4:.5 B4:.5")
    harp.arp((17, 24), "02421353", 0.5, low="A3", high="A5")
    harp.arp((25, 28), "0123456765432101", 0.25, low="E3", high="E5")
    harp.arp((29, 32), "01234321", 0.5, low="A3", high="A5")

    pad.pad((9, 16), voices=3, low="D3", high="A4")
    pad.pad((29, 32), voices=3, low="E3", high="B4")

    mar.chords((17, 24), ".x.x", voices=3, low="E4", high="E5", gate=0.5)
    mar.arp((29, 32), "0213", 0.5, low="C#4", high="C#5")

    # --- bass --------------------------------------------------------------------------------
    bass.bass((1, 8), "R:1.5 R:.5' 5:1 8:.5 5:.5")
    for b in range(9, 17):
        two = len(list(s.chord_spans((b, b)))) > 1
        bass.bass((b, b), "R:2 R:1.5 5:.5" if two else "R:3 5:1", gate=0.95)
    bass.bass((17, 21), "R:.5 8:.5' R:.5 8:.5' 5:.5 8:.5' R:.5 s:.5")
    # bars 22-23: the scale step on 4.5 fell on A2 (against F#7's A#) and G#2 (against
    # E7sus4's A), so these two bars end on chord tones: A#2 rising to B, B2 falling to A
    bass.bass((22, 22), "R:.5 8:.5' R:.5 8:.5' 5:.5 8:.5' R:.5 3:.5")
    bass.bass((23, 23), "R:.5 8:.5' R:.5 8:.5' 5:.5 8:.5' R:.5 5:.5")
    bass.bass((24, 24), "R:.5 8:.5' R:.5 8:.5' R:1 R:1")
    bass.bass((25, 28), "R:2 R:2", gate=0.95)
    bass.bass((29, 31), "R:1.5 R:.5' 5:1 8:.5 5:.5")
    bass.bass((32, 32), "R:1 5:1 R:1 a:1")

    # --- drums -------------------------------------------------------------------------------
    flow = {"kick": "x.....x.", "stick": "....x...", "shaker": "xoxoxoxo"}
    grid_bars(kit, 1, [flow, flow, flow,
                       dict(flow, kick="x.....xx"),                        # a pickup into bar 5
                       flow,
                       dict(flow, stick=".....x.."),                       # the side stick slides late
                       flow])
    kit.grid((8, 8), {"kick": "x.....x.", "stick": "....x...", "shaker": "xoxo...."})
    kit.fill(8, 3, "stick:.5- stick:.5 high_tom:.5 mid_tom:.5")
    kit.grid((9, 12), {"shaker": "o.x.o.xo"})
    kit.grid((13, 15), {"shaker": "oxoxoxox", "kick": "x.......", "stick": "....x..."})
    kit.grid((16, 16), {"shaker": "oxox....", "kick": "x......."})
    kit.fill(16, 3, "shaker:.5- stick:.5 low_tom:.5 floor_tom:.5")
    kit.hit(17, 1, "crash", 80)
    a2 = {"kick": "x..x..x.", "snare": "....x...", "shaker": "xoxoxoxo", "hat": "x.x.x.x."}
    grid_bars(kit, 17, [a2, a2, a2,
                        dict(a2, kick="x..x..xx"),                         # a pickup into bar 21
                        a2,
                        dict(a2, snare="......x."),                        # the backbeat moves to 4
                        a2])
    kit.hit(20, 4.5, "open_hat", 58)
    kit.hit(22, 4.5, "open_hat", 58)
    kit.grid((24, 24), {"kick": "x.......", "shaker": "xoxo...."})
    kit.fill(24, 3, "stick:.5- stick:.5 low_tom:.25 low_tom:.25 floor_tom:.5")
    kit.grid((25, 28), {"shaker": "o.x.o.xo", "kick": "x......."})
    kit.grid((29, 31), {"kick": "x..x..x.", "snare": "....x...", "shaker": "xoxoxoxo",
                        "tambourine": "..x...x."})
    kit.grid((32, 32), {"kick": "x.......", "shaker": "xo......"})
    # the slide: shaker sixteenths pour into one floor tom on the last eighth
    kit.fill(32, 2, "shaker:.25- shaker:.25 shaker:.25 shaker:.25 shaker:.25- shaker:.25"
                    " shaker:.25 shaker:.25 shaker:.25 shaker:.25 floor_tom:.5>")
    kit.hit(1, 1, "crash", 72)
    return s
