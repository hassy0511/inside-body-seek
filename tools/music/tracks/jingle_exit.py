"""jingle_exit - the leave-the-body screen: the ship pops out into the daylight.

KEY AND METRE  C major, 4/4, tempo 138, 2 bars + 0.5 s ring = about 4.0 s, does not loop.

FORM  pop - tail of the motif - bright ending
  bar 1 beat 1     the pop: a pizzicato C chord, a high wood block and a harp flick
                   (C4 to C5 in thirty-seconds)
  bar 1 beats 2-4  the motif's tail (D5 E5 G5, "short-short-looong") in the flute with
                   the glockenspiel an octave up, the horn a third/sixth below
  bar 2            the bright ending: bVI - bVII - I (Ab Bb C) as two quick
                   eighths into a long C, the flute on the chords' thirds
                   (C6 D6 E6, the motif tail's short-short-long), the horn
                   falling Eb5 D5 C5 against it (contrary motion); one rolled harp chord, cymbal and bass drum on
                   the C chord (beat 2)
                   (revision 1: no rising root-position triads in the harp and no
                   top line on the chord roots, so the cadence does not recall a
                   well-known "course clear" fanfare)

CHORDS  C:1 G7:3 | Ab:.5 Bb:.5 C:3
        G7 under the tail (D and G are chord tones); Ab and Bb are borrowed from
        C minor, the "sunrise" cadence that sounds brighter than V-I.

THE MOTIF  its tail (bar 2 of the motif: D5 E5 G5) in bar 1, flute and glockenspiel.

INSTRUMENTS (name: GM instrument, pan, role)
  flute: flute 73, centre, melody          glock: glockenspiel 9, +28, sparkle
  horn: french horn 60, -20, counter       pizz: pizzicato strings 45, -30, harmony (the pop)
  harp: harp 46, +18, accompaniment        bass: acoustic bass 32, centre, bass
  kit: orchestra kit (wood block, bass drum, cymbal)
"""
from tools.music import motif
from tools.music.score import Song


def song() -> Song:
    s = Song("jingle_exit", tempo=138, key="C", mode="major", bars=2, loop=False, tail=0.5,
             where="leave-the-body screen")
    s.section("all", 1, 2)
    s.harmony(1, "C:1 G7:3 | Ab:.5 Bb:.5 C:3")

    flute = s.part("flute", "flute", role="melody", pan=0, volume=112, reverb=0.30)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=28, volume=108, reverb=0.40, gate=1.0)
    horn = s.part("horn", "french_horn", role="counter", pan=-20, volume=86, reverb=0.42)
    pizz = s.part("pizz", "pizzicato", role="harmony", pan=-30, volume=100, reverb=0.28)
    harp = s.part("harp", "harp", role="accomp", pan=18, volume=96, reverb=0.32, gate=1.0)
    bass = s.part("bass", "acoustic_bass", role="bass", pan=0, volume=96, reverb=0.08)
    kit = s.drums("kit", "orchestra", volume=82, reverb=0.28)

    flute.dyn({1: 84, 2: 94})
    glock.dyn({1: 70, 2: 80})
    horn.dyn({1: 70, 2: 82})
    harp.dyn({1: 70, 2: 78})
    bass.dyn({1: 80, 2: 86})

    # the pop
    pizz.chords((1, 1), "x...", voices=4, low="C4", high="C5", gate=0.4)
    kit.hit(1, 1, "block_hi", 92)
    harp.line(1, 1, "C4:.125 E4:.125 G4:.125 C5:.625")

    # the motif's tail, then the bright ending
    flute.place(1, 2, motif.tail(s, 5))                          # D5 E5 G5
    flute.line(2, 1, "C6:.5 D6:.5 E6:3_>")
    for n in list(flute.notes):
        if n.t < s.at(2):
            glock.note(1, 1 + n.t, n.pitch + 12, n.dur)
    glock.line(2, 3, "G6:.25 C7:1.75")
    flute.auto_swell(1.5)

    horn.line(1, 2, "B4:.5 C5:.5 D5:2 | Eb5:.5* D5:.5 C5:3_")      # contrary to the flute
    horn.auto_swell(1.5)
    harp.line(2, 2, "C4:.125 G4:.125 C5:.125 E5:.125 G5:2.5")     # one rolled C chord
    pizz.chords((2, 2), "xxx.....", voices=3, low="Eb4", high="D5", gate=0.4)   # Ab Bb C
    bass.line(1, 1, "C2:1' G2:3 | Ab2:.5 Bb2:.5 C2:3_")
    kit.hit(2, 2, "crash", 86)
    kit.hit(2, 2, "triangle", 78)
    kit.hit(2, 2, "kick", 80)
    return s
