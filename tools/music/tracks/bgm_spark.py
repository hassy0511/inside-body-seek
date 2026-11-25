"""bgm_spark - the brain: twinkling, clever, curious.

KEY AND METRE  B-flat Lydian (B-flat major with E natural), 4/4, tempo 108,
28 bars = 62.2 s, loops.  The scale is set to Lydian, so the motif's fourth
degree is E: the motif reads Bb F E D | C D F, and the raised fourth is the
"bright idea" colour of the piece.  Lydian chords used: C6 / C7 / C/Bb
(II over I) and Em7b5.

FORM (8 + 8 + 8 + 4)             thin/full and what changes
  A   bars  1-8   theme            thin at first: synth lead (the motif), electric
                                   piano in a few syncopated chords, bass
                                   bouncing, woodblocks ticking like a clock;
                                   from bar 5 pizzicato arpeggios, side stick and
                                   hats; the celesta answers in the lead's rests
                                   (bars 2, 4, 8)
  B   bars  9-16  contrast         G minor colour, flowing eighths that start
                                   after a breath (beat 1 is a rest in bars 9,
                                   11, 13: "curious" questions); the tune moves to
                                   the electric piano; soft synth pad, celesta
                                   twinkles in quarters, pizzicato off-beats,
                                   walking bass, hats instead of blocks (celesta
                                   above the tune, D6-D7; it rests in 13-14 where the
                                   line climbs to F6 in bar 13 and E6 in bar 14)
  A'  bars 17-24  theme again      fullest: the celesta doubles the motif an
                                   octave up (17-20), the pizzicato plays its own
                                   answering line in the lead's gaps, the bass
                                   bounces root-fifth-octave, snare on 3, blocks
                                   come back on the off-beats; new ending with
                                   D6 in bar 21
  T   bars 25-28  tag (call and    thin: a music box plays the motif's head, the
                  response)        lead answers with its tail, twice, over a
                                   B-flat pedal (bar 26 is C/Bb, the Lydian
                                   chord); bars 27-28 build with a drum fill;
                                   C7 and the lead's run E D C fall into the
                                   B-flat of bar 1

CHORDS (one bar each; two in a bar share it)
  A   Bb6 | Dm7 | Gm7 | C6 | Bb6 | Am7 D7 | Gm7 C7 | Fsus4 F
      Bb6, not Bbmaj7: the tune starts on B-flat, and a held A in the chord
      would rub a minor ninth against it.
      C6 = II of Lydian (its E is the raised fourth); D7 = V of ii (F# marked);
      Fsus4 F = V, which leads to the G minor of B.
  B   Gm7 | Am7 | Bbadd9 | C7sus4 C7 | Gm7 | Em7b5 A7 | Dm7 G7 | C7sus4 C7
      Em7b5 A7 = ii-V into D minor (secondary dominant, C# marked);
      G7 = V of V (B natural marked); C7sus4 C7 (II7) returns to B-flat.
  A'  as A for bars 17-22, then Gm7 C7 | F/A C7.
  T   Bb6 | C/Bb | Gm7 | C7sus4 C7   (back to Bb6 in bar 1)

THE MOTIF (tools/music/motif.py; in B-flat Lydian: Bb F E D | C D F)
  bars 1-2    as written (lead)              bars 3-4    the brain's own answer
                                             F5 D5 F5 G5 F5 | E5 G5 A5 G5 (lead)
  bars 17-20  again (lead, celesta an octave up); bar 20 climbs further: E5 G5 A5 C6 A5,
              a step below the D6 of bar 21
  bars 25, 27 its head on Bb, then on D (music box, call)
  bars 26     its tail on G (lead, answer: G A C)
  bar 13      B's climb (G Bb D F) borrows the motif's long-short pickup shape.

HIGH POINTS  A: C6 in bar 6.  B: F6 in bar 13.  A': D6 in bar 21 (then C6).
             T: C6 in bar 28, falling into bar 1.

INSTRUMENTS (name: GM instrument, pan, role)
  lead: chiff lead 83 (a soft breathy synth), centre, melody
  epmel: electric piano 4, +6, melody (B only)
  call: music box 10, +12, melody (tag only)
  celesta: celesta 8, +32, sparkle     ep: electric piano 4, -26, harmony
  pizz: pizzicato strings 45, +28, accompaniment (counter-line in A')
  pad: warm pad 89, -14, harmony (B and tag)
  bass: acoustic bass 32, centre      kit: standard kit (woodblocks, stick, hats)
"""
from tools.music import motif
from tools.music.score import Song


def grid_bars(kit, first: int, patterns: list):
    """One drum pattern (a dict of lanes) per bar, from bar `first` on."""
    for i, pat in enumerate(patterns):
        kit.grid((first + i, first + i), pat)


def song() -> Song:
    s = Song("bgm_spark", tempo=108, key="Bb", mode="lydian", meter=(4, 4), bars=28,
             where="brain")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24).section("T", 25, 28)
    s.harmony(1, "Bb6 | Dm7 | Gm7 | C6 | Bb6 | Am7 D7 | Gm7 C7 | Fsus4 F")
    s.harmony(9, "Gm7 | Am7 | Bbadd9 | C7sus4 C7 | Gm7 | Em7b5 A7 | Dm7 G7 | C7sus4 C7")
    s.harmony(17, "Bb6 | Dm7 | Gm7 | C6 | Bb6 | Am7 D7 | Gm7 C7 | F/A C7")
    s.harmony(25, "Bb6 | C/Bb | Gm7 | C7sus4 C7")
    two = {6, 7, 8, 12, 14, 15, 16, 22, 23, 24, 28}

    # --- parts ----------------------------------------------------------------
    lead = s.part("lead", 83, role="melody", pan=0, volume=122, reverb=0.32)
    epmel = s.part("epmel", "epiano", role="melody", pan=6, volume=124, reverb=0.30)
    call = s.part("call", "music_box", role="melody", pan=12, volume=122, reverb=0.32, gate=1.0)
    cel = s.part("celesta", "celesta", role="sparkle", pan=32, volume=104, reverb=0.38, gate=1.0)
    ep = s.part("ep", "epiano", role="harmony", pan=-26, volume=88, reverb=0.28)
    pizz = s.part("pizz", "pizzicato", role="accomp", pan=28, volume=92, reverb=0.28)
    pad = s.part("pad", "warm_pad", role="harmony", pan=-14, volume=72, reverb=0.45, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", pan=0, volume=80, reverb=0.06)
    kit = s.drums("kit", "standard", volume=82, reverb=0.16)

    lead.dyn({1: 78, 3: 84, 4: 76, 5: 82, 6: 92, 8: 74, 17: 82, 21: 94, 24: 78,
              25: 76, 28: 86})
    epmel.dyn({9: 74, 11: 80, 13: 92, 14: 90, 16: 76})
    call.dyn({25: 80, 27: 86})
    cel.dyn({1: 70, 8: 74, 9: 56, 13: 64, 16: 58, 17: 66, 21: 70, 24: 72})
    ep.dyn({1: 62, 5: 68, 8: 72, 17: 66, 22: 74, 24: 70})
    pizz.dyn({5: 60, 8: 66, 9: 58, 13: 64, 16: 60, 17: 70, 21: 76, 24: 70, 27: 62, 28: 70})
    pad.dyn({9: 44, 12: 60, 13: 68, 15: 50, 16: 58, 25: 40, 27: 56, 28: 66})
    bass.dyn({1: 80, 5: 84, 8: 80, 9: 76, 13: 84, 16: 80, 17: 86, 21: 90, 24: 84,
              25: 74, 27: 80, 28: 88})
    kit.dyn({1: 58, 5: 66, 8: 72, 9: 60, 16: 70, 17: 74, 24: 80, 25: 54, 27: 66, 28: 80})

    # --- melody: A --------------------------------------------------------------
    lead.place(1, 1, motif.notes(s, 4))                                  # Bb F E D | C D F
    # bars 3-4: the brain's own continuation (the motif's long-short rhythm, its own
    # contour; E5 on C6 is the Lydian "bright idea" note), not the title's sequence.
    # Bar 4 stops at A5 so that C6 in bar 6 stays the one high point of A.
    lead.line(3, 1, "F5:1 D5:.5 F5:.5 G5:1.5 F5:.5 | E5:1 G5:1 A5:1.5 G5:.5")
    lead.line(5, 1, "D5:.5 F5:.5 Bb5:1 G5:1.5 F5:.5 | A5:1 E5:1 F#5:1* C6:1 |"
                    " Bb5:1.5 A5:.5 G5:1 E5:1 | F5:2 r:1 C5:.5 D5:.5")
    cel.line(2, 4, "F6:.5 A6:.5")                                         # answers
    cel.line(4, 4, "E6:.5 G6:.5")
    cel.line(8, 3, "C6:.5 F6:.5")

    # --- melody: B (electric piano; questions that start after a breath) -----------
    epmel.line(9, 1, "r:.5 D5:.5 G5:.5 A5:.5 Bb5:1 A5:.5 G5:.5 | E5:1.5 C5:.5 r:1 E5:.5 G5:.5 |"
                     " r:.5 F5:.5 Bb5:.5 C6:.5 D6:1 C6:.5 Bb5:.5 | G5:2 E5:1 r:.5 D5:.5 |"
                     " r:.5 G5:.5 Bb5:.5 D6:.5 F6:1.5 D6:.5 | E6:1.5 D6:.5 C#6:1* A5:1 |"
                     " D6:1.5 C6:.5 B5:1* G5:1 | F5:1 G5:1 E5:1 C5:1")

    # --- melody: A' (motif again, new ending) --------------------------------------------
    lead.place(17, 1, motif.notes(s, 4))
    lead.line(19, 1, "F5:1 D5:.5 F5:.5 G5:1.5 F5:.5 | E5:1 G5:.5 A5:.5 C6:1.5 A5:.5")
    lead.line(21, 1, "D5:.5 F5:.5 Bb5:1 D6:1.5 C6:.5 | C6:1 A5:1 F#5:1* A5:1 |"
                     " Bb5:1.5 A5:.5 G5:1 E5:1 | F5:1.5 G5:.5 E5:1 r:1")
    for n in lead.notes:                                                  # celesta doubles
        if s.at(17) <= n.t < s.at(21):
            cel.note(1, 1 + n.t, n.pitch + 12, n.dur, ok=n.ok)
    cel.line(22, 4, "D6:.5 F#6:.5*")
    cel.line(24, 4, "G6:.5 Bb6:.5")
    # pizzicato answering line in the lead's long notes and rests
    pizz.line(17, 3, "D4:.5 F4:.5 | A4:1 r:1 G4:.5 A4:.5 Bb4:1 | r:2 C5:.5 Bb4:.5 A4:1 |"
                     " G4:1 r:1 C5:.5 Bb4:.5 G4:1 | r:2 F4:.5 G4:.5 A4:1 |"
                     " C5:1 r:1 D5:.5 C5:.5 A4:1 | G4:1 r:1 Bb4:.5 A4:.5 G4:1 | F4:1 r:1 G4:.5 E4:.5 C4:1")

    # --- tag: call and response --------------------------------------------------------
    call.place(25, 1, motif.head(s, 4))                                   # Bb F E D
    lead.place(26, 1, motif.tail(s, 4, shift=4))                          # G A C
    call.place(27, 1, motif.head(s, 4, shift=2))                          # D A G F
    lead.line(28, 1, "C6:1 Bb5:.5 G5:.5 E5:1 D5:.5 C5:.5")
    lead.auto_swell(2.0)

    # --- harmony ----------------------------------------------------------------------
    ep.chords((1, 4), "x.....x.", voices=3, low="F3", high="D5", gate=0.6)
    ep.chords((5, 8), "x..x..x.", voices=3, low="F3", high="D5", gate=0.6)
    ep.chords((17, 24), "x..x..x.", voices=3, low="F3", high="D5", gate=0.6)
    ep.chords((27, 28), "x..x..x.", voices=3, low="F3", high="D5", gate=0.6)
    pizz.arp((5, 8), "0213", 0.5, low="F3", high="F5", gate=0.4)
    pizz.chords((9, 16), ".x.x", voices=3, low="D3", high="A4", gate=0.4)
    pizz.arp((27, 28), "0123", 0.5, low="F3", high="F5", gate=0.4)
    # celesta above the tune; it rests in 13-14, where the tune climbs to F6/E6 inside
    # its D6-D7 band, and gives one answer under the tune's held C#6
    cel.arp((9, 12), "0r21r3r1", 0.5, low="D6", high="D7")
    cel.line(14, 3.5, "A6:.5")
    cel.arp((15, 16), "0r21r3r1", 0.5, low="D6", high="D7")
    pad.pad((9, 16), voices=3, low="D4", high="A4")
    pad.pad((25, 28), voices=3, low="D4", high="A4")

    # --- bass ------------------------------------------------------------------------------
    for b in range(1, 9):
        pat = "R:1.5 5:.5 R:1.5 5:.5" if b in two else ("R:1.5 5:.5' r:1 5:1'" if b == 2 else "R:1.5 5:.5' r:1 8:1'")
        bass.bass((b, b), pat)
    bass.walk((9, 15))
    # walk() approaches chromatically from below; in bar 9 (Ab2 under the tune's A5) and
    # bar 11 (B2 under C in tune, pizzicato and pad) that rubbed a minor 9th, so these two
    # approach from above with chord tones: Bb2 down to A, D3 down to C
    for n in bass.notes:
        if s.at(9) + 3 - 1e-6 <= n.t < s.at(10) and n.pitch == 44:
            n.pitch = 46
        if s.at(11) + 3 - 1e-6 <= n.t < s.at(12) and n.pitch == 47:
            n.pitch = 50
    bass.bass((16, 16), "R:2 R:1 -5:1")                                     # C C G2, up to Bb2
    for b in range(17, 25):
        pat = "R:1 5:1 R:1 5:1" if b in two else ("R:1 5:1 3:1 5:1" if b == 18 else "R:1 5:1 8:1 5:1")
        bass.bass((b, b), pat)
    bass.bass((25, 26), "R:3 5:1", gate=0.95)                               # B-flat pedal
    bass.bass((27, 27), "R:1.5 5:.5 R:1 5:1")
    bass.bass((28, 28), "R:2 R:1 -5:1")                                     # C C G2, up to Bb2

    # --- drums ---------------------------------------------------------------------------------
    clock = {"kick": "x.......", "block_hi": "x.o.x.o.", "block_lo": "..x...x."}
    kit.grid((1, 4), clock)
    kit.grid((5, 7), {"kick": "x...x...", "stick": "..x...x.", "hat": ".o.o.o.o", "block_hi": "x...x..."})
    kit.grid((8, 8), {"kick": "x...x...", "stick": "..x.....", "hat": ".o.o...."})
    kit.fill(8, 3, "block_lo:.5- block_hi:.25 block_hi:.25 block_lo:.25 block_hi:.25 triangle:.5")
    b1 = {"kick": "x..x....", "stick": "....x...", "hat": "x.x.x.xo"}
    grid_bars(kit, 9, [b1, b1, b1,
                       dict(b1, kick="x..x...x"),                          # a pickup into bar 13
                       b1,
                       dict(b1, stick="......x."),                         # the backbeat moves to 4
                       b1])
    kit.grid((16, 16), {"kick": "x.......", "hat": "xoxo...."})
    kit.fill(16, 3, "stick:.25- stick:.25 block_hi:.5 high_tom:.5 block_lo:.5")
    kit.hit(17, 1, "crash", 76)
    a2 = {"kick": "x..x..x.", "snare": "....x...", "hat": "xoxoxoxo", "block_hi": "...x...x"}
    grid_bars(kit, 17, [a2, a2, a2,
                        dict(a2, kick="x..x..xx"),                         # a pickup into bar 21
                        a2,
                        dict(a2, snare=".....x.."),                        # the backbeat comes late
                        a2])
    kit.grid((24, 24), {"kick": "x..x....", "snare": "....x...", "hat": "xoxo...."})
    kit.fill(24, 4, "block_hi:.25- block_lo:.25 snare:.5")
    kit.grid((25, 26), {"block_hi": "x...x...", "triangle": "x......."})
    kit.grid((27, 27), {"kick": "x...x...", "stick": "..x...x.", "hat": "xoxoxoxo"})
    kit.grid((28, 28), {"kick": "x.......", "hat": "xo......"})
    kit.fill(28, 2, "stick:.5- stick:.25 stick:.25 high_tom:.5 mid_tom:.5 snare:.5 triangle:.5>")   # the spark: up to a triangle "ping"
    kit.hit(1, 1, "triangle", 70)
    return s
