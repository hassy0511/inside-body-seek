"""bgm_tummy - the stomach and the small intestine.

KEY AND METRE  G Dorian (G minor with a raised 6th, E natural), 4/4, tempo 100,
24 bars = 57.6 s, loops.  Light swing (0.60) on the eighths for the groove.
MOOD  bubbly, a little mysterious, a groove: a bassoon (a friendly, round
"tummy" voice) over congas, a sliding fretless bass and kalimba bubbles.

FORM (8-bar phrases)                 thin/full and what changes
  A   bars  1-8   groove + theme      bassoon tune, kalimba eighths, muted-trumpet
                                      stabs on the off-beats, fretless bass
                                      riff (root-octave-5th-7th), congas + shaker
                                      + soft kick, vibraphone "bubbles" at phrase
                                      ends; the kalimba starts sparse (bars 1-4)
                                      and fills in to eighths from bar 5
  B   bars  9-16  the bright middle   thinner and warmer: the harmony turns to
                                      B-flat major; a muted trumpet takes the tune
                                      in longer notes, a second bassoon answers low
                                      in its gaps, a warm pad holds the chords,
                                      kalimba bubbles higher and sparser, no stabs,
                                      no kick, bass in long notes, congas only
  A'  bars 17-24  theme again         fullest: bassoon tune with a new second half
                                      (the E-flat 5 of bar 23 comes by a longer climb), the trumpet
                                      answers in the gaps, stabs back, a busier
                                      bass, side stick on 3, kalimba in a new
                                      order; bar 24 (D7) turns back to Gm7 in bar 1

CHORDS (one bar each; two in a bar share it)
  A   Gm7 | Gm9 C9 | Gm7 | Gm7 C9 | Dm7 | Am7 | Eb6 | D7sus4 D7
      i-IV with the Dorian major IV (C9, its E natural is the Dorian colour);
      Gm9 in bar 2 because the motif's A sits on its downbeat; Dm7 Am7 = the
      Dorian v and ii under the motif's sequence; Eb6 = bVI borrowed from G
      Aeolian (a 6 rather than a maj7, so no D rubs against the tune's E-flat);
      D7 = the major V (F# from harmonic minor), here deceptively into E-flat.
  B   Ebmaj7 | Dm7 | Cm7 F7 | Bbadd9 | Ebadd9 | Am7b5 D7 | Gm7 Gm7/F | Ebmaj7 D7
      in B-flat major: IV iii ii-V I, then IV, ii-V of G minor (Am7b5 D7), and
      the bass falling G F Eb D into A'.  add9 instead of maj7 in bars 12-13
      because the trumpet holds the root (no major 7th a semitone below it).
  A'  Gm7 | Gm7 C9 | Gm7 | Gm7 C9 | Bbmaj7 | Am7 | Eb6 | D7sus4 D7
      as A with Bbmaj7 (bIII) in bar 21 under the new second half; the
      last D7 is the turnaround into bar 1.

THE MOTIF (tools/music/motif.py; in G Dorian: G D C Bb | A Bb D)
  bars 1-2    as written (bassoon)              bars 17-18  again (bassoon)
  bars 5-6    sequence on degree 5, a fourth lower (D A G F | E F A, bassoon)
  bar 10      its tail rhythm C D F (trumpet, B)
  bar 18, 20  the trumpet's answers echo the tail's short-short

HIGH POINTS  A: E-flat 5 in bar 7.  B: G5 in bar 13 (trumpet).  A': E-flat 5 in bar 23.
Melody range D4..G5 (17 semitones); the bassoon stays at or below its E-flat 5.

INSTRUMENTS (name: GM instrument, pan, role)
  bassoon: bassoon 70, centre, melody      tpt: muted trumpet 59, +12, melody (B lead,
  bsn2: bassoon 70, -14, counter (B)              answers in A and A')
  stab: muted trumpet 59, -26, harmony     kalimba: kalimba 108, +32, accompaniment
  pad: warm pad 89, -30, harmony (B)       bubbles: vibraphone 11, +38, sparkle
  bass: fretless bass 35, centre, bass     kit: standard kit (congas, shaker, kick,
                                                side stick, bongos in fills)
"""
from tools.music import motif
from tools.music.score import Song


def grid_bars(kit, first: int, patterns: list):
    """One drum pattern (a dict of lanes) per bar, from bar `first` on."""
    for i, pat in enumerate(patterns):
        kit.grid((first + i, first + i), pat)

SW = 0.60   # swing on the off-beat eighths


def song() -> Song:
    s = Song("bgm_tummy", tempo=100, key="G", mode="dorian", meter=(4, 4), bars=24,
             where="stomach, small intestine")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24)
    s.harmony(1, "Gm7 | Gm9 C9 | Gm7 | Gm7 C9 | Dm7 | Am7 | Eb6 | D7sus4 D7")
    s.harmony(9, "Ebmaj7 | Dm7 | Cm7 F7 | Bbadd9 | Ebadd9 | Am7b5 D7 | Gm7 Gm7/F | Ebmaj7 D7")
    s.harmony(17, "Gm7 | Gm7 C9 | Gm7 | Gm7 C9 | Bbmaj7 | Am7 | Eb6 | D7sus4 D7")

    # --- parts ----------------------------------------------------------------
    bsn = s.part("bassoon", "bassoon", role="melody", pan=0, volume=110, reverb=0.30, swing=SW)
    tpt = s.part("tpt", "muted_trumpet", role="melody", pan=12, volume=96, reverb=0.32, swing=SW)
    bsn2 = s.part("bsn2", "bassoon", role="counter", pan=-14, volume=88, reverb=0.32, swing=SW)
    stab = s.part("stab", "muted_trumpet", role="harmony", pan=-26, volume=70, reverb=0.30, swing=SW)
    kal = s.part("kalimba", "kalimba", role="accomp", pan=32, volume=96, reverb=0.28, gate=1.0, swing=SW)
    pad = s.part("pad", "warm_pad", role="harmony", pan=-30, volume=66, reverb=0.45, gate=1.0)
    bub = s.part("bubbles", "vibraphone", role="sparkle", pan=38, volume=86, reverb=0.45, gate=1.0, swing=SW)
    bass = s.part("bass", "fretless_bass", role="bass", pan=0, volume=86, reverb=0.06, swing=SW)
    kit = s.drums("kit", "standard", volume=80, reverb=0.16, swing=SW)

    bsn.dyn({1: 84, 4: 80, 5: 78, 7: 92, 8: 82, 16: 80, 17: 86, 21: 88, 23: 100, 24: 88})
    tpt.dyn({4: 70, 9: 80, 12: 84, 13: 96, 15: 82, 16: 76, 18: 72, 22: 76})
    bsn2.dyn({9: 72, 16: 76})
    stab.dyn({1: 62, 8: 68, 17: 66, 24: 72})
    kal.dyn({1: 70, 8: 74, 9: 62, 16: 66, 17: 72, 24: 78})
    pad.dyn({9: 56, 13: 66, 16: 58})
    bub.dyn({1: 56, 6: 64, 8: 74, 10: 58, 16: 72, 18: 58, 22: 68})
    bass.dyn({1: 84, 9: 76, 17: 82, 24: 84})
    kit.dyn({1: 70, 8: 76, 9: 58, 16: 64, 17: 76, 24: 84})

    # --- melody: A (bassoon) ------------------------------------------------------
    bsn.place(1, 1, motif.notes(s, 4))                                    # G D C Bb | A Bb D
    bsn.line(3, 1, "D5:.5 C5:.5 Bb4:.5 G4:.5 F4:1 G4:1 | Bb4:1.5 G4:.5 E4:1 r:1")
    bsn.place(5, 1, motif.notes(s, 3, shift=4))                           # D A G F | E F A
    bsn.line(7, 1, "G4:1 Bb4:1 Eb5:1.5 D5:.5 | A4:1.5 G4:.5 F#4:1 D4:.5 F#4:.5")
    tpt.line(4, 4, "E5:.5' G5:.5'")                                       # an answer
    # --- melody: B (muted trumpet; a second bassoon answers low) --------------------
    tpt.line(9, 1, "D5:1.5 C5:.5 Bb4:2 | C5:.5 D5:.5 F5:2 r:1 |"
                   " Eb5:1.5 D5:.5 C5:1 A4:1 | Bb4:2 r:1 D5:.5 F5:.5 |"
                   " G5:2.5 F5:.5 Eb5:1 | Eb5:1.5 D5:.5 C5:1 A4:1 |"
                   " Bb4:1.5 A4:.5 G4:2 | G4:2 r:2")
    bsn2.line(9, 3, "G3:1 Bb3:1")
    bsn2.line(10, 4, "A3:.5 C4:.5")
    bsn2.line(12, 3, "D4:.5 C4:.5 Bb3:1")
    bsn2.line(14, 4, "F#3:.5 A3:.5")
    bsn2.line(15, 3, "D4:1 Bb3:1")
    bsn.line(16, 3, "A4:1 F#4:1")                                         # pickup into A'
    # --- melody: A' (bassoon, new second half; trumpet answers) ---------------------
    bsn.place(17, 1, motif.head(s, 4))
    bsn.place(18, 1, motif.tail(s, 4), ok=True)       # A over Gm7: an appoggiatura (see notes)
    bsn.line(19, 1, "D5:.5 C5:.5 Bb4:.5 G4:.5 F4:1 G4:1 | Bb4:1.5 G4:.5 E4:1 r:1 |"
                    " D4:1 F4:1.5 G4:.5 A4:1 | C5:1.5 A4:.5 E4:1 r:1 |"
                    " G4:.5 Bb4:.5 C5:1 Eb5:1.5 D5:.5 | C5:1 A4:1 F#4:1 D4:.5 F#4:.5")
    tpt.line(18, 4, "E5:.5' G5:.5'")
    tpt.line(20, 4, "Bb4:.5' D5:.5'")
    tpt.line(22, 4, "A4:.5 C5:.5")
    bsn.auto_swell(2.0)
    tpt.auto_swell(2.0)

    # bubbles: small rising figures at the phrase ends
    bub.line(2, 4, "D5:.25 G5:.25 Bb5:.5")
    bub.line(6, 4, "E5:.25 A5:.25 C6:.5")
    bub.line(8, 3, "D5:.25- F#5:.25 A5:.25 C6:.25 D6:1>")
    bub.line(10, 4, "D5:.25 F5:.25 A5:.5")
    bub.line(12, 3, "F5:.25 Bb5:.25 D6:.5")
    bub.line(14, 4, "C5:.25 F#5:.25 A5:.5")
    bub.line(16, 3, "D5:.25- F#5:.25 A5:.25 C6:.25 D6:1>")
    bub.line(18, 4, "D5:.25 G5:.25 Bb5:.5")
    bub.line(22, 4, "E5:.25 A5:.25 C6:.5")

    # --- harmony ---------------------------------------------------------------------
    stab.chords((1, 7), "..x..x..", voices=3, low="G3", high="F4", gate=0.4)
    stab.chords((8, 8), "..x..x.x", voices=3, low="G3", high="F4", gate=0.4)
    stab.chords((17, 23), "..x..x..", voices=3, low="G3", high="F4", gate=0.4)
    stab.chords((24, 24), "x.x..x.x", voices=3, low="G3", high="F4", gate=0.4)

    # kalimba above the bassoon; in bars 7 and 23 it leaves out the E-flat a
    # step above the tune's D5, in bar 18 it starts away from the tune's A4
    kal.arp((1, 4), "0r21r3r2", 0.5, low="D5", high="D6")       # sparse first: A grows
    kal.arp((5, 6), "0r21r3r2", 0.5, low="D5", high="D6")      # still sparse
    kal.arp((7, 7), "0121", 0.5, low="G5", high="C6")
    kal.arp((8, 8), "0213", 0.5, low="D5", high="D6")
    kal.arp((9, 16), "0r2r1r3r", 0.5, low="C5", high="C6")
    kal.arp((17, 17), "3120", 0.5, low="D5", high="E6")
    kal.arp((18, 18), "1203", 0.5, low="D5", high="E6")
    kal.arp((19, 22), "3r20r1r2", 0.5, low="D5", high="E6")    # sparse, a new order
    kal.arp((23, 23), "0121", 0.5, low="G5", high="C6")
    kal.arp((24, 24), "3120", 0.5, low="D5", high="E6")

    pad.pad((9, 16), voices=3, low="Bb3", high="G4")

    # --- bass (fretless) --------------------------------------------------------------
    one = "R:1.5 8:.5' r:.5 5:.5 7:.5 5:.5"
    two = "R:1.5 5:.5' R:1.5 5:.5'"
    for b in range(1, 9):
        if b == 8:
            bass.bass((b, b), "R:1.5 5:.5' R:1 a:1")
        else:
            bass.bass((b, b), two if b in (2, 4) else one)
    for b in range(9, 17):
        bass.bass((b, b), "R:1.5 5:.5' R:2" if b in (11, 14, 15, 16) else "R:2.5 5:1 s:.5", gate=0.95)
    busy = "R:.5 r:.5 8:.5' R:.5 5:.5 7:.5 R:1"
    for b in range(17, 25):
        if b == 24:
            bass.bass((b, b), "R:1.5 5:.5' R:1 a:1")
        else:
            bass.bass((b, b), two if b in (18, 20) else busy)

    # --- drums -------------------------------------------------------------------------------
    groove = {"kick": "x.....x.", "conga_lo": "x..x....", "conga_hi": "..x...x.",
              "conga_mute": "....o..o", "shaker": "xoxoxoxo"}
    grid_bars(kit, 1, [groove, groove, groove,
                       dict(groove, kick="x.....xx"),                    # a pickup into bar 5
                       groove,
                       dict(groove, conga_hi="..x....x"),                # the slap moves
                       groove])
    kit.grid((8, 8), {"kick": "x.......", "shaker": "xoxo...."})
    kit.fill(8, 3, "conga_hi:.5 conga_hi:.5- conga_mute:.5 conga_lo:.5")
    bg = {"conga_lo": "x.....x.", "conga_mute": "...o....", "shaker": "o.x.o.x."}
    grid_bars(kit, 9, [bg, bg, bg, dict(bg, conga_mute="...o...o"), bg,
                       dict(bg, conga_lo="x....x.."), bg])
    kit.grid((16, 16), {"conga_lo": "x.......", "shaker": "o.x....."})
    kit.fill(16, 3, "bongo_hi:.5- bongo_hi:.5 bongo_lo:.5 conga_lo:.5")
    a2 = {"kick": "x.....x.", "stick": "....x...", "conga_lo": "x..x....",
          "conga_hi": "..x...xx", "conga_mute": ".o..o..o", "shaker": "xoxoxoxo"}
    grid_bars(kit, 17, [a2, a2, a2, dict(a2, kick="x.....xx"), a2,
                        dict(a2, stick="......x."), a2])
    kit.grid((24, 24), {"kick": "x...x...", "shaker": "xoxo...."})
    kit.fill(24, 3, "bongo_hi:.25- bongo_hi:.25 bongo_lo:.5 conga_hi:.5 conga_lo:.5")
    return s
