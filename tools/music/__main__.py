"""python -m tools.music build [names...] | check [names...] | table | list

  build  renders the pieces (all when no names) and checks each one.
  check  runs the checks on what was built; prints MUSIC: OK or the failures.
  table  writes the table of pieces into docs/audio.md (never run by build).
  list   prints the track names.
  seamtest [names]  shows that the seam check catches broken loops.
  godot [names]     asks Godot ($GODOT) whether each OGG is imported looping and plays across the loop point.
Names starting with '_' are examples (they stay in tools/music/out/).
"""
from __future__ import annotations

import sys
import time

from . import analyze, render


def _names(args, include_examples=False):
    return args or render.track_names(include_examples)


def _print_result(r):
    st = r["stats"]
    bits = []
    if "lufs" in st:
        bits.append(f"{st['lufs']:.2f} LUFS")
    if "true_peak" in st:
        bits.append(f"TP {st['true_peak']:.2f} dBTP")
    if "seconds" in st:
        bits.append(f"{st['seconds']:.2f} s")
    if "bytes" in st:
        bits.append(f"{st['bytes']} B")
    if "seam" in st:
        bits.append("seam click {click:.2f} drop {drop:+.1f} dB".format(**st["seam"]))
    head = "FAIL" if r["fails"] else "ok"
    print(f"{r['name']}: {head}  " + ", ".join(bits) + f"  ({len(r['warns'])} warnings, report: tools/music/out/{r['name']}/report.md)")
    for f in r["fails"]:
        print(f"  FAIL {f}")


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    cmd, args = argv[0], [a for a in argv[1:] if not a.startswith("--")]
    flags = [a for a in argv[1:] if a.startswith("--")]
    if cmd == "list":
        print("\n".join(render.track_names(True)))
        return 0
    if cmd == "build":
        results = []
        for n in _names(args):
            t = time.time()
            render.build(n)
            r = analyze.check(n)
            _print_result(r)
            print(f"  ({time.time() - t:.0f} s)")
            results.append(r)
        bad = [r for r in results if r["fails"]]
        print("MUSIC: OK" if not bad else f"MUSIC: FAIL ({', '.join(r['name'] for r in bad)})")
        return 1 if bad else 0
    if cmd == "check":
        results = []
        for n in _names(args):
            r = analyze.check(n, pics="--no-pics" not in flags)
            _print_result(r)
            results.append(r)
        bad = [r for r in results if r["fails"]]
        print("MUSIC: OK" if not bad else f"MUSIC: FAIL ({', '.join(r['name'] for r in bad)})")
        return 1 if bad else 0
    if cmd == "seamtest":
        ok = all([analyze.seamtest(n) for n in _names(args)])
        return 0 if ok else 1
    if cmd == "godot":
        from . import godot_check
        return godot_check.run(_names(args))
    if cmd == "table":
        from . import table
        table.write()
        return 0
    print(f"unknown command {cmd!r}\n{__doc__}")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
