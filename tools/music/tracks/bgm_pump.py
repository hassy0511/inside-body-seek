"""bgm_pump - the heart (right and left): strong, brave, a "lub-dub" pulse.

KEY AND METRE  E-flat major, 4/4, tempo 116, 32 bars = 66.2 s, loops.
MOOD  strong and brave, never frightening: a french horn sings the tune over
a heartbeat.  The heartbeat is a rhythm, not a sound effect: "lub-dub" =
an accented hit on the beat and a softer one an eighth later (beats 1, 1.5
and 3, 3.5), in the kick, the timpani and the bass, with a pause on 2 and 4
that the pizzicato fills.  In B the heart slows to one lub-dub per bar
(timpani alone) and comes back in bar 13.

FORM (8-bar phrases)               thin/full and what changes
  A   bars  1-8   theme             horn tune; string ostinato in eighths (short
                                    bows, Eb3-Eb4, under the horn); pizzicato on
                                    2 and 4 above the horn; lub-dub in kick,
                                    timpani and bass; soft hats; glockenspiel
                                    blinks in the motif's rests
  B   bars  9-16  contrast          C minor colour, thinner and lyrical: the
                                    strings take the tune legato, the horns turn
                                    into a pad, pizzicato plays the lub-dub
                                    chords, timpani one heartbeat per bar, no
                                    kit; the ostinato and kick return in bar 13
                                    and a timpani roll in bar 16 leads to A'
  A'  bars 17-24  theme again       fullest: horn tune with a new top (F5 in
                                    bar 21), a trumpet answers in the gaps and in
                                    thirds above in bar 22, snare backbeat, hats
                                    in eighths, glockenspiel doubles the high
                                    point, a new bass (lub-dub, then 5th, the
                                    5th below and a step into the next bar);
                                    the trumpet runs up in bar 24
  C   bars 25-32  the brave answer  thin at first (25-28): strings sing a high
                                    line over the horn pad, heartbeat in pizzicato
                                    and soft timpani only; from bar 29 the horn
                                    plays the motif BACKWARDS (it now ends on the
                                    home note: the answer to the motif's
                                    question), ostinato, kit and trumpet build to
                                    the fill, and the horn's D4 in bar 32 steps up
                                    into the E-flat of bar 1

CHORDS (one bar each; two in a bar share it)
  A   Eb | Gm7 | Fm7 | Cm7 | Ab | Fm7 Bb7 | Gm7 C7 | Fm7 Bb7
      C7 = V of ii (secondary dominant, the horn sings its E natural);
      bar 8's Bb7 resolves deceptively to the C minor of B.
  B   Cm | Cm/Bb | Ab | G7sus4 G7 | Fm7 | Bb7 | Ab Fm7 | Bb7sus4 Bb7
      (plain Ab in the accompaniment: the strings sing its G as a major 7th
      on top, so horns and pizzicato do not hold G against Ab)
      the bass falls C Bb Ab G; G7 = V of vi; sus4 -> 7 opens A'.
  A'  as A, but 21-22 are Ab Fm7 | Bb7sus4 Bb7 (room for the high F5).
  C   Ab | Gm7 | Fm7 | Abm6 Bb7 | Eb/G | Ab Eb/G | Fm7 Gm7 | Ab Bb7
      Abm6 = IV to iv (borrowed from E-flat minor; the strings sing its
      C-flat, written B); bass G Ab G F G Ab Bb under the retrograde motif,
      then V7 back to Eb.

THE MOTIF (tools/music/motif.py; in Eb: Eb Bb Ab G | F G Bb)
  bars 1-2    as written (horn, Eb4)            bars 3-4    a step higher (sequence)
  bars 17-20  again in A' (horn)
  bars 10, 13 its tail rhythm (short-short-long) in the strings
  bars 29-30  backwards (retrograde) in the horn: Bb G F G | Ab Bb Eb

HIGH POINTS  A: Eb5 in bar 5.  B: Bb5 in bar 14 (strings).  A': F5 in bar 21.
             C: C6 in bar 25 (strings).

INSTRUMENTS (name: GM instrument, pan, role)
  horn: french horn 60, centre, melody     sings: strings 48, +8, melody (B, C)
  tpt: trumpet 56, +22, counter            hpad: french horn 60, -16, harmony (pad)
  ost: strings 48, -28, accompaniment (ostinato)
  pizz: pizzicato 45, +30, harmony         timp: timpani 47, -8, accompaniment
  bass: acoustic bass 32, centre           glock: glockenspiel 9, +34, sparkle
  (the timpani are three drums, Eb2 G2 Bb2: they do not follow the root)
  kit: standard kit, centre
"""
from tools.music import motif
from tools.music.score import Song


def song() -> Song:
    s = Song("bgm_pump", tempo=116, key="Eb", mode="major", meter=(4, 4), bars=32,
             where="heart (right and left)")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24).section("C", 25, 32)
    s.harmony(1, "Eb | Gm7 | Fm7 | Cm7 | Ab | Fm7 Bb7 | Gm7 C7 | Fm7 Bb7")
    s.harmony(9, "Cm | Cm/Bb | Ab | G7sus4 G7 | Fm7 | Bb7 | Ab Fm7 | Bb7sus4 Bb7")
    s.harmony(17, "Eb | Gm7 | Fm7 | Cm7 | Ab Fm7 | Bb7sus4 Bb7 | Gm7 C7 | Fm7 Bb7")
    s.harmony(25, "Ab | Gm7 | Fm7 | Abm6 Bb7 | Eb/G | Ab Eb/G | Fm7 Gm7 | Ab Bb7")

    # --- parts ----------------------------------------------------------------
    horn = s.part("horn", "french_horn", role="melody", pan=0, volume=112, reverb=0.42, gate=0.95)
    sings = s.part("sings", "strings", role="melody", pan=8, volume=120, reverb=0.45, gate=1.0)
    tpt = s.part("tpt", "trumpet", role="counter", pan=22, volume=78, reverb=0.40)
    hpad = s.part("hpad", "french_horn", role="harmony", pan=-16, volume=78, reverb=0.50, gate=1.0)
    ost = s.part("ost", "strings", role="accomp", pan=-28, volume=100, reverb=0.32, gate=0.5)
    pizz = s.part("pizz", "pizzicato", role="harmony", pan=30, volume=92, reverb=0.28)
    timp = s.part("timp", "timpani", role="accomp", pan=-8, volume=100, reverb=0.30, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", pan=0, volume=100, reverb=0.06)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=34, volume=96, reverb=0.40, gate=1.0)
    kit = s.drums("kit", "standard", volume=82, reverb=0.17)

    horn.dyn({1: 82, 5: 94, 8: 76, 17: 86, 21: 100, 24: 80, 29: 86, 31: 96, 32: 86})
    sings.dyn({9: 76, 11: 84, 14: 96, 16: 78, 25: 86, 26: 80, 28: 74})
    tpt.dyn({18: 64, 22: 74, 24: 78, 30: 66})
    hpad.dyn({9: 54, 12: 62, 13: 58, 16: 64, 25: 56, 28: 64})
    ost.dyn({1: 64, 4: 70, 5: 74, 8: 66, 13: 56, 16: 70, 17: 68, 21: 76, 24: 70, 29: 62, 32: 74})
    pizz.dyn({1: 62, 8: 68, 9: 58, 16: 64, 17: 66, 24: 70, 25: 56, 28: 66, 29: 62, 32: 70})
    timp.dyn({1: 76, 8: 80, 9: 64, 13: 70, 17: 80, 24: 86, 25: 60, 28: 70, 29: 78, 32: 84})
    bass.dyn({1: 82, 9: 72, 13: 76, 17: 86, 25: 72, 29: 82, 32: 88})
    glock.dyn({2: 60, 8: 72, 21: 66, 30: 64, 32: 74})
    kit.dyn({1: 70, 8: 76, 13: 56, 16: 70, 17: 78, 24: 84, 29: 70, 32: 84})

    # --- melody: A (horn) ----------------------------------------------------------
    horn.place(1, 1, motif.notes(s, 4))                        # Eb4 Bb4 Ab4 G4 | F4 G4 Bb4
    horn.place(3, 1, motif.notes(s, 4, shift=1))               # F4 C5 Bb4 Ab4 | G4 Ab4 C5
    horn.line(5, 1, "Ab4:.5 C5:.5 Eb5:2 Bb4:.5 C5:.5 | C5:1.5 Ab4:.5 Bb4:1 D5:1 |"
                    " D5:1 Bb4:.5 G4:.5 E4:1* G4:1 | F4:2 r:2")
    # --- melody: B (strings, legato, C minor colour) ----------------------------------
    sings.line(9, 1, "G5:1.5 Eb5:.5 C5:2 | Bb4:.5 C5:.5 Eb5:2 r:1 | C5:1.5 Eb5:.5 G5:2* |"
                     " F5:1 Eb5:1 D5:1 B4:1* | C5:.5 D5:.5 Eb5:1.5 F5:.5 Ab5:1 |"
                     " Bb5:2 Ab5:1 F5:1 | G5:1.5* F5:.5 Eb5:1 C5:1 | Eb5:2 D5:1 r:1")
    horn.line(16, 4, "Bb3:.5 D4:.5")                            # pickup into A'
    # --- melody: A' (horn, F5 at the top) ---------------------------------------------
    horn.place(17, 1, motif.notes(s, 4))
    horn.place(19, 1, motif.notes(s, 4, shift=1))
    horn.line(21, 1, "Ab4:.5 C5:.5 Eb5:1 F5:1.5 Eb5:.5 | Eb5:1 Bb4:.5 C5:.5 D5:1 Bb4:1 |"
                     " D5:1.5 C5:.5 Bb4:1 G4:1 | F4:2 D4:1 r:1")
    # --- melody: C (strings high, then the horn plays the motif backwards) -------------
    sings.line(25, 1, "C6:2 G5:1* Eb5:1 | F5:1 G5:1 Bb5:2 | Ab5:1.5 G5:.5 F5:1 Eb5:1 |"
                      " Eb5:1.5 B4:.5* D5:2")
    horn.place(29, 1, motif.notes(s, 4, retro=True))           # Bb4 G4 F4 G4 | Ab4 Bb4 Eb4
    horn.line(31, 1, "C5:1.5 Ab4:.5 Bb4:1 D5:1 | Eb5:1 C5:.5 Ab4:.5 F4:1 D4:1")
    horn.auto_swell(2.0)
    sings.auto_swell(1.5)

    # --- counter: trumpet answers ----------------------------------------------------
    tpt.line(18, 4, "D5:.5 F5:.5")
    tpt.line(20, 4, "Eb5:.5 G5:.5")
    tpt.line(22, 3, "F5:1 D5:1")
    tpt.line(24, 3, "Bb4:.5 C5:.5 D5:.5 Eb5:.5")
    tpt.line(30, 4, "G4:.5 Bb4:.5")

    # --- sparkle ----------------------------------------------------------------------
    glock.line(2, 4, "D6:.5 F6:.5")
    glock.line(4, 4, "Eb6:.5 G6:.5")
    glock.line(8, 3, "F6:.5 D6:.5 Bb5:.5 D6:.5")
    glock.line(21, 1, "Ab5:.5 C6:.5 Eb6:1 F6:1.5 Eb6:.5")
    glock.line(30, 4, "Bb5:.5 Eb6:.5")
    glock.line(32, 3, "F6:.5 D6:.5 Bb5:.5 D6:.5")

    # --- harmony and ostinato --------------------------------------------------------------
    ost.arp((1, 8), "02130213", 0.5, low="Eb3", high="Eb4")
    ost.arp((13, 16), "0213", 1.0, low="Eb3", high="Eb4", gate=0.8)
    ost.arp((17, 24), "02130213", 0.5, low="Eb3", high="Eb4")
    ost.arp((29, 32), "02130213", 0.5, low="Eb3", high="Eb4")

    pizz.chords((1, 8), ".x.x", voices=3, low="Bb4", high="G5", gate=0.4)
    pizz.chords((9, 16), "Xo..Xo..", voices=3, low="G3", high="C5", gate=0.4)
    pizz.chords((17, 24), ".x.x", voices=3, low="Eb4", high="Ab5", gate=0.4)
    pizz.chords((25, 28), "Xo..Xo..", voices=3, low="G3", high="C5", gate=0.4)
    pizz.chords((29, 32), ".x.x", voices=3, low="Bb4", high="G5", gate=0.4)

    hpad.pad((9, 16), voices=3, low="Eb3", high="C5")
    hpad.pad((25, 28), voices=3, low="Eb3", high="C5")

    # --- heartbeat: timpani and bass ----------------------------------------------------------
    # The timpani are three drums tuned Eb2, G2, Bb2 (not the chord root every bar):
    # each hit takes Eb2 if the chord has an Eb, else Bb2, else G2 (only G7/G7sus4).
    # The bass keeps the roots.
    def drum(t):
        pcs = s.chord_at(t).pcs
        return 39 if 3 in pcs else (46 if 10 in pcs else 43)

    def heart(bars, beats=(1, 3)):
        for b in range(bars[0], bars[1] + 1):
            for bt in beats:
                pt = drum(s.at(b, bt))
                timp.note(b, bt, pt, 0.5, accent=14)                  # lub
                timp.note(b, bt + 0.5, pt, 0.5, accent=-14)           # dub

    heart((1, 8))
    heart((9, 12), beats=(1,))
    heart((13, 15))
    heart((16, 16), beats=(1,))
    for i, v in enumerate((48, 54, 60, 66, 72, 78, 86, 94)):   # roll on Bb into A'
        timp.note(16, 3 + i * 0.25, "Bb2", 0.25, vel=v)
    heart((17, 24))
    heart((25, 28), beats=(1,))
    heart((29, 32))

    bass.bass((1, 8), "R:.5> R:1- 5:.5 R:.5> R:1- 5:.5")
    for b in range(9, 17):
        two = len(list(s.chord_spans((b, b)))) > 1
        bass.bass((b, b), "R:2 R:2" if two else "R:3 5:1", gate=0.95)
    bass.bass((17, 23), "R:.5> R:.5- 5:1 -5:1 s:1")
    bass.bass((24, 24), "R:.5> R:.5- 5:1 R:1 5:1")
    bass.bass((25, 28), "R:2 R:2", gate=0.95)
    bass.bass((29, 31), "R:.5> R:1- 5:.5 R:.5> R:1- 5:.5")
    bass.bass((32, 32), "R:1 5:1 R:1 a:1")

    # --- drums -------------------------------------------------------------------------------
    heart = {"kick": "Xo..Xo..", "hat": "o.o.o.o."}
    kit.grid((1, 7), heart)
    kit.grid((8, 8), {"kick": "Xo..Xo..", "hat": "o.o....."})
    kit.fill(8, 4, "snare:.25- snare:.25 snare:.25 snare:.25")
    kit.grid((13, 15), {"kick": "Xo..Xo..", "ride": "x...x..."})
    kit.hit(17, 1, "crash", 86)
    kit.grid((17, 23), {"kick": "Xo..Xo..", "snare": "..x...x.", "hat": "xoxoxoxo"})
    kit.hit(21, 1, "crash", 72)
    kit.grid((24, 24), {"kick": "Xo..Xo..", "snare": "..x.....", "hat": "xoxo...."})
    kit.fill(24, 3, "snare:.5- snare:.5 mid_tom:.5 floor_tom:.5")
    kit.hit(25, 1, "crash", 64)
    kit.hit(29, 1, "crash", 74)
    kit.grid((29, 31), {"kick": "Xo..Xo..", "snare": "..x...x.", "hat": "xoxoxoxo",
                        "tambourine": "..x...x."})
    kit.grid((32, 32), {"kick": "Xo......", "hat": "xo......"})
    kit.fill(32, 2, "snare:.5- snare:.5 high_tom:.5 mid_tom:.5 low_tom:.25 low_tom:.25 floor_tom:.5")
    kit.hit(1, 1, "crash", 74)
    return s
