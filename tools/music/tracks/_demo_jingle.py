"""_demo_jingle - a worked example of a short piece that does not loop.

loop=False: rendered once; `tail` seconds of ring are kept after the last bar
and faded out over the last 80 ms; loudness target -16 LUFS.
output="wav_mono" makes a mono 16-bit WAV (what clear.wav needs); leave it
out for a stereo OGG (jingle_enter, jingle_exit, jingle_karte).

Two bars of 4/4 at 132 plus 1.2 s of ring = 4.8 s: the motif's head as a
little fanfare (trumpet and horn in thirds), a held C major chord, a timpani
roll and a cymbal.  Chords: C | F (1 beat) G7 (1 beat) C (2 beats, held in the ring).
"""
from tools.music import motif
from tools.music.score import Song


def song() -> Song:
    s = Song("_demo_jingle", tempo=132, key="C", bars=2, loop=False, tail=1.2,
             output="wav_mono", where="example only")
    s.harmony(1, "C | F:1 G7:1 C:2")      # chord lengths in beats
    tpt = s.part("trumpet", "trumpet", role="melody", volume=92, reverb=0.3)
    horn = s.part("horn", "french_horn", role="counter", pan=-20, volume=90, reverb=0.4)
    glock = s.part("glock", "glockenspiel", role="sparkle", pan=25, volume=80, reverb=0.4, gate=1.0)
    kit = s.drums("kit", "orchestra", volume=96, reverb=0.3)
    tpt.dyn({1: 90, 2: 100})
    horn.dyn({1: 80, 2: 90})
    tpt.place(1, 1, motif.head(s, 5))                    # C G F E
    horn.place(1, 1, motif.head(s, 4, shift=-2))          # a third below: A E D C
    tpt.line(2, 1, "F5:1 G5:1 C6:2_>")
    horn.line(2, 1, "C5:1 B4:1 E5:2_")
    glock.line(2, 3, "C6:.25 E6:.25 G6:.25 C7:1.25")
    kit.fill(1, 1, "kick:1 r:3")
    kit.hit(2, 3, "crash", 96)
    kit.hit(2, 3, "kick", 100)
    return s
