"""The shared motif ("the adventure call"): two bars, seven notes.

In C major, 4/4 (beats in quarters):

    bar 1:  C5 (1)   G5 (1.5)   F5 (.5)   E5 (1)
    bar 2:  D5 (.5)  E5 (.5)    G5 (2)    rest (1)

degrees 1 5 4 3 | 2 3 5 : a brave leap up a fifth, a step back down, and a
question at the end (it stops on degree 5 over a short climb).  The rhythm to
recognise is "long - lo-ong - short - long | short-short - looong".

The motif is stored as scale steps (0 = degree 1) so it fits any key and mode:
in D minor ``notes(song, ...)`` gives D A G F | E F A automatically.

Use it like this in a track::

    from tools.music import motif
    lead.place(1, 1, motif.notes(song, octave=5))                 # as written
    lead.place(3, 1, motif.notes(song, octave=5, shift=2))        # a third higher (sequence)
    horn.place(9, 1, motif.notes(song, octave=4, stretch=2))      # augmentation: 4 bars
    lead.place(5, 1, motif.notes(song, octave=5, invert=True))    # upside down
    lead.place(7, 1, motif.head(song, octave=5))                  # first bar only
    lead.place(8, 1, motif.tail(song, octave=5))                  # second bar only

Every function returns a list of (offset_beats, dur_beats, midi_pitch) for
``part.place(bar, beat, notes)``.  ``bar`` / ``beat`` of place() are where the
first note starts.  In 6/8 the 6/8 rhythm (MOTIF_68) is used automatically.
"""
from __future__ import annotations

# (scale step from degree 1, offset in quarter beats, duration in quarter beats)
MOTIF_44 = [
    (0, 0.0, 1.0),
    (4, 1.0, 1.5),
    (3, 2.5, 0.5),
    (2, 3.0, 1.0),
    (1, 4.0, 0.5),
    (2, 4.5, 0.5),
    (4, 5.0, 2.0),
]
LENGTH_44 = 8.0   # two bars of 4/4 (the last beat is a rest)

# the same contour in 6/8 (offsets in eighths): C. G F | E D E G.
MOTIF_68 = [
    (0, 0.0, 3.0),
    (4, 3.0, 2.0),
    (3, 5.0, 1.0),
    (2, 6.0, 1.0),
    (1, 7.0, 1.0),
    (2, 8.0, 1.0),
    (4, 9.0, 3.0),
]
LENGTH_68 = 12.0


def _base(song):
    if song.compound:
        return MOTIF_68, LENGTH_68
    return MOTIF_44, LENGTH_44


def steps(song) -> list[int]:
    return [s for s, _, _ in _base(song)[0]]


def notes(song, octave: int = 5, *, shift: int = 0, invert: bool = False,
          retro: bool = False, stretch: float = 1.0, at_bar: int = 1,
          first: int = 0, last: int | None = None, chromatic: int = 0):
    """The motif as (offset, dur, pitch) in the key of the song at `at_bar`.

    shift: diatonic steps up (2 = a third higher; sequences).
    invert: turn it upside down around its first note.
    retro: play it backwards (rhythm too).
    stretch: 2 = augmentation (twice as long), 0.5 = diminution.
    first/last: take only notes first..last-1 (0..7).
    chromatic: semitones added after everything (to put it in another key)."""
    base, length = _base(song)
    items = list(base)
    if retro:
        end = max(o + d for _, o, d in items)
        items = sorted(((s, end - (o + d), d) for s, o, d in items), key=lambda x: x[1])
    if invert:
        s0 = items[0][0]
        items = [(2 * s0 - s, o, d) for s, o, d in items]
    items = items[first:last]
    if not items:
        return []
    o0 = items[0][1]
    t = song.at(at_bar)
    out = []
    for s, o, d in items:
        step = s + shift
        pitch = song.deg(step + 1, octave, t=t) + chromatic
        out.append(((o - o0) * stretch, d * stretch, pitch))
    return out


def head(song, octave: int = 5, **kw):
    """The first bar of the motif (four notes)."""
    return notes(song, octave, first=0, last=4, **kw)


def tail(song, octave: int = 5, **kw):
    """The second bar of the motif (three notes)."""
    return notes(song, octave, first=4, **kw)


def as_line(song, octave: int = 5, **kw) -> str:
    """The motif as text for part.line() (handy to print and edit by hand)."""
    from .score import name_of
    out = []
    t = 0.0
    for o, d, pch in notes(song, octave, **kw):
        if o > t + 1e-9:
            out.append(f"r:{o - t:g}")
        out.append(f"{name_of(pch)}:{d:g}")
        t = o + d
    return " ".join(out)
