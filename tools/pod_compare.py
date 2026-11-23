#!/usr/bin/env python3
"""絵（上の 段）と モデル（下の 段）を 4 方向 ならべた 1 枚を 作る。

    tools/pod_views.sh /tmp/views/                      # 先に モデルを 撮る
    python3 tools/pod_compare.py <絵の フォルダ> /tmp/views/ /tmp/compare.png [id（既定 pod）]

・絵は `<id>_3d_<向き>.png`（透過）。外形で 切りぬいて、同じ 高さに そろえて 置く。
・モデルの 画像は 背景（左上の 色）と ちがう 所を 外形と みなす。
・3 段目は ゲームの カメラから 見た 画面（game_zoom・game_left・game_front と、等倍の game）。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

VIEWS = ["front", "front_right45", "side_right", "back"]
CELL = 520
BG = (230, 230, 230)


def crop_art(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    a = np.array(im)[:, :, 3] > 16
    ys, xs = np.where(a)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    out = Image.new("RGBA", im.size, BG + (255,))
    out.alpha_composite(im)
    return out.convert("RGB")


def crop_render(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    px = np.array(im).astype(int)
    diff = np.abs(px - px[2, 2]).sum(axis=2) > 12
    ys, xs = np.where(diff)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def fit(im: Image.Image, h: int) -> Image.Image:
    w = max(1, round(im.width * h / im.height))
    return im.resize((w, h), Image.LANCZOS)


def paste_center(sheet: Image.Image, im: Image.Image, cx: int, cy: int) -> None:
    sheet.paste(im, (cx - im.width // 2, cy - im.height // 2))


def main() -> None:
    art_dir, shot_dir, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    name = sys.argv[4] if len(sys.argv) > 4 else "pod"
    sheet = Image.new("RGB", (CELL * 4, CELL * 3), BG)
    h = int(CELL * 0.86)
    for i, v in enumerate(VIEWS):
        art = art_dir / f"{name}_3d_{v}.png"
        if art.exists():
            paste_center(sheet, fit(crop_art(art), h), CELL * i + CELL // 2, CELL // 2)
        shot = shot_dir / f"{name}_{v}.png"
        if shot.exists():
            paste_center(sheet, fit(crop_render(shot), h), CELL * i + CELL // 2, CELL + CELL // 2)
    for i, v in enumerate(["game_zoom", "game_left", "game_front", "game"]):
        shot = shot_dir / f"{name}_{v}.png"
        if not shot.exists():
            continue
        im = Image.open(shot).convert("RGB")
        if v == "game":
            # 等倍：画面の 下から CELL の 高さ（船は 画面の 下 1/4 あたりに 映る。本当の 大きさの まま）
            cx = im.width // 2
            im = im.crop((cx - CELL // 2, im.height - CELL, cx + CELL // 2, im.height))
        else:
            s = min(im.width, im.height)
            im = im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width + s) // 2, (im.height + s) // 2)).resize((CELL, CELL), Image.LANCZOS)
        sheet.paste(im, (CELL * i, CELL * 2))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print("saved", out)


if __name__ == "__main__":
    main()
