"""clear - scene clear: a small fanfare on the motif (clear.wav, mono 16-bit).

KEY AND METRE  C major, 4/4, tempo 160, 2 bars + 0.4 s ring = about 3.4 s, does not loop.

FORM  statement and answer
  bar 1  the whole motif at double speed (C5 G5 F5 E5 | D5 E5 G5 in eighths and
         sixteenths) in the trumpet, the horn holding chord tones below, a bass drum
         and a timpani C on beat 1
  bar 2  the answer climbs A5 C6 B5 to C6 (held), a cymbal, the bass drum and a
         timpani G-C on the last chord, the glockenspiel rising over it

CHORDS  C:2 G:2 | F:1.5 G:.5 C:2

THE MOTIF  all of it at double speed (diminution) in bar 1, trumpet.

INSTRUMENTS (name: GM instrument, role)            mono, so no pan plan
  trumpet: trumpet 56, melody            flute: flute 73, melody (doubles the trumpet)
  horn: french horn 60, counter
  glock: glockenspiel 9, sparkle         pizz: pizzicato strings 45, harmony
  bass: acoustic bass 32, bass           timp: timpani 47, percussion
  kit: orchestra kit (bass drum, cymbal, snare)
"""
import dataclasses

from tools.music import motif
from tools.music.score import Song


def song() -> Song:
    s = Song("clear", tempo=160, key="C", mode="major", bars=2, loop=False, tail=0.4,
             output="wav_mono", where="scene clear")
    s.section("all", 1, 2)
    s.harmony(1, "C:2 G:2 | F:1.5 G:.5 C:2")

    tpt = s.part("trumpet", "trumpet", role="melody", volume=90, reverb=0.30)
    flute = s.part("flute", "flute", role="melody", volume=108, reverb=0.30)
    horn = s.part("horn", "french_horn", role="counter", volume=96, reverb=0.40)
    glock = s.part("glock", "glockenspiel", role="sparkle", volume=104, reverb=0.40, gate=1.0)
    pizz = s.part("pizz", "pizzicato", role="harmony", volume=90, reverb=0.28)
    bass = s.part("bass", "acoustic_bass", role="bass", volume=94, reverb=0.08)
    timp = s.part("timp", "timpani", role="perc", volume=84, reverb=0.30, gate=1.0)
    kit = s.drums("kit", "orchestra", volume=80, reverb=0.28)

    tpt.dyn({1: 72, 2: 80})
    horn.dyn({1: 72, 2: 82})
    glock.dyn({2: 64})
    pizz.dyn({1: 64})
    bass.dyn({1: 78, 2: 84})
    timp.dyn({1: 74, 2: 84})

    tpt.place(1, 1, motif.notes(s, 5, stretch=0.5))          # the whole motif, twice as fast
    tpt.line(2, 1, "A5:.5 C6:1 B5:.5 C6:2_>")
    tpt.auto_swell(1.5)
    # the flute doubles the trumpet in unison: a rounder tone, less 2-5 kHz edge
    flute.notes.extend(dataclasses.replace(n) for n in tpt.notes)
    flute.dyn({1: 80, 2: 88})
    flute.auto_swell(1.5)

    horn.line(1, 1, "E4:2 D4:2 | F4:1.5 D4:.5 E4:2_")
    horn.auto_swell(1.5)
    pizz.chords((1, 1), "x.x.x.x.", voices=3, low="G3", high="E4", gate=0.4)
    glock.line(2, 3, "C6:.25 E6:.25 G6:.25 C7:1.25")
    bass.line(1, 1, "C2:1' r:1 G2:1' r:1 | F2:1.5 G2:.5 C2:2_")
    timp.line(1, 1, "C3:1 r:3 | r:1 G2:.5 G2:.5 C3:2")
    kit.hit(1, 1, "kick", 80)
    kit.fill(1, 4, "snare:.25- snare:.25 snare:.5")
    kit.hit(2, 3, "crash", 76)
    kit.hit(2, 3, "kick", 84)
    return s
