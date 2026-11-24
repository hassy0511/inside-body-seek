"""bgm_clinic - the clinic (consult, guess, the talk after a scene).

MOOD  gentle, curious, caring: someone feels unwell and we will find out why.
      A soft clarinet tells the story, the celesta asks little questions in
      the gaps, the guitar and brushes keep a light swing under it.

KEY AND METRE  F major, 4/4, tempo 84, light swing (0.60) on the off-beat
eighths, 24 bars = 68.6 s, loops.

FORM (8-bar phrases)              thin/full and what changes
  A   bars  1-8   the question     5 parts: clarinet tune, nylon guitar comps a
                                   3+3+2 rhythm, acoustic bass in a two-feel
                                   (root and fifth), brushes (soft kick, brush
                                   taps on 2 and 4, swung hats), celesta answers
                                   in the gaps at the phrase ends
  B   bars  9-16  thinking it over thinner: the clarinet asks short swung
                                   questions that start after a breath (bars
                                   9-12, the celesta answers in the rests), then
                                   climbs in longer notes; guitar in quarter-
                                   note arpeggios, strings pad, bass in long notes,
                                   only hats and a shaker; the celesta joins the
                                   climb to the top in bars 13-14
  A'  bars 17-24  we found it      fullest: the clarinet tune again (a new top in
                                   bar 21), celesta doubles the motif an octave up,
                                   strings play a slow counter-line, guitar in
                                   eighth arpeggios, walking bass, full brushes;
                                   bar 24 ends with a brush fill and the clarinet's
                                   E4 leading note into the F4 of bar 1

CHORDS (one bar each; two in a bar share it)
  A   F6 | Gm7/C | Am7 | Gm7 C7 | Bbmaj7 | Bbm6 | F/C D7 | Gm7 C7
      Gm7/C = a soft C9sus4 (the motif's tail G A C sits on it).
      Bbm6 = IV to iv (borrowed from F minor; the tune sings its D-flat).
      D7 = V of ii, into Gm7.
  B   Bbmaj7 | C/Bb | Am7 | D7 | Gm7 | Bbm6 | Am7 D7 | Gm7 C7sus4 C7
      C/Bb is V over the IV pedal; D7 again V of ii; Bbm6 again the borrowed iv.
  A'  as A.

THE MOTIF (tools/music/motif.py; in F: F C Bb A | G A C)
  bars 1-2    as written (clarinet)          bars 3-4    a third higher (A E D C | Bb C E)
  bars 9-12   short questions (eighths after an eighth rest), not the motif:
              they leave B free of the title's B rhythm (revision 1)
  bars 17-20  again in A' (clarinet), celesta an octave above
  celesta     the tail's rhythm (short-short-long) as the question in bars 2, 4, 8

HIGH POINTS  A: F5 in bar 5 (held two beats).  B: G5 in bar 14, after the climb in bar 13.
             A': A5 in bar 21, held 1.5 beats (the maj7 of Bbmaj7: the top of the piece).
Revision 1 also gave bars 5-6 (and 21-22) their own rhythm (.5 .5 2 .5 .5 | 2 1 1),
a soft kick only on beat 1 (A) and 1+3 (A'), a quieter bass, and drum bars 4 and 6
of each 7-bar run that differ from the rest.

INSTRUMENTS (name: GM instrument, pan, role)
  clar: clarinet 71, centre, melody        cel: celesta 8, +30, counter / sparkle
  gtr: nylon guitar 24, -28, harmony       strings: slow strings 49, -16, harmony
                                           (pad in B, counter-line in A')
  bass: acoustic bass 32, centre, bass     kit: brush kit, centre (swung)
  Tempo, key and length as in the table.  Added to the table's colours: soft
  slow strings, so B has a sustained pad and A' a counter-line.
"""
from tools.music import motif
from tools.music.score import Song


def grid_bars(kit, first: int, patterns: list):
    """One drum pattern (a dict of lanes) per bar, from bar `first` on."""
    for i, pat in enumerate(patterns):
        kit.grid((first + i, first + i), pat)

SW = 0.60   # light swing


def song() -> Song:
    s = Song("bgm_clinic", tempo=84, key="F", mode="major", meter=(4, 4), bars=24,
             where="consult, guess, the talk after a scene")

    # --- form and harmony ---------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24)
    a_chords = "F6 | Gm7/C | Am7 | Gm7 C7 | Bbmaj7 | Bbm6 | F/C D7 | Gm7 C7"
    s.harmony(1, a_chords)
    s.harmony(9, "Bbmaj7 | C/Bb | Am7 | D7 | Gm7 | Bbm6 | Am7 D7 | Gm7:2 C7sus4:1 C7:1")
    s.harmony(17, a_chords)

    # --- parts ----------------------------------------------------------------
    clar = s.part("clar", "clarinet", role="melody", pan=0, volume=112, reverb=0.32, swing=SW)
    cel = s.part("cel", "celesta", role="counter", pan=30, volume=114, reverb=0.38, gate=1.0, swing=SW)
    gtr = s.part("gtr", "nylon_guitar", role="harmony", pan=-28, volume=92, reverb=0.28, gate=1.0, swing=SW)
    strings = s.part("strings", "slow_strings", role="harmony", pan=-16, volume=70, reverb=0.45, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", pan=0, volume=92, reverb=0.06, swing=SW)
    kit = s.drums("kit", "brush", volume=88, reverb=0.18, swing=SW)

    clar.dyn({1: 78, 4: 84, 5: 90, 6: 86, 8: 74, 9: 72, 12: 78, 13: 84, 14: 92, 16: 74,
              17: 80, 21: 94, 22: 88, 24: 76})
    cel.dyn({1: 66, 9: 60, 13: 70, 16: 62, 17: 64, 24: 70})
    gtr.dyn({1: 64, 8: 68, 9: 58, 16: 62, 17: 66, 24: 70})
    strings.dyn({9: 54, 13: 64, 16: 56, 17: 74, 21: 86, 24: 76})
    bass.dyn({1: 80, 9: 72, 17: 78, 24: 80})
    kit.dyn({1: 62, 8: 68, 9: 52, 16: 58, 17: 60, 24: 70})

    # --- melody: A (the question) -------------------------------------------------
    clar.place(1, 1, motif.notes(s, 4))                           # F C Bb A | G A C
    clar.place(3, 1, motif.notes(s, 4, shift=2))                  # A E D C | Bb C E
    clar.line(5, 1, "D5:.5 E5:.5 F5:2 E5:.5 D5:.5 | Db5:2* Bb4:1 G4:1 |"
                    " C5:1 A4:1 D5:1.5 C5:.5 | Bb4:2 G4:1 r:1")
    # --- melody: B (longer notes, the motif's tail) -------------------------------
    clar.line(9, 1, "r:.5 F4:.5 A4:.5 C5:.5 D5:1.5 C5:.5 | Bb4:.5 A4:.5 G4:1 r:2 |"
                    " r:.5 E4:.5 G4:.5 A4:.5 C5:1.5 A4:.5 | F#4:.5* A4:.5 C5:.5 D5:.5 r:2 |"
                    " Bb4:1 D5:1 F5:1 G5:1 | G5:2 F5:1 Db5:1* |"
                    " E5:1.5 C5:.5 D5:1 C5:1 | Bb4:1.5 A4:.5 G4:2")
    # --- melody: A' (the tune again, a higher top, a leading note at the end) -------
    clar.place(17, 1, motif.notes(s, 4))
    clar.place(19, 1, motif.notes(s, 4, shift=2))
    clar.line(21, 1, "D5:1 F5:1 A5:1.5 G5:.5 | Db5:2* Bb4:1 G4:1 |"
                     " C5:1 A4:1 D5:1.5 C5:.5 | Bb4:1.5 A4:.5 G4:1 E4:1")
    clar.auto_swell(2.0)

    # --- celesta: questions in the gaps (A), the climb (B), the motif above (A') -----
    cel.line(2, 4, "A5:.5 C6:.5")
    cel.line(4, 4, "G5:.5 Bb5:.5")
    cel.line(6, 4, "F5:.5 G5:.5")
    cel.line(8, 4, "E5:.5 G5:.5")
    cel.line(10, 3, "E6:.5 C6:.5 A5:1")
    cel.line(12, 3, "C6:.5 A5:.5 F#5:1*")
    cel.line(13, 3, "D6:.5 F6:.5 G6:1")
    cel.line(14, 3, "F6:.5 Db6:.5* Bb5:1")
    cel.line(16, 3, "E6:.5 C6:.5 Bb5:.5 G5:.5")
    for n in clar.notes:
        if s.at(17) <= n.t < s.at(21):
            cel.note(1, 1 + n.t, n.pitch + 12, n.dur, ok=n.ok)
    cel.line(22, 4, "F5:.5 G5:.5")
    cel.line(24, 3, "C6:.5 Bb5:.5 G5:.5 E5:.5")

    # --- harmony ---------------------------------------------------------------------
    gtr.chords((1, 8), "x..x..x.", voices=3, low="C3", high="A4", gate=0.55)
    gtr.arp((9, 14), "0231", 1.0, low="C3", high="C5")
    gtr.arp((15, 16), "0123", 0.5, low="C3", high="A4")   # eighths: B winds up into A'
    gtr.arp((17, 24), "0213", 0.5, low="C3", high="A4")

    strings.pad((9, 16), voices=3, low="D3", high="F4")
    strings.line(17, 1, "A3:2 C4:2 | Bb3:4 | C4:2 E4:2 | D4:2 E4:2 | D4:2 F4:2 |"
                        " Db4:4* | A3:2 F#3:2* | G3:2 Bb3:2")
    strings.auto_swell(2.0, bars=(17, 24))

    # --- bass ----------------------------------------------------------------------------
    for b in range(1, 9):
        two = b in (4, 7, 8)
        bass.bass((b, b), "R:2 R:1.5 5:.5" if two else "R:2 5:1.5 a:.5")
    for b in range(9, 17):
        bass.bass((b, b), "R:2 R:2" if b in (15, 16) else "R:3 5:1", gate=0.95)
    bass.walk((17, 23))
    bass.bass((24, 24), "R:1 5:1 R:1 a:1")

    # --- drums (brush kit: the snare notes are brushes) ----------------------------------
    groove = {"kick": "o.......", "snare": "..o...o.", "hat": "x.xxx.xx"}
    grid_bars(kit, 1, [groove, groove, groove,
                      dict(groove, snare="..o...oo"),               # a brush pickup into bar 5
                      groove,
                      dict(groove, snare="..o.....", hat="x.xxx.x."),   # one backbeat left out
                      groove])
    kit.grid((8, 8), {"kick": "x...x...", "snare": "..o.....", "hat": "x.xx...."})
    kit.fill(8, 4, "snare:.5- snare:.5")
    kit.grid((9, 15), {"hat": "..x...x.", "shaker": "o.x.o.xo"})
    kit.grid((16, 16), {"hat": "..x.....", "shaker": "oxoxo..."})
    kit.fill(16, 3.5, "snare:.5- snare:.5- snare:.5")
    full = {"kick": "o...o...", "snare": "..x...x.", "hat": "x.xxx.xx", "shaker": "o.o.o.o."}
    grid_bars(kit, 17, [full, full, full, dict(full, snare="..x...xo"), full,
                        dict(full, snare="..x....x"), full])
    kit.grid((24, 24), {"kick": "x.......", "hat": "x.xx...."})
    kit.fill(24, 3, "snare:.5- snare:.5 low_tom:.5- floor_tom:.5")
    kit.hit(17, 1, "ride", 66)
    return s
