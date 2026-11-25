"""bgm_boss - scenes with a boss (a cartoon villain: tense but fun, never frightening).

KEY AND METRE  D minor, relief in F major (bars 9-16), 4/4, tempo 138, 32 bars = 55.7 s, loops.

FORM (8-bar phrases)                 thin/full and what changes
  A   bars  1-8   the villain sneaks  clarinet tune (the motif upside down), low string
                                      ostinato in staccato eighths, tuba on 1 and 3 over a
                                      D pedal (bars 1-2), timpani, soft snare backbeat,
                                      xylophone "giggles" in the gaps of the tune;
                                      trombone stabs only in the cadence (bars 7-8)
  B   bars  9-16  relief: the heroes  F major.  The motif the right way up in the french
                                      horn, slow strings pad, tuba oom-pah, pizzicato
                                      off-beats from bar 13, a soft snare march, one bass
                                      drum per bar; no ostinato, timpani only in bar 16:
                                      thinner, longer notes, brighter
  A'  bars 17-24  the villain again   fullest: the clarinet tune with the xylophone an octave
                                      above (17-20), a bassoon answering line, trombone stabs
                                      on the off-beats, kick + snare, crash; new chord (C) and
                                      the top note C6 in bar 23
  C   bars 25-32  call and response,  thin at first: the english horn calls the motif's
                  then the build      head upside down, the xylophone answers with its tail
                                      (25-28) over the ostinato, short tuba notes and wood
                                      block; from bar 29 the clarinet climbs to
                                      Bb5, pad, stabs and snare build; bar 32 (A7sus4 A7) has a
                                      snare roll, a timpani roll and the clarinet's C#5 leading
                                      note into the D5 of bar 1

CHORDS (one bar each; two in a bar share it)
  A   Gm/D | C7/D | Dm | A7 | Bb | Gm6 | Eb A7 | Dm C7
      bars 1-2: iv and VII7 over a D pedal (the sneaking); Eb A7 = Neapolitan to V
      (the cartoon-villain flourish); C7 = V of F, it opens the door to B.
  B   F | C/E | Am7 | Bb C7 | F/A | Bb Bbm6 | Gm7 C7 | Gm7 A7
      Bb Bbm6 = IV to iv (borrowed); Gm7 A7 = iv V of D minor, back to the villain.
  A'  Gm/D | C7/D | Dm | A7 | Bb | Gm6 | C A7 | Dm A7
      bar 23 C (VII, brighter) instead of Eb, for the high point C6.
  C   Gm/D | C7/D | Bb/F | Em7b5 | A7 | Dm Dm/C | Bb Eb | A7sus4 A7
      ii-half-diminished V in 28-29; a falling bass D C Bb, Eb A in 30-32.

THE MOTIF (tools/music/motif.py; in D minor upside down: D5 G4 A4 Bb4 | C5 Bb4 G4)
  bars 1-2, 17-18   upside down (clarinet)          bars 5-6, 21-22   upside down a third higher
  bars 9-10         the right way up in F (horn)     bars 11-12        its own answer, chord tones (horn)
  bars 25, 27       head upside down (english horn)  bars 26, 28       tail upside down (xylophone)

HIGH POINTS  A: Bb5 bar 7.  B: F5 bar 13 (and 16).  A': C6 bar 23.  C: Bb5 bar 31.
MELODY RANGE F4..C6 (19 semitones) over all melody parts.

INSTRUMENTS (name: GM instrument, pan, role)
  clar: clarinet 71, centre, melody (A, A', C 29-32)   horn: french horn 60, -6, melody (B)
  call: english horn 69, -10, melody (C 25, 27)           xans: xylophone 13, +12, melody (C 26, 28)
  xylo: xylophone 13, +30, sparkle                     bsn: bassoon 70, -24, counter (A')
  ost: strings 48, -30, accompaniment (staccato ostinato)
  pad: slow strings 49, +22, harmony (B, C 29-32)      pizz: pizzicato 45, +34, harmony (B)
  bone: trombone 57, +18, harmony (stabs)              tuba: tuba 58, centre, bass
  timp: timpani 47, -14, percussion (four drums D2 G2 A2 Bb2; the tuba keeps the roots)
  kit: standard kit (kick, snare, crash, wood block).  The orchestra kit's concert bass
       drum rang about 1.2 s and three hits a bar made a steady 40-50 Hz boom under the
       tuba (too dark for a 6-year-old); the standard kick decays in about 0.3 s.
Tempo and key as in the table.  The lead is a clarinet, not a brass or xylophone: the xylophone measured far softer than
the other parts in this soundfont and is shrill as a lead for 3-5 minutes; it answers instead.
The call in C is an english horn, not a bassoon: D5-F5 is above the bassoon's comfortable
range (the range check stops at D#5).  The tuba is written with bass(octave=1) and every
note under A1 is lifted an octave (E1/F1 made the low end boom in the spectrogram).
"""
from tools.music import motif
from tools.music.score import Song


def grid_bars(kit, first: int, patterns: list):
    """One drum pattern (a dict of lanes) per bar, from bar `first` on."""
    for i, pat in enumerate(patterns):
        kit.grid((first + i, first + i), pat)


def song() -> Song:
    s = Song("bgm_boss", tempo=138, key="D", mode="minor", meter=(4, 4), bars=32,
             where="scenes with a boss")

    # --- form, keys and harmony ----------------------------------------------------
    s.section("A", 1, 8).section("B", 9, 16).section("A'", 17, 24).section("C", 25, 32)
    s.set_key(9, "F", "major")
    s.set_key(17, "D", "minor")
    s.harmony(1, "Gm/D | C7/D | Dm | A7 | Bb | Gm6 | Eb A7 | Dm C7")
    s.harmony(9, "F | C/E | Am7 | Bb C7 | F/A | Bb Bbm6 | Gm7 C7 | Gm7 A7")
    s.harmony(17, "Gm/D | C7/D | Dm | A7 | Bb | Gm6 | C A7 | Dm A7")
    s.harmony(25, "Gm/D | C7/D | Bb/F | Em7b5 | A7 | Dm Dm/C | Bb Eb | A7sus4 A7")

    # --- parts -------------------------------------------------------------------
    clar = s.part("clar", "clarinet", role="melody", pan=0, volume=110, reverb=0.30)
    horn = s.part("horn", "french_horn", role="melody", pan=-6, volume=100, reverb=0.40)
    call = s.part("call", "english_horn", role="melody", pan=-10, volume=112, reverb=0.30)
    xans = s.part("xans", "xylophone", role="melody", pan=12, volume=120, reverb=0.28, gate=1.0)
    xylo = s.part("xylo", "xylophone", role="sparkle", pan=30, volume=112, reverb=0.30, gate=1.0)
    bsn = s.part("bsn", "bassoon", role="counter", pan=-24, volume=92, reverb=0.32)
    ost = s.part("ost", "strings", role="accomp", pan=-30, volume=112, reverb=0.25, gate=0.45)
    pad = s.part("pad", "slow_strings", role="harmony", pan=22, volume=74, reverb=0.45, gate=1.0)
    pizz = s.part("pizz", "pizzicato", role="harmony", pan=34, volume=88, reverb=0.28)
    bone = s.part("bone", "trombone", role="harmony", pan=18, volume=78, reverb=0.32)
    tuba = s.part("tuba", "tuba", role="bass", pan=0, volume=92, reverb=0.08)
    timp = s.part("timp", "timpani", role="perc", pan=-14, volume=90, reverb=0.30, gate=1.0)
    kit = s.drums("kit", "standard", volume=82, reverb=0.20)

    clar.dyn({1: 74, 4: 80, 5: 82, 7: 92, 8: 80, 17: 82, 21: 88, 23: 96, 24: 82,
              29: 84, 31: 96, 32: 88})
    horn.dyn({9: 78, 12: 84, 13: 90, 14: 86, 15: 82, 16: 88})
    call.dyn({25: 80, 27: 86})
    xans.dyn({26: 84, 28: 90})
    xylo.dyn({1: 70, 8: 74, 17: 66, 24: 72, 29: 70, 32: 80})
    bsn.dyn({17: 66, 20: 72, 21: 70, 24: 76})
    ost.dyn({1: 64, 4: 72, 5: 66, 8: 76, 17: 70, 20: 76, 21: 70, 24: 80, 25: 58, 28: 68, 29: 68, 32: 84})
    pad.dyn({9: 50, 11: 60, 12: 52, 13: 58, 14: 68, 15: 56, 16: 64, 29: 46, 31: 60, 32: 70})
    pizz.dyn({13: 56, 14: 68, 15: 58, 16: 72})
    bone.dyn({7: 70, 8: 76, 17: 66, 23: 78, 24: 74, 29: 64, 32: 80})
    tuba.dyn({1: 80, 9: 72, 17: 84, 25: 74, 29: 80, 32: 88})
    timp.dyn({1: 70, 8: 78, 17: 74, 25: 62, 29: 70, 32: 86})
    kit.dyn({1: 58, 8: 70, 9: 54, 16: 66, 17: 70, 24: 80, 25: 50, 29: 62, 32: 86})

    # --- melody: A (the villain tune) ------------------------------------------------
    clar.place(1, 1, motif.notes(s, 5, invert=True))                   # D5 G4 A4 Bb4 | C5 Bb4 G4
    clar.line(3, 1, "F5:.5' E5:.5' F5:.5' G#5:.5'* A5:1 F5:1 |"
                    " E5:1 C#5:.5* E5:.5 A5:1 r:1")
    clar.place(5, 1, motif.notes(s, 5, invert=True, shift=2))          # F5 Bb4 C5 D5 | E5 D5 Bb4
    clar.line(7, 1, "G5:1 Bb5:1 A5:1.5 G5:.5 | F5:.5 E5:.5 D5:1 E5:1 C5:1")
    # --- melody: B (relief, horn; the motif the right way up in F) ------------------
    horn.place(9, 1, motif.notes(s, 4, at_bar=9))                     # F4 C5 Bb4 A4 | G4 A4 C5
    horn.line(11, 1, "C5:1.5 A4:.5 E5:2 | D5:1.5 Bb4:.5 G4:1 C5:1")    # own answer (Am7 | Bb C7)
    horn.line(13, 1, "A4:.5 C5:.5 F5:2 E5:.5 C5:.5 | D5:1.5 C5:.5 Bb4:1 Db5:1* |"
                     " Bb4:1 D5:.5 F5:.5 E5:1 C5:1 | D5:1 F5:1 E5:1.5 C#5:.5*")
    horn.auto_swell(1.5)
    # --- melody: A' (the tune again, new bar 23, rests in bar 24) ---------------------
    clar.place(17, 1, motif.notes(s, 5, invert=True))
    clar.line(19, 1, "F5:.5' E5:.5' F5:.5' G#5:.5'* A5:1 F5:1 |"
                     " E5:1 C#5:.5* E5:.5 A5:1 r:1")
    clar.place(21, 1, motif.notes(s, 5, invert=True, shift=2))
    clar.line(23, 1, "G5:1 C6:1 A5:1.5 G5:.5 | F5:.5 E5:.5 D5:1 r:2")
    # --- melody: C (call and response, then the climb) ---------------------------------
    call.place(25, 1, motif.head(s, 5, invert=True))                  # D5 G4 A4 Bb4
    xans.place(26, 1, motif.tail(s, 6, invert=True))                  # C6 Bb5 G5
    call.place(27, 1, motif.head(s, 5, invert=True, shift=2))         # F5 Bb4 C5 D5
    xans.place(28, 1, motif.tail(s, 5, invert=True, shift=2))         # E5 D5 Bb4
    clar.line(29, 1, "A4:1 C#5:.5* E5:.5 G5:1 E5:1 | F5:1.5 E5:.5 D5:1 A5:1 |"
                     " Bb5:1.5 A5:.5 G5:1 Bb5:1 | A5:1 G5:.5 D5:.5 E5:1 C#5:1*")
    clar.auto_swell(2.0)

    # xylophone: giggles in the gaps of A, an octave above the tune in A' (17-20),
    # a run into C and into bar 1
    xylo.line(2, 4, "G5:.5' Bb5:.5'")
    xylo.line(4, 4, "A5:.25 G5:.25 F5:.25 E5:.25")
    xylo.line(6, 4, "G5:.5' Bb5:.5'")
    xylo.line(8, 3.5, "C6:.5 Bb5:.5 G5:.5")
    for n in clar.notes:
        if s.at(17) <= n.t < s.at(21):
            xylo.note(1, 1 + n.t, n.pitch + 12, n.dur, ok=n.ok)
    xylo.line(22, 4, "G6:.5' Bb6:.5'")
    xylo.line(24, 3, "A5:.25 C#6:.25* E6:.25 A6:.25 G6:.25 E6:.25 C#6:.25* A5:.25")
    xylo.line(30, 4, "D6:.5' A5:.5'")
    xylo.line(32, 3, "E6:.25 C#6:.25* A5:.25 G5:.25 E5:.25 C#5:.25* A4:.25 C#5:.25*")

    # bassoon answering line in A' (moves where the clarinet holds or rests)
    bsn.line(17, 1, "r:2 Bb3:1 G3:1 | r:1 E3:1 G3:1 Bb3:1 | A3:2 F3:1 D3:1 |"
                    " C#3:1* E3:1 G3:1 A3:1 | D4:2 Bb3:1 F3:1 | E3:1 G3:1 Bb3:1 D4:1 |"
                    " E4:1 C4:1 C#4:1* E4:1 | D4:1 A3:1 r:.5 A3:.5' C#4:.5'* E4:.5'")
    bsn.auto_swell(2.0)

    # --- accompaniment -----------------------------------------------------------------
    ost_pat = "00201021"
    ost.arp((1, 8), ost_pat, 0.5, low="C3", high="Bb3")
    # A' 17-20: the ostinato thins to quarters so the bassoon's answer (same octave) is heard
    ost.arp((17, 20), "0r2r1r2r", 0.5, low="C3", high="Bb3")
    ost.arp((21, 24), ost_pat, 0.5, low="C3", high="Bb3")
    ost.arp((25, 32), "00201021", 0.5, low="C3", high="Bb3")

    # bar 9 by hand: F3 C4 F4 (no A under the horn's passing Bb4), then voice-led pads
    for q in ("F3", "C4", "F4"):
        pad.note(9, 1, q, 4, ok=True)
    pad.swell(9, 1, 4)
    pad.pad((10, 16), voices=3, low="F3", high="C5")
    pad.pad((29, 32), voices=3, low="F3", high="D5")
    pizz.chords((13, 15), ".x.x", voices=3, low="A3", high="F5", gate=0.4)
    pizz.chords((16, 16), ".x.xxxxx", voices=3, low="A3", high="F5", gate=0.4)

    bone.chords((7, 8), "..x...x.", voices=3, low="F3", high="D4", gate=0.35)
    bone.chords((17, 23), ".x...x..", voices=3, low="F3", high="D4", gate=0.35)
    bone.chords((24, 24), "x.x.....", voices=3, low="F3", high="D4", gate=0.35)
    bone.chords((29, 31), ".x...x..", voices=3, low="F3", high="D4", gate=0.35)
    bone.chords((32, 32), "x...X...", voices=3, low="F3", high="E4", gate=0.6)

    # --- bass ------------------------------------------------------------------------------
    tuba.bass((1, 6), "R:1' r:.5 R:.5' 5:1' r:1", octave=1)
    tuba.bass((7, 8), "R:1' r:1 R:1' r:1", octave=1)
    tuba.bass((9, 15), "R:1' 5:1' R:1' 5:1'", octave=1)
    tuba.bass((16, 16), "R:1' 5:1' R:1 a:1", octave=1)
    tuba.bass((17, 22), "R:1' 5:.5' R:.5' 5:1' s:1", octave=1)
    tuba.bass((23, 24), "R:1' r:1 R:1' r:1", octave=1)
    tuba.bass((25, 28), "R:1.5 5:.5' r:1 5:1'", octave=1, gate=0.8)
    tuba.bass((29, 31), "R:1' 5:1' R:1' 5:1'", octave=1)
    tuba.bass((32, 32), "R:1' r:1 R:2", octave=1)
    # octave 1 puts E and F chords on E1/F1: lift anything under A1 an octave (less boom)
    for n in tuba.notes:
        if n.pitch < 33:
            n.pitch += 12

    # The timpani are four drums tuned D2, G2, A2, Bb2 and do not follow the root:
    # a hit takes D2 if the chord has a D, else A2, else G2 (C, Eb), else Bb2; the
    # second hit of a bar takes the other of D2/A2 when the chord has it.
    def drum(t, first=True):
        pcs = s.chord_at(t).pcs
        order = (2, 9, 7, 10) if first else (9, 2, 7, 10)
        pc = next((c for c in order if c in pcs), 2)
        return {2: 38, 9: 45, 7: 43, 10: 46}[pc]

    def tim(bars, hits):
        for b in range(bars[0], bars[1] + 1):
            for i, (bt, d, acc) in enumerate(hits):
                timp.note(b, bt, drum(s.at(b, bt), i == 0), d, accent=acc)

    tim((1, 7), [(1, 1, 14), (4.5, .5, 0)])
    timp.line(8, 3, "A2:.5 A2:.5 D3:1")
    timp.line(16, 3, "A2:.25- A2:.25- A2:.25 A2:.25 A2:.25 A2:.25 A2:.25> r:.25")
    tim((17, 23), [(1, 1, 14), (3, 1, 0)])
    tim((25, 31), [(1, 1, 0)])
    timp.line(32, 3, "A2:.25- A2:.25- A2:.25 A2:.25 A2:.25 A2:.25 A2:.25> r:.25")

    # --- drums (standard kit: a short kick, snare, crash, wood block) ----------------------------
    sneak = {"snare": "..o...o.", "kick": "o.......", "block_hi": "......x."}
    grid_bars(kit, 1, [sneak, sneak, sneak,
                       dict(sneak, block_hi="......xx"),                   # a pickup into bar 5
                       sneak,
                       dict(sneak, snare="..o....."),                      # the backbeat on 4 drops
                       sneak])
    kit.grid((8, 8), {"snare": "..o.....", "kick": "o......."})
    # the villain tiptoes: wood blocks, a rest, then one snare (its own fill, not the title's)
    kit.fill(8, 3, "block_hi:.25- block_hi:.25 block_lo:.5 r:.5 snare:.5>")
    march = {"snare": "o.x.o.x.", "kick": "o......."}
    grid_bars(kit, 9, [march, march, march,
                       dict(march, snare="o.x.o.xo"),                      # a pickup into bar 13
                       march,
                       dict(march, snare="o.x.o..."),                      # beat 4 left out
                       march])
    kit.grid((16, 16), {"kick": "o...x..."})
    kit.hit(17, 1, "crash", 80)
    a2 = {"kick": "x...x...", "snare": "..x..ox.", "block_hi": ".......x"}
    grid_bars(kit, 17, [a2, a2, a2,
                        dict(a2, kick="x...x..x"),                         # a pickup into bar 21
                        a2,
                        dict(a2, snare="..x..o.."),                        # the backbeat on 4 drops
                        a2])
    kit.grid((24, 24), {"kick": "x.x....."})
    kit.fill(24, 3, "snare:.25- snare:.25- snare:.25 snare:.25 snare:.5 snare+crash:.5>")
    kit.grid((25, 28), {"snare": "......o.", "block_hi": "..x...x."})
    kit.hit(29, 1, "crash", 72)
    kit.grid((29, 31), {"kick": "x...x...", "snare": "..x...xo"})
    kit.grid((32, 32), {"kick": "x......."})
    kit.fill(32, 2, "snare:.25- snare:.25- snare:.25- snare:.25 snare:.25 snare:.25"
                    " snare:.25 snare:.25 snare:.25 snare:.25> snare:.25> snare:.25>")
    kit.hit(1, 1, "crash", 74)
    return s
