"""bgm_air - the lungs (when there is no boss) and the nose: airy, floating, light.

KEY AND METRE  E major with a Lydian tint (A-sharp), 6/8, dotted quarter = 66,
32 bars = 58.2 s, loops.
  Why 32 bars and not "about 24": at 66 dotted quarters a 6/8 bar lasts 1.82 s,
  so 24 bars would be 43.6 s, under the 48 s that a loop must last.  32 bars
  (four 8-bar phrases) keeps the tempo and the 8-bar shape.
  The Lydian colour: bar 6 (A# in F#7/A#), bar 17 (the motif with A# instead of
  A: set_key lydian for that bar) and the whole of section C bars 25-28, which
  float over an E pedal with F#/E (II over I, the Lydian chord).

FORM (8-bar phrases)              thin/full and what changes
  A   bars  1-8   theme            thin at first: flute tune, harp rocking in
                                   eighths, bass in dotted quarters, a shaker
                                   breath; from bar 5 a soft string pad, the
                                   brush kit (kick on 1, brush on 4); the
                                   vibraphone answers at the ends of the phrases
                                   (bars 4 and 8)
  B   bars  9-16  contrast         the tune moves to the strings, lower and in
                                   long notes; the flute only answers with small
                                   motif-tail figures; "oohs" voices replace the
                                   string pad; harp in quarters; bass long notes
                                   that step to the next chord; triangle, no snare
  A'  bars 17-24  theme again      fullest: the motif in its Lydian form (A#);
                                   the vibraphone gets its own counter-line in
                                   dotted quarters (inner line C# - C in bar 22,
                                   IV to iv); harp sweeps up through six notes;
                                   the bass bounces root-fifth-octave; shaker
                                   in eighths; top note F#6 in bar 22
  C   bars 25-32  call / response  E Lydian over an E pedal, thin: the vibraphone
                                   plays the motif's head, the flute answers with
                                   its tail (twice, the second time a step up);
                                   from bar 29 everything comes back and climbs
                                   to E6 in bar 31; bar 32 (B7sus4 B7) and the
                                   flute's D#5 - B4 lead into the E5 of bar 1

CHORDS (one bar each; two in a bar share it 3 + 3 eighths)
  A   E | C#m7 | Amaj7 | B7sus4 B7 | G#m7 | Aadd9 F#7/A# | B7sus4 B7 | E E7/G#
      F#7/A# = V of V with the Lydian A#.  E7/G# = V of IV: its bass G# steps
      up to the A of bar 9 and its D (the vibes' answer) falls to C#.
  B   Amaj7 | G#m7 C#7 | F#m7 | Am6 | E/G# | C#m7 F#7 | B7sus4 | B7
      C#7 = V of ii, Am6 = iv borrowed from E minor (IV to iv across bars 11-12),
      F#7 = V of V; B7sus4 to B7 over two bars is a dominant held for the return.
  A'  as A, but Aadd9 in bar 19 (no G# under the flute's A), then
      Aadd9 Am6 | E/B B7 | E in bars 22-24 (IV-iv, cadence).
  C   E | C#m7/E | F#/E | F#/E      (E Lydian, E pedal in the bass)
      Aadd9 | G#m7 C#m7 | F#m7 | B7sus4 B7   (back to E in bar 1)

THE MOTIF (tools/music/motif.py; in E in 6/8: E. B A | G# F# G# B.)
  bars 1-2    as written (flute)
  bar  11     its tail shape (step, step, third: E F# A) as the flute's answer;
  bar  13     the same shape on B (B C# E)
  bars 17-18  in Lydian (E B A# | G# F# G# B), flute
  bars 25-26  head (vibes, call) and tail (flute, answer)
  bars 27-28  the same a step higher (F# C# B A# | G# A# C#)
  The 3 + 2 + 1 rhythm of the motif's first bar comes back in bars 5 and 21.

HIGH POINTS  A: E6 in bar 6.  B: F#5 in bar 15 (the strings, the top of their
             climb).  A': F#6 in bar 22, the top of the piece.  C: E6 in bar 31.

INSTRUMENTS (name: GM instrument, pan, role)
  flute: flute 73, centre, melody         strings: strings 48, -10, melody (B only)
  vibes: vibraphone 11, +30, counter      harp: harp 46, -32, accompaniment
  pad: slow strings 49, -18, harmony      oohs: voice oohs 53, +18, harmony (B only)
  bass: acoustic bass 32, centre          kit: brush kit (shaker, triangle, bell tree)
"""
from tools.music import motif
from tools.music.score import Song


def song() -> Song:
    s = Song("bgm_air", tempo=66, key="E", mode="major", meter=(6, 8), bars=32,
             where="lungs (no boss), nose")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24).section("C", 25, 32)
    s.harmony(1, "E | C#m7 | Amaj7 | B7sus4 B7 | G#m7 | Aadd9 F#7/A# | B7sus4 B7 | E E7/G#")
    s.harmony(9, "Amaj7 | G#m7 C#7 | F#m7 | Am6 | E/G# | C#m7 F#7 | B7sus4 | B7")
    s.harmony(17, "E | C#m7 | Aadd9 | B7sus4 B7 | G#m7 | Aadd9 Am6 | E/B B7 | E")
    s.harmony(25, "E | C#m7/E | F#/E | F#/E | Aadd9 | G#m7 C#m7 | F#m7 | B7sus4 B7")
    s.set_key(17, "E", "lydian").set_key(18, "E", "major")
    s.set_key(25, "E", "lydian").set_key(29, "E", "major")
    two = {4, 6, 7, 8, 10, 14, 20, 22, 23, 30, 32}       # bars with two chords

    # --- parts ----------------------------------------------------------------
    flute = s.part("flute", "flute", role="melody", pan=0, volume=110, reverb=0.36)
    strm = s.part("strings", "strings", role="melody", pan=-10, volume=104, reverb=0.42, gate=1.0)
    vibes = s.part("vibes", "vibraphone", role="counter", pan=30, volume=118, reverb=0.40, gate=1.0)
    harp = s.part("harp", "harp", role="accomp", pan=-32, volume=92, reverb=0.38, gate=1.0)
    pad = s.part("pad", "slow_strings", role="harmony", pan=-18, volume=70, reverb=0.48, gate=1.0)
    oohs = s.part("oohs", "voice_oohs", role="harmony", pan=18, volume=70, reverb=0.50, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", pan=0, volume=96, reverb=0.07)
    kit = s.drums("kit", "brush", volume=82, reverb=0.22)

    flute.dyn({1: 74, 3: 82, 4: 72, 5: 80, 6: 90, 8: 70, 9: 66, 13: 74, 16: 70,
               17: 80, 20: 76, 22: 94, 24: 74, 25: 70, 28: 74, 29: 80, 31: 92, 32: 78})
    strm.dyn({9: 66, 12: 74, 15: 86, 16: 70})
    vibes.dyn({1: 76, 8: 80, 17: 74, 22: 84, 24: 72, 25: 76, 28: 80, 29: 64, 32: 66})
    harp.dyn({1: 62, 4: 68, 5: 64, 8: 70, 9: 58, 16: 64, 17: 66, 22: 74, 24: 64,
              25: 52, 28: 58, 29: 62, 32: 72})
    pad.dyn({5: 48, 7: 60, 8: 52, 17: 54, 22: 66, 24: 54, 25: 44, 29: 52, 32: 62})
    oohs.dyn({9: 50, 12: 60, 15: 66, 16: 56})
    bass.dyn({1: 74, 5: 80, 8: 76, 9: 70, 15: 80, 17: 82, 22: 88, 24: 78, 25: 60,
              29: 78, 32: 86})
    kit.dyn({1: 50, 5: 60, 8: 66, 9: 52, 16: 62, 17: 66, 24: 70, 25: 48, 29: 60, 32: 74})

    # --- melody: A (durations in eighths) ---------------------------------------
    flute.place(1, 1, motif.notes(s, 5))                                 # bars 1-2
    flute.line(3, 1, "C#6:2 B5:1 A5:2 G#5:1 | F#5:3 r:3 |"
                     " G#5:3 D#6:2 C#6:1 | E6:2 D#6:1 C#6:2 A#5:1* |"
                     " B5:2 A5:1 F#5:2 D#5:1 | E5:3 r:3")
    vibes.line(4, 4, "D#6:1 C#6:1 B5:1")                                  # answers
    vibes.line(8, 4, "G#5:1 B5:1 D6:1*")

    # --- melody: B (strings, long notes; the flute answers) -------------------------
    strm.line(9, 1, "C#5:3 E5:3 | D#5:3 C#5:2 B4:1 | C#5:5 B4:1 | C5:3* E5:2 F#5:1 |"
                    " E5:3 B4:3 | E5:3 C#5:3 | F#5:4 E5:2 | D#5:3 r:3")
    strm.auto_swell(3)
    flute.line(11, 4, "E5:1 F#5:1 A5:1")                                  # tail shape
    flute.line(13, 4, "B5:1 C#6:1 E6:1")
    flute.line(16, 4, "B5:1 A5:1 F#5:1")                                  # into bar 17

    # --- melody: A' (Lydian motif, new ending, F#6 at the top) ------------------------
    flute.place(17, 1, motif.notes(s, 5, at_bar=17))                      # E B A# | G# F# G# B
    flute.line(19, 1, "C#6:2 B5:1 A5:2 G#5:1 | F#5:3 r:3 |"
                      " G#5:3 D#6:2 C#6:1 | E6:2 F#6:1 E6:2 C6:1* |"
                      " B5:2 G#5:1 A5:2 F#5:1 | G#5:2 F#5:1 E5:3")
    vibes.line(17, 1, "B4:3 G#4:3 | E4:3 G#4:3 | A4:3 C#5:3 | E4:3 D#5:1 C#5:1 B4:1 |"
                      " B4:3 D#5:3 | C#5:3 C5:3* | B4:3 A4:3 | G#4:6")

    # --- melody: C (call and response in E Lydian, then the climb) -----------------------
    vibes.place(25, 1, motif.head(s, 5, at_bar=25))                       # E B A# | G#
    flute.place(26, 2, motif.tail(s, 5, at_bar=25))                       # F# G# B
    vibes.place(27, 1, motif.head(s, 5, shift=1, at_bar=25))              # F# C# B | A#
    flute.place(28, 2, motif.tail(s, 5, shift=1, at_bar=25))              # G# A# C#
    flute.line(29, 1, "A5:2 B5:1 C#6:3 | B5:1 G#5:1 F#5:1 E5:3 |"
                      " F#5:1 A5:1 C#6:1 E6:2 C#6:1 | A5:2 F#5:1 D#5:2 B4:1")
    flute.auto_swell(3)

    # --- harp -------------------------------------------------------------------------------
    harp.arp((1, 8), "012321", 1, low="E3", high="E5")
    harp.arp((9, 16), "0.2.4.", 1, low="E3", high="E5")
    harp.arp((17, 24), "012345", 1, low="E3", high="B5")
    harp.arp((25, 28), "0..3..", 1, low="E3", high="E5")
    harp.arp((29, 32), "012345", 1, low="E3", high="B5")

    # --- pads ---------------------------------------------------------------------------------
    pad.pad((5, 8), voices=3, low="G#3", high="E4")
    pad.pad((17, 24), voices=3, low="G#3", high="E4")
    pad.pad((25, 32), voices=3, low="G#3", high="E4")
    oohs.pad((9, 16), voices=3, low="E3", high="C#4")

    # --- bass ---------------------------------------------------------------------------------
    for b in range(1, 9):
        bass.bass((b, b), "R:3 R:2 5:1" if b in two else "R:3 5:2 R:1", gate=0.9)
    for b in range(9, 17):
        bass.bass((b, b), "R:3 R:3" if b in two else "R:5 s:1", gate=0.95)
    for b in range(17, 25):
        pat = "R:2 5:1 R:2 5:1" if b in two else ("R:2 5:1 3:2 5:1" if b == 18 else "R:2 5:1 8:2 5:1")
        bass.bass((b, b), pat, gate=0.85)
    bass.bass((25, 25), "R:6", gate=0.95)                                  # E pedal, every other bar:
    bass.bass((27, 27), "R:6", gate=0.95)                                  # 26 and 28 rest (lighter low end)
    for b in range(29, 32):
        bass.bass((b, b), "R:3 R:3" if b in two else "R:3 5:3", gate=0.9)
    bass.bass((32, 32), "R:3 R:2 a:1")

    # --- drums (brush kit; 6 steps = eighths) ----------------------------------------------
    kit.grid((1, 4), {"shaker": "o..o.."})
    kit.grid((5, 7), {"kick": "x.....", "snare": "...o..", "shaker": "x.ox.o"})
    kit.grid((8, 8), {"kick": "x.....", "shaker": "x.o..."})
    kit.fill(8, 4, "snare:1- snare:1 snare:1")
    kit.grid((9, 15), {"kick": "x.....", "triangle": "...o.."})
    kit.grid((16, 16), {"kick": "x....."})
    kit.fill(16, 4, "snare:1- low_tom:1 floor_tom:1")
    kit.hit(17, 1, "bell_tree", 70)
    a2 = {"kick": "x..o..", "snare": "...x..", "shaker": "xoxxox"}
    for b, pat in zip(range(17, 24), [a2, a2, a2, dict(a2, kick="x..o.o"),    # 20: pickup kick
                                      a2, dict(a2, snare="....o."), a2]):    # 22: backbeat later, softer
        kit.grid((b, b), pat)
    kit.grid((24, 24), {"kick": "x.....", "shaker": "xox..."})
    kit.fill(24, 4, "snare:1- snare:1 snare:1")
    kit.grid((25, 28), {"triangle": "x.....", "shaker": "...o.."})
    kit.grid((29, 31), {"kick": "x.....", "snare": "...o..", "shaker": "x.ox.o"})
    kit.grid((32, 32), {"kick": "x.....", "shaker": "x.o..."})
    kit.fill(32, 4, "snare:.5- snare:.5 low_tom:1 floor_tom:1")
    kit.hit(1, 1, "bell_tree", 64)
    return s
