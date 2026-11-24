"""bgm_mouth - the mouth (teeth are a xylophone).

KEY AND METRE  D major (B in G major), 4/4, tempo 120, 32 bars = 64.0 s, loops.
MOOD  bouncy and playful: short mallet notes over a staccato tuba and wood
blocks; the teeth "play" the tune.  The mouth is the first place after the
title screen, so it keeps the title's patterns out on purpose: no pizzicato
off-beats or marimba eighths in A, no snare backbeat, no string pad, its own
C section and its own fills (revision 1).

FORM (8-bar phrases)               thin/full and what changes
  A   bars  1-8   theme             xylophone tune; marimba chords in a 3+3+2
                                    "teeth" bounce; tuba oom-pah (root on 1,
                                    fifth on 3, staccato); wood blocks and kick
                                    in a skipping groove, no hats; one
                                    glockenspiel blink in bar 2
  B   bars  9-16  contrast, G major thinner: a second marimba sings the tune in
                                    dotted (long-short) rhythms, the xylophone
                                    only answers in the gaps; pizzicato plays the
                                    chords as half notes; the tuba in half time;
                                    kick, low block and cabasa only
  A'  bars 17-24  theme again       fullest: xylophone tune doubled an octave
                                    lower by the marimba, pizzicato enters with
                                    the 3+3+2 bounce, the tuba bounces on every beat,
                                    kick + blocks + hats (no snare), a stop in
                                    bar 24
  C   bars 25-32  "tooth game"      big tooth, small tooth: over a D pedal the
                                    tuba calls the motif's head at double speed
                                    (beats 1-2) and the xylophone answers with
                                    the head upside down (beats 3-4); from bar 29
                                    the xylophone climbs in eighths over marimba
                                    chords, pizzicato and a low marimba counter-
                                    line, to a wood-block fill and the C#5 in
                                    bar 32 that leads into the D5 of bar 1

CHORDS (one bar each; two in a bar share it)
  A   D | A/C# | Bm7 | Em7 A7 | D | Em7 A7 | D/A A7 | D D7/C
      bars 5-8 are new against the title: I, ii-V, I6/4-V, and D7/C (V of
      IV) points to G, the key of B.
  B   G | Em7 | Am7 D7 | G | C | G/B | Am7 D7 | Em7 A7
      (in G major) I-vi-ii-V twice, with IV in bar 13; Em7 A7 = ii-V of D
      takes the music back home for A'.
  A'  D | A/C# | Bm7 | Em7 A7 | D/F# | Em7 A7 | D/A A7 | D Asus4
      a stop on a suspended chord in bar 24 instead of the cadence.
  C   D | G/D | Em7/D | A7/D | Bm7 | G6 | Em7 A7 | D A7
      four bars over a pedal D (IV, ii, V7 above it), then down by fifths
      Bm7 to G6, ii-V, and A7 back into bar 1.

THE MOTIF (tools/music/motif.py; in D: D A G F# | E F# A)
  bars 1-2    as written (xylophone)        bars 17-18  again in A' (xylophone + marimba)
  bar 12      its tail rhythm (short-short-long) in the B tune
  bars 25-28  its head at double speed in the tuba on D, G, E, A, each answered
              by the head turned upside down in the xylophone

HIGH POINTS  A: D6 in bar 5.  B: E6 in bar 13.  A': E6 in bar 21.  C: E6 in bar 30.
Melody range A4..E6 (19 semitones; the marimba octave double in A' is a counter part).

INSTRUMENTS (name: GM instrument, pan, role)
  xylo: xylophone 13, centre, melody       call: marimba 12, +10, melody (tune in B,
                                                  props up the xylophone's long notes)
  dbl: marimba 12, -10, counter (the tune an octave lower in A', a slow
       counter-line in bars 29-32)
  glock: glockenspiel 9, +30, sparkle (quiet: a few blinks)
  pizz: pizzicato strings 45, -32, harmony  marimba: marimba 12, +36, accompaniment
  tuba: tuba 58, centre, bass (and the "big tooth" in C)
  kit: standard kit, centre (wood blocks 76/77, kick, cabasa, hats, triangle)
  The table asks for "woodblock": the kit's wood blocks are used (one drum
  channel), so the woodblock sits in the groove with the kick.
"""
from tools.music import motif
from tools.music.score import Song


def grid_bars(kit, first: int, patterns: list):
    """One drum pattern (a dict of lanes) per bar, from bar `first` on."""
    for i, pat in enumerate(patterns):
        kit.grid((first + i, first + i), pat)


def song() -> Song:
    s = Song("bgm_mouth", tempo=120, key="D", mode="major", meter=(4, 4), bars=32,
             where="mouth")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24).section("C", 25, 32)
    s.set_key(9, "G", "major")
    s.set_key(17, "D", "major")
    s.harmony(1, "D | A/C# | Bm7 | Em7 A7 | D | Em7 A7 | D/A A7 | D D7/C")
    s.harmony(9, "G | Em7 | Am7 D7 | G | C | G/B | Am7 D7 | Em7 A7")
    s.harmony(17, "D | A/C# | Bm7 | Em7 A7 | D/F# | Em7 A7 | D/A A7 | D Asus4")
    s.harmony(25, "D | G/D | Em7/D | A7/D | Bm7 | G6 | Em7 A7 | D A7")

    # --- parts ----------------------------------------------------------------
    xylo = s.part("xylo", "xylophone", role="melody", pan=0, volume=120, reverb=0.28, gate=0.8)
    call = s.part("call", "marimba", role="melody", pan=10, volume=110, reverb=0.26, gate=1.0)
    dbl = s.part("dbl", "marimba", role="counter", pan=-10, volume=86, reverb=0.26, gate=1.0)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=30, volume=80, reverb=0.40, gate=1.0)
    pizz = s.part("pizz", "pizzicato", role="harmony", pan=-32, volume=88, reverb=0.28)
    mar = s.part("marimba", "marimba", role="accomp", pan=36, volume=80, reverb=0.25, gate=1.0)
    tuba = s.part("tuba", "tuba", role="bass", pan=0, volume=58, reverb=0.06)
    kit = s.drums("kit", "standard", volume=76, reverb=0.16)

    xylo.dyn({1: 94, 5: 108, 6: 104, 8: 90, 10: 84, 12: 88, 14: 92, 16: 88,
              17: 98, 21: 112, 22: 106, 24: 94, 25: 96, 28: 100, 29: 100, 30: 110, 31: 104, 32: 98})
    call.dyn({4: 70, 8: 70, 9: 84, 12: 90, 13: 100, 14: 96, 16: 86, 20: 72, 24: 72})
    dbl.dyn({17: 70, 22: 80, 24: 70, 29: 66, 31: 74, 32: 70})
    glock.dyn({1: 62, 16: 66, 18: 58, 24: 64, 32: 68})
    pizz.dyn({9: 64, 13: 70, 16: 64, 17: 64, 24: 70, 29: 66, 32: 74})
    mar.dyn({1: 62, 8: 66, 25: 56, 29: 60, 32: 66})
    tuba.dyn({1: 86, 8: 84, 9: 72, 16: 76, 17: 86, 25: 84, 28: 90, 29: 84, 32: 90})
    kit.dyn({1: 72, 8: 78, 9: 56, 16: 64, 17: 72, 23: 76, 24: 84, 25: 62, 29: 74, 32: 86})

    # --- melody: A (xylophone) ---------------------------------------------------
    xylo.place(1, 1, motif.notes(s, 5))                                    # D A G F# | E F# A
    xylo.line(3, 1, "B5:.5' A5:.5' F#5:1 D5:.5' F#5:.5' B5:1 |"
                    " G5:1.5 F#5:.5 E5:1 C#5:1 |"
                    " F#5:.5' A5:.5' D6:1 C#6:.5'* B5:.5' A5:1 |"
                    " B5:.5' G5:.5' E5:1 G5:.5' B5:.5' A5:1 |"
                    " F#5:.5' D5:.5' A4:1 B4:.5'* C#5:.5' E5:1 |"
                    " D5:2 r:.5 F#5:.5 A5:.5 C6:.5")
    # --- melody: B (G major; a marimba sings in dotted rhythms, the xylophone answers)
    call.line(9, 1, "D5:.75 B4:.25 D5:.5 G5:.5 B5:1 G5:1 |"
                    " G5:.75 E5:.25 G5:.5 B5:.5 D6:2 |"
                    " C6:1 A5:.5 F#5:.5 D5:1 F#5:1 |"
                    " r:1 B4:.5 D5:.5 G5:2 |"
                    " E6:.75 D6:.25 C6:.5 G5:.5 E5:1 G5:1 |"
                    " D6:.75 C6:.25 B5:.5 G5:.5 D5:2 |"
                    " C6:.5 B5:.5 A5:.5 G5:.5 F#5:1 A5:1 |"
                    " G5:1 E5:.5 G5:.5 A5:1 C#5:1")
    xylo.line(10, 4, "B5:.5' D6:.5'")                                      # answers
    xylo.line(12, 1, "D6:.5' B5:.5'")
    xylo.line(14, 4.5, "G5:.5'")
    call.auto_swell(2.0, bars=(9, 16))
    # --- melody: A' (xylophone, marimba doubles an octave lower) ------------------
    xylo.place(17, 1, motif.notes(s, 5))
    xylo.line(19, 1, "B5:.5' A5:.5' F#5:1 D5:.5' F#5:.5' B5:1 |"
                     " G5:1.5 F#5:.5 E5:1 C#5:1 |"
                     " F#5:.5' A5:.5' E6:1 C#6:.5'* B5:.5' A5:1 |"
                     " B5:.5' G5:.5' E5:1 G5:.5' B5:.5' A5:1 |"
                     " F#5:.5' D5:.5' A4:1 B4:.5'* C#5:.5' E5:1 |"
                     " D5:2 r:2")
    for n in list(xylo.notes):
        if s.at(17) <= n.t < s.at(25):
            dbl.note(1, 1 + n.t, n.pitch - 12, n.dur, ok=n.ok)
    # a xylophone cannot hold a note: the singing marimba props up the phrase ends
    for bar, beat, pitch, dur in ((4, 1, "G5", 1.5), (8, 1, "D5", 2), (20, 1, "G5", 1.5),
                                  (24, 1, "D5", 2)):
        call.note(bar, beat, pitch, dur)
    # --- melody: C (the tooth game, then the climb) ---------------------------------------
    for bar, shift, oct_ans in ((25, 0, 6), (26, 3, 5), (27, 1, 6), (28, 4, 5)):
        tuba.place(bar, 1, motif.head(s, 2, shift=shift, stretch=0.5))       # big tooth
        xylo.place(bar, 3, motif.head(s, oct_ans, shift=shift, stretch=0.5, invert=True))  # small tooth
    xylo.line(29, 1, "D5:.5' F#5:.5' A5:.5' D6:.5' B5:1 A5:1 |"
                     " G5:.5' B5:.5' D6:.5' B5:.5' E6:1 D6:1 |"
                     " B5:.5' G5:.5' E5:1 G5:.5' E5:.5' C#5:1 |"
                     " D5:.5' F#5:.5' A5:1 G5:.5' E5:.5' C#5:1")
    # a slow counter-line under the climb (contrary motion)
    dbl.line(29, 1, "F#4:2 D4:2 | B4:2 G4:2 | G4:2 G4:1 A4:1 | F#4:2 E4:1 G4:1")

    # glockenspiel: a few quiet blinks (no accents; the xylophone owns the top)
    glock.line(2, 4, "A6:.25 F#6:.25 D6:.5")
    glock.line(16, 4.5, "E6:.5")
    glock.line(18, 4, "C#6:.5 E6:.5")
    glock.line(22, 4.5, "G6:.5")
    glock.line(32, 4.5, "E6:.5")

    # --- harmony ---------------------------------------------------------------------
    mar.chords((1, 8), "x..x..x.", voices=3, low="D4", high="D5", gate=0.5)    # 3+3+2 teeth
    mar.chords((25, 28), "x.......", voices=3, low="D4", high="D5", gate=0.6)   # one soft chord
    mar.chords((29, 31), "x..x..x.", voices=3, low="D4", high="D5", gate=0.5)
    mar.chords((32, 32), "x..x....", voices=3, low="D4", high="D5", gate=0.5)

    pizz.chords((9, 16), "x...x...", voices=3, low="D3", high="B4", gate=0.9)  # half notes
    pizz.chords((17, 23), "x..x..x.", voices=3, low="F#3", high="D5", gate=0.35)
    pizz.chords((24, 24), "x.x.....", voices=3, low="F#3", high="D5", gate=0.4)
    pizz.chords((29, 31), ".x.x.x.x", voices=3, low="F#3", high="A4", gate=0.35)

    # --- bass (tuba) --------------------------------------------------------------------
    tuba.bass((1, 7), "R:1' r:1 5:1' r:1")                                  # oom-pah
    tuba.bass((8, 8), "R:1' 5:1' R:2")
    tuba.bass((9, 16), "R:1' r:1 5:1' r:1")                                 # half time
    tuba.bass((17, 23), "R:1' 5:1' R:1' -5:1'")                             # a bounce on every beat
    tuba.bass((24, 24), "R:1' R:1' R:1' r:1")
    for b in range(25, 29):                                                 # the pedal D,
        tuba.note(b, 3, "D2", 1, gate=0.45)                                 # under the answers
    tuba.bass((29, 31), "R:1' 5:1' R:1' 5:1'")
    tuba.bass((32, 32), "R:1' 5:1' R:1' a:1'")

    # --- drums -------------------------------------------------------------------------------
    skip = {"kick": "x..x.x..", "block_hi": "..x...x.", "block_lo": ".x...x.."}
    grid_bars(kit, 1, [skip, skip, skip,
                      dict(skip, kick="x..x.x.x"),                         # pickup into bar 5
                      skip,
                      dict(skip, block_hi="..x....x"),                     # the block moves
                      skip])
    kit.grid((8, 8), {"kick": "x..x....", "block_hi": "..x....."})
    kit.fill(8, 3, "block_hi:.5 block_lo:.5 block_hi:.25- block_hi:.25 block_lo:.5")
    soft = {"kick": "x.......", "block_lo": "....x...", "cabasa": "..x...x."}
    grid_bars(kit, 9, [soft, soft, soft, dict(soft, cabasa="..x...xx"), soft,
                       dict(soft, block_lo="....x..x"), soft])
    kit.grid((16, 16), {"kick": "x.......", "cabasa": "..x....."})
    kit.fill(16, 3, "block_lo:.25- block_lo:.25 block_hi:.25- block_hi:.25 block_lo:.5 block_hi:.5")
    kit.hit(17, 1, "triangle", 70)
    full = {"kick": "x...x.x.", "block_hi": "..x...x.", "block_lo": ".......x", "hat": "x.x.x.x."}
    grid_bars(kit, 17, [full, full, full, dict(full, kick="x...x.xx"), full,
                        dict(full, block_hi="..x....x", block_lo="......x."), full])
    kit.grid((24, 24), {"kick": "x.x.x...", "block_lo": "x.x.x..."})
    kit.fill(24, 4, "block_hi:.25- block_hi:.25 block_lo:.5")
    kit.grid((25, 28), {"kick": "x.......", "block_lo": "....x...", "hat": "..x...x."})
    kit.grid((29, 31), {"kick": "x...x...", "block_hi": ".x.x.x.x", "hat": "x.x.x.x.",
                        "block_lo": "..x...x."})
    kit.grid((32, 32), {"kick": "x.......", "hat": "x......."})
    kit.fill(32, 2, "block_lo:.25 block_lo:.25- block_hi:.25 block_hi:.25- block_lo:.25 block_hi:.25"
                    " block_lo:.25 block_hi:.25 block_hi:.25- block_hi:.25 block_lo:.25 block_hi:.25")
    kit.hit(1, 1, "triangle", 66)
    return s
