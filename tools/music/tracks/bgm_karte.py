"""bgm_karte - the karte (the three lines, the quiz, the stars).

MOOD  warm, proud, at rest: the case is solved.  The shared motif comes back
      in long notes (twice as slow), like a deep breath after the adventure.

KEY AND METRE  G major, 4/4, tempo 92, straight eighths, 24 bars = 62.6 s, loops.

FORM (8-bar phrases)              thin/full and what changes
  A   bars  1-8   the motif, slow   4-5 parts: flute sings the motif in long
                                    notes (augmented, bars 1-4), then an answer
                                    climbing to E6 in bar 7; electric piano in
                                    broken chords (quarters); bass in long notes;
                                    a glockenspiel twinkle at the phrase ends;
                                    only a shaker from bar 5
  B   bars  9-16  looking back      a new colour: the piano takes the tune (it
                                    turns to C, then the borrowed C minor 6),
                                    the flute answers in its gaps, strings pad,
                                    electric piano in half notes, kick and rim
  A'  bars 17-24  proud again       fullest: the flute's motif with the
                                    glockenspiel in unison, a strings counter-
                                    line underneath, electric piano comping in a
                                    pushed eighth rhythm, a moving bass, light
                                    kit; bar 24 ends with a soft tom fill and the
                                    flute's F#5 leading note into the G5 of bar 1

CHORDS (one bar each; two in a bar share it)
  A   G6 | Em7 | Am7 D | Bm7 | Cmaj7 | Am7 D7 | Bm7 E7 | Am7 D7
      G6, not Gmaj7, so no F# rubs against the motif's G.
      E7 = V of ii (secondary dominant), into Am7.
  B   Cmaj7 | Bm7 | Am7 | Gmaj7/B | Cmaj7 | Cm6 | G/D E7 | Am7 D7sus4 D7
      Cm6 = IV to iv (borrowed from G minor; the piano sings its E-flat);
      G/D E7 again pulls to Am7, and the sus4 resolves into bar 17.
  A'  as A, with Am7 D7sus4 D7 in the last bar, back into G6.

THE MOTIF (tools/music/motif.py; in G: G D C B | A B D)
  bars 1-4    augmented (stretch 2), flute: G5 (2) D6 (3) C6 (1) B5 (2) | A5 B5 D6 (4)
  bar 13      its tail (B C E), piano with the flute softly in unison, at the top of B
              (the flute stays in unison, softly, through bar 16)
  bars 17-20  augmented again, flute with the glockenspiel in unison

HIGH POINTS  A: E6 in bar 7.  B: E6 in bar 13 (the motif's tail), Eb6 in bar 14.
             A': E6 in bar 23, held longer.
Revision 1: the strings drop the 7th in bars 9 and 12 (as in 13), the B accompaniment
is softer and the piano louder so B's tune does not sink, and drum bars 4 and 6 of
the 7-bar runs in B and A' differ from the rest.

INSTRUMENTS (name: GM instrument, pan, role)
  flute: flute 73, centre, melody            piano: piano 0, +6, melody (B only)
  ep: electric piano 4, -26, harmony         strings: slow strings 49, +22, harmony
                                             (pad in B, counter-line in A')
  glock: glockenspiel 9, +32, sparkle        bass: fingered bass 33, centre, bass
  kit: standard kit, centre (shaker, kick, rim, soft hats)
  Tempo, key and length as in the table.  Added to the table's colours: a
  bass and a light kit (the brief asks for bass and percussion layers), and the
  acoustic piano as the B tune so the repeat of A (flute) sounds fresh.
"""
from tools.music import motif
from tools.music.score import Song


def grid_bars(kit, first: int, patterns: list):
    """One drum pattern (a dict of lanes) per bar, from bar `first` on."""
    for i, pat in enumerate(patterns):
        kit.grid((first + i, first + i), pat)


def song() -> Song:
    s = Song("bgm_karte", tempo=92, key="G", mode="major", meter=(4, 4), bars=24,
             where="karte and quiz")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24)
    s.harmony(1, "G6 | Em7 | Am7 D | Bm7 | Cmaj7 | Am7 D7 | Bm7 E7 | Am7 D7")
    s.harmony(9, "Cmaj7 | Bm7 | Am7 | Gmaj7/B | Cmaj7 | Cm6 | G/D E7 | Am7:2 D7sus4:1 D7:1")
    s.harmony(17, "G6 | Em7 | Am7 D | Bm7 | Cmaj7 | Am7 D7 | Bm7 E7 | Am7:2 D7sus4:1 D7:1")

    # --- parts ----------------------------------------------------------------
    flute = s.part("flute", "flute", role="melody", pan=0, volume=108, reverb=0.34)
    piano = s.part("piano", "piano", role="melody", pan=6, volume=127, reverb=0.30)
    ep = s.part("ep", "epiano", role="harmony", pan=-26, volume=88, reverb=0.30, gate=0.95)
    strings = s.part("strings", "slow_strings", role="harmony", pan=22, volume=72, reverb=0.45, gate=1.0)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=32, volume=100, reverb=0.40, gate=1.0)
    bass = s.part("bass", "fingered_bass", role="bass", pan=0, volume=96, reverb=0.06)
    kit = s.drums("kit", "standard", volume=80, reverb=0.18)

    flute.dyn({1: 78, 3: 84, 4: 76, 5: 80, 7: 92, 8: 78, 9: 70, 16: 72, 17: 82, 19: 88,
               20: 80, 23: 96, 24: 80})
    piano.dyn({9: 108, 12: 110, 13: 118, 14: 116, 16: 106})
    ep.dyn({1: 62, 4: 66, 8: 64, 9: 44, 16: 44, 17: 64, 23: 70, 24: 66})
    strings.dyn({9: 38, 13: 48, 16: 44, 17: 80, 21: 86, 23: 96, 24: 82})
    glock.dyn({1: 60, 4: 72, 8: 62, 12: 76, 16: 64, 17: 54, 20: 70, 24: 62})
    bass.dyn({1: 78, 8: 76, 9: 62, 16: 66, 17: 84, 24: 84})
    kit.dyn({5: 56, 8: 60, 9: 52, 16: 58, 17: 66, 24: 76})

    # --- melody: A (the motif in long notes, then an answer) -----------------------
    flute.place(1, 1, motif.notes(s, 5, stretch=2))               # G D C B | A B D, slowly
    flute.line(5, 1, "E5:1.5 G5:.5 B5:2 | C6:1.5 B5:.5 A5:1 F#5:1 |"
                     " B5:1 D6:1 E6:1.5 D6:.5 | C6:2 A5:1 r:1")
    # --- melody: B (the piano; the flute answers in the gaps) -------------------------
    piano.line(9, 1, "G5:3 E5:1 | F#5:1.5 D5:.5 B4:2 | C5:1 E5:1 A5:1.5 G5:.5 | F#5:2 D5:2")
    piano.place(13, 1, motif.tail(s, 5, shift=1))                 # B C E: the tail, on top
    piano.line(14, 1, "Eb6:1* C6:1 A5:1 G5:1 | B5:1.5 A5:.5 G#5:1* E5:1 | C6:1.5 B5:.5 A5:1 F#5:1")
    flute.line(10, 3, "D6:.5 B5:.5 A5:1")
    flute.line(12, 3, "B5:.5 A5:.5 D6:1")
    flute.line(13, 4, "C6:.5 B5:.5")
    flute.place(13, 1, motif.tail(s, 5, shift=1), vel=60)         # unison with the piano: the B top
    for n in list(piano.notes):                                    # and softly through bars 14-16,
        if s.at(14) <= n.t < s.at(17):                             # so B's tune does not sink
            flute.note(1, 1 + n.t, n.pitch, n.dur, vel=58, ok=n.ok)
    # --- melody: A' (the motif again, a longer top at the end) --------------------------
    flute.place(17, 1, motif.notes(s, 5, stretch=2))
    flute.line(21, 1, "E5:1.5 G5:.5 B5:1 G5:1 | C6:1.5 B5:.5 A5:1 F#5:1 |"
                      " B5:1 D6:1 E6:2 | C6:2 A5:1.5 F#5:.5")
    flute.auto_swell(2.0)
    piano.auto_swell(2.0)

    # --- glockenspiel: twinkles at the phrase ends, the motif in unison in A' ---------
    glock.line(4, 3, "F#6:.5 A6:.5 D7:1")
    glock.line(8, 4, "D6:.5 F#6:.5")
    glock.line(12, 4, "B6:.5 D7:.5")
    glock.line(16, 4, "A6:.5 F#6:.5")
    for n in flute.notes:
        if s.at(17) <= n.t < s.at(21):
            glock.note(1, 1 + n.t, n.pitch, n.dur, ok=n.ok)
    glock.line(20, 3, "F#6:.5 A6:.5 D7:1")
    glock.line(24, 4, "D6:.5 F#6:.5")

    # --- harmony ---------------------------------------------------------------------
    ep.arp((1, 8), "0213", 1.0, low="G3", high="D5")
    ep.chords((9, 16), "x...x...", voices=3, low="D3", high="G4")
    ep.chords((17, 24), "x...x.x.", voices=4, low="E3", high="C5", gate=0.7)

    strings.pad((9, 16), voices=3, low="D3", high="D4")
    # bars 9, 12, 13: no 7th in the strings, where it would rub a semitone against
    # the e-piano in the same low register (the e-piano and the tune keep the colour)
    for bar, voices in ((9, ("C3", "E3", "G3")), (12, ("B2", "D3", "G3")), (13, ("C3", "E3", "G3"))):
        strings.clear(bar)
        for v in voices:
            strings.note(bar, 1, v, 4)
    strings.line(17, 1, "B3:2 D4:2 | E4:2 G4:2 | E4:2 F#4:2 | F#4:2 D4:2 |"
                        " E4:2 G4:2 | E4:2 F#4:2 | D4:2 D4:1 E4:1 | C4:2 A3:1 C4:1")
    strings.auto_swell(2.0, bars=(17, 24))

    # --- bass --------------------------------------------------------------------------------
    for b in range(1, 9):
        bass.bass((b, b), "R:2 R:2" if b in (3, 6, 7, 8) else "R:3 5:1", gate=0.95)
    for b in range(9, 17):
        bass.bass((b, b), "R:2 R:1 R:1" if b in (15, 16) else "R:2 5:1.5 R:.5")
    for b in range(17, 24):
        two = b in (19, 22, 23)
        bass.bass((b, b), "R:1.5 5:.5 R:1.5 5:.5" if two else "R:1.5 5:.5 3:1 5:1")
    bass.bass((24, 24), "R:2 R:1 a:1")

    # --- drums -------------------------------------------------------------------------------
    kit.grid((5, 7), {"shaker": "o.x.o.x."})
    kit.grid((8, 8), {"shaker": "o.x.o.xx"})
    b = {"kick": "x.....x.", "stick": "....x...", "shaker": "o.x.o.x."}
    grid_bars(kit, 9, [b, b, b, dict(b, shaker="o.x.o.xx"), b, dict(b, stick="....x..x"), b])
    kit.grid((16, 16), {"kick": "x.......", "stick": "....x..."})
    kit.fill(16, 4, "stick:.5- stick:.5")
    kit.hit(17, 1, "crash", 60)
    a2 = {"kick": "x..x..x.", "stick": "..x...x.", "hat": "x.x.x.x.", "shaker": ".o.o.o.o"}
    grid_bars(kit, 17, [a2, a2, a2, dict(a2, kick="x..x..xx", open_hat=".......o"), a2,
                        dict(a2, stick="..x....x"), a2])
    kit.grid((24, 24), {"kick": "x.......", "hat": "x.x....."})
    kit.fill(24, 3, "stick:.5- low_tom:.5- floor_tom:.5 floor_tom:.5")      # its own fill
    return s
