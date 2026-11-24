"""bgm_title - the main theme (title, episode select, picture book, ending).

THIS FILE IS THE WORKED EXAMPLE.  Read tools/music/score.py's top comment for
time and pitch, then copy the shape of song() below.  Build and check with
    python -m tools.music build bgm_title     (renders, then checks)
    python -m tools.music check bgm_title     (checks again, redraws the pictures)
and read tools/music/out/bgm_title/report.md, roll.png, spectrogram.png, seam.png.

KEY AND METRE  C major, 4/4, tempo 112 (quarters per minute), 32 bars = 68.6 s, loops.

FORM (8-bar phrases)              thin/full and what changes
  A   bars  1-8   theme            6 parts: flute tune, pizzicato off-beats, marimba
                                   eighths, bass bouncing root-5th-octave, light kit
                                   (side stick, soft hats), glockenspiel at phrase ends
  B   bars  9-16  contrast         thinner: longer notes, horn pad, marimba in quarters,
                                   no kit but a shaker (plus soft kick from bar 13),
                                   bass in long notes, no pizzicato
  A'  bars 17-24  theme again      fullest: glockenspiel doubles the motif an octave up,
                                   horn answers in the gaps, walking bass, pizzicato
                                   and marimba swap jobs, snare instead of side stick
  C   bars 25-32  call / response  thin at first: a second marimba ("call") plays the
                                   motif's head, the flute answers with its tail; from
                                   bar 29 horn pad, arpeggios and kit build to the drum
                                   fill and the pickup in bar 32 that lead into bar 1

CHORDS (one bar each; two in a bar share it)
  A   C | G/B | Am7 | Dm7 G7 | C/E | F Fm6 | C/G G7 | C C7
      Fm6 = IV to iv (borrowed from C minor; the melody sings its A-flat).
      C7 = V of IV: it pulls into the F chord that opens B.
  B   Fmaj7 | Em7 | Dm7 | G7sus4 G7 | E7/G# | Am Am/G | D7/F# | G7sus4 G7
      E7/G# = V of vi and D7/F# = V of V (secondary dominants); the bass falls
      F E D, rises G# A, then G (Am/G) F# G.
  A'  as A.  Melody as A, but E6 held in bar 21 (the top of the piece) and a last
      bar that rests while the horn and the drum fill lead on.
  C   Fadd9 | G/F | Em7 | Am7 | Dm7 | Fm6 | C/G Am7 | Dm7 G7
      ii-V in bar 32 turns back to C in bar 1; the flute's B4 is the leading note.

THE MOTIF (tools/music/motif.py; in C: C G F E | D E G)
  bars 1-2    as written (flute)               bars 3-4    a third higher (sequence)
  bar 10      its tail rhythm D E G (flute)    bars 17-20  again in A' (flute, glock above)
  bars 25, 27 its head on F, then E (call)     bars 26, 28 its tail on F, then E (flute)

HIGH POINTS  A: C6 in bar 5.  B: C6 in bar 14, after the climb through bar 13.
             A': E6 in bar 21 (held 1.5 beats).  C: C6 in bar 31.
Revision 1: the horn pad stays under the flute (top A4), drum bars 4 and 6 of the
7-bar runs differ from the rest, the flute's last pickup is A4 B4 (range A4..E6).

INSTRUMENTS (name: GM instrument, pan, role)            loudness per part: see report.md
  flute: flute 73, centre, melody         call: marimba 12, +8, melody (only in C)
  glock: glockenspiel 9, +28, sparkle     pizz: pizzicato strings 45, -34, harmony
  marimba: marimba 12, +34, accompaniment bass: acoustic bass 32, centre, bass
  horn: french horn 60, -18, counter (pad in B and from bar 29, answering line in A')
  kit: standard kit, centre

THE SHAPE OF song() (copy it for a new piece)
  1. Song(...)              name, tempo, key, mode, metre, bars, where
  2. sections + harmony     the chord chart drives chords(), pad(), arp(), bass(),
                            walk() and the score checks
  3. parts                  instrument, pan, volume (CC 7), reverb send, role
  4. dynamics               part.dyn({bar: velocity}) gives each phrase a shape
  5. notes                  place()/line() for tunes, chords()/arp()/pad() for
                            harmony, bass()/walk() for the bass, grid()/fill()/hit()
                            for drums, auto_swell() for breath on long notes
  6. the last bar           a drum fill and a melodic pickup that lead into bar 1
"""
from tools.music import motif
from tools.music.score import Song


def grid_bars(kit, first: int, patterns: list):
    """One drum pattern (a dict of lanes) per bar, from bar `first` on."""
    for i, pat in enumerate(patterns):
        kit.grid((first + i, first + i), pat)


def song() -> Song:
    s = Song("bgm_title", tempo=112, key="C", mode="major", meter=(4, 4), bars=32,
             where="title, episode select, picture book, ending")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24).section("C", 25, 32)
    s.harmony(1, "C | G/B | Am7 | Dm7 G7 | C/E | F Fm6 | C/G G7 | C C7")
    s.harmony(9, "Fmaj7 | Em7 | Dm7 | G7sus4 G7 | E7/G# | Am Am/G | D7/F# | G7sus4 G7")
    s.harmony(17, "C | G/B | Am7 | Dm7 G7 | C/E | F Fm6 | C/G G7 | C C7")
    s.harmony(25, "Fadd9 | G/F | Em7 | Am7 | Dm7 | Fm6 | C/G Am7 | Dm7 G7")

    # --- parts ----------------------------------------------------------------
    flute = s.part("flute", "flute", role="melody", pan=0, volume=110, reverb=0.32)
    call = s.part("call", "marimba", role="melody", pan=8, volume=104, reverb=0.25, gate=1.0)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=28, volume=108, reverb=0.40, gate=1.0)
    pizz = s.part("pizz", "pizzicato", role="harmony", pan=-34, volume=90, reverb=0.28)
    mar = s.part("marimba", "marimba", role="accomp", pan=34, volume=84, reverb=0.25, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", pan=0, volume=100, reverb=0.06)
    horn = s.part("horn", "french_horn", role="counter", pan=-18, volume=80, reverb=0.45, gate=1.0)
    kit = s.drums("kit", "standard", volume=84, reverb=0.16)

    flute.dyn({1: 80, 5: 90, 8: 74, 9: 72, 13: 86, 14: 90, 16: 76, 17: 84, 21: 96, 24: 80,
               26: 76, 29: 84, 31: 90, 32: 82})
    call.dyn({25: 82, 28: 86})
    glock.dyn({1: 70, 17: 62, 24: 66, 32: 70})
    pizz.dyn({1: 66, 8: 70, 17: 62, 25: 64, 32: 72})
    mar.dyn({1: 60, 8: 64, 9: 54, 16: 58, 17: 62, 24: 66, 25: 58, 32: 66})
    bass.dyn({1: 84, 9: 76, 17: 86, 25: 80, 32: 88})
    horn.dyn({9: 52, 12: 64, 13: 60, 14: 72, 16: 56, 17: 60, 21: 74, 24: 62, 29: 56, 32: 72})
    kit.dyn({1: 70, 8: 76, 9: 56, 17: 76, 24: 82, 25: 62, 29: 72, 32: 84})

    # --- melody: A ---------------------------------------------------------------
    flute.place(1, 1, motif.notes(s, 5))                              # bars 1-2: the motif
    flute.place(3, 1, motif.notes(s, 5, shift=2))                     # bars 3-4: a third higher
    flute.line(5, 1, "G5:1 C6:1.5 B5:.5 A5:1 | A5:1.5 G5:.5 F5:1 Ab5:1 |"
                     " G5:1 E5:.5 C5:.5 D5:1.5 B4:.5 | C5:2 r:.5 E5:.5 G5:.5 Bb5:.5")
    # --- melody: B (longer notes, the motif's tail in bar 10) ---------------------------
    flute.line(9, 1, "A5:1.5 G5:.5 E5:2 | D5:.5 E5:.5 G5:2 r:1 | F5:1.5 E5:.5 C5:2 |"
                     " D5:2 r:1 B4:.5 D5:.5 | E5:1 G#5:1 B5:2 | C6:2.5 B5:.5 A5:1 |"
                     " A5:1 F#5:1 D5:1 E5:.5 F#5:.5 | G5:2 F5:1 D5:1")
    # --- melody: A' (same tune, E6 at the top, rests at the end) ------------------------
    flute.place(17, 1, motif.notes(s, 5))
    flute.place(19, 1, motif.notes(s, 5, shift=2))
    flute.line(21, 1, "G5:1 C6:1 E6:1.5 D6:.5 | A5:1.5 G5:.5 F5:1 Ab5:1 |"
                      " G5:1 E5:.5 C5:.5 D5:1.5 B4:.5 | C5:3 r:1")
    # --- melody: C (call and response) -----------------------------------------------------
    call.place(25, 1, motif.head(s, 5, shift=3))                      # F C B A
    flute.place(26, 1, motif.tail(s, 5, shift=2))                     # F G B
    call.place(27, 1, motif.head(s, 5, shift=2))                      # E B A G
    flute.place(28, 1, motif.tail(s, 5, shift=1))                     # E F A
    flute.line(29, 1, "A5:1.5 G5:.5 F5:1 E5:.5 D5:.5 | Ab5:1.5 G5:.5 F5:1 D5:1 |"
                      " E5:1 G5:1 C6:1 A5:1 | F5:1 D5:1 B4:1 A4:.5 B4:.5")
    flute.auto_swell(2.0)

    # glockenspiel: in A' it doubles the motif an octave up (bars 17-20), then
    # only the flute's longer notes (21-24), so the top stays light
    for n in flute.notes:
        if s.at(17) <= n.t < s.at(21) or (s.at(21) <= n.t < s.at(25) and n.dur >= 1):
            glock.note(1, 1 + n.t, n.pitch + 12, n.dur, ok=n.ok)
    glock.line(2, 4, "E6:.5 G6:.5")
    glock.line(4, 4, "D6:.5 G6:.5")
    glock.line(8, 3, "G6:.5 C7:.5")
    glock.line(12, 3, "B6:.5 G6:.5 F6:.5 D6:.5")
    glock.line(26, 4, "E6:.5 G6:.5")
    glock.line(28, 4, "C7:.5 A6:.5")
    glock.line(32, 4, "D6:.5 G6:.5")

    # --- harmony ---------------------------------------------------------------------
    pizz.chords((1, 8), ".x.x", voices=3, low="G3", high="D5", gate=0.4)
    pizz.arp((17, 24), "0123", 0.5, low="G3", high="G5", gate=0.4)
    pizz.chords((25, 28), "x..x..x.", voices=3, low="G3", high="D5", gate=0.4)
    pizz.arp((29, 32), "0213", 0.5, low="G3", high="G5", gate=0.4)

    mar.arp((1, 8), "0213", 0.5, low="C4", high="C5")
    mar.arp((9, 16), "0121", 1.0, low="C4", high="E5")
    mar.chords((17, 24), ".x.x", voices=3, low="E4", high="E5")
    mar.arp((26, 26), "0213", 0.5, low="C4", high="C5")
    mar.arp((28, 28), "0213", 0.5, low="C4", high="C5")
    mar.arp((29, 32), "0123", 0.5, low="C4", high="C5")

    horn.pad((9, 16), voices=3, low="F3", high="A4")      # under the flute
    horn.line(17, 1, "E4:2 C4:1 G4:1 | D4:2 B3:1 C4:.5 D4:.5 | C4:2 E4:2 | F4:2 F4:1 G4:.5 A4:.5 |"
                     " G4:3 E4:1 | A4:2 Ab4:2 | G4:2 F4:2 | E4:2 G4:1 Bb4:1")
    horn.auto_swell(2.0, bars=(17, 24))
    horn.pad((29, 32), voices=3, low="F3", high="A4")

    # --- bass --------------------------------------------------------------------------------
    bass.bass((1, 8), "R:1.5 5:.5 8:1 5:1")
    for b in range(9, 17):   # long notes; bars with two chords give each its bass
        bass.bass((b, b), "R:2 R:1.5 5:.5" if b in (12, 14, 16) else "R:3 5:1", gate=0.95)
    bass.walk((17, 24))
    bass.bass((25, 28), "R:1.5 R:.5' r:1 5:1")
    bass.walk((29, 31))
    bass.bass((32, 32), "R:1 5:1 R:1 a:1")

    # --- drums -------------------------------------------------------------------------------
    light = {"kick": "x...x.x.", "stick": "..x...x.", "hat": "xoxoxoxo"}
    grid_bars(kit, 1, [light, light, light,
                       dict(light, kick="x...x.xx", open_hat=".......x"),   # a pickup into bar 5
                       light,
                       dict(light, stick="..x..x.."),                      # the backbeat moves
                       light])
    kit.grid((8, 8), {"kick": "x...x...", "stick": "..x.....", "hat": "xoxo...."})
    kit.fill(8, 3, "snare:.5- snare:.5 snare:.25- snare:.25 snare:.5")
    kit.grid((9, 12), {"shaker": "o.x.o.xo"})
    kit.grid((13, 15), {"shaker": "oxoxoxox", "kick": "x...x...", "stick": "......x."})
    kit.fill(16, 3, "high_tom:.5- mid_tom:.5 low_tom:.5 floor_tom:.5")
    kit.hit(17, 1, "crash", 84)
    a2 = {"kick": "x..xx.x.", "snare": "..x...x.", "hat": "xoxoxoxo"}
    grid_bars(kit, 17, [a2, a2, a2, dict(a2, hat="xoxoxox."), a2,
                        dict(a2, snare="..x....x"), a2])
    kit.hit(20, 4.5, "open_hat", 60)
    kit.grid((24, 24), {"kick": "x...x...", "snare": "..x.....", "hat": "xoxo...."})
    kit.fill(24, 3, "snare:.5 mid_tom:.5 low_tom:.5 floor_tom:.5")
    kit.grid((25, 28), {"kick": "x.......", "stick": "....x...", "hat": "x.x.x.x."})
    kit.grid((29, 31), {"kick": "x...x...", "snare": "..x...x.", "hat": "xoxoxoxo",
                        "tambourine": "..x...x."})
    kit.grid((32, 32), {"kick": "x.......", "hat": "xo......"})
    kit.fill(32, 2, "snare:.5- snare:.5 high_tom:.5 mid_tom:.5 low_tom:.25 low_tom:.25 floor_tom:.5")
    kit.hit(1, 1, "crash", 78)
    return s
