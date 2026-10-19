# からだのなか だいぼうけん — 開発メモ（Claude 向け）

子ども向け（6〜10 歳）の体のしくみを学ぶ 3D ゲーム。Godot 4.7（GDScript）＋ Blender（bpy スクリプトで GLB 生成）。
企画は `docs/design.md`、使い方・構成は `README.md`。

## 変更するときの約束

- 文章は ひらがな・カタカナ中心。一文字の臓器名は「い（胃）」「は（歯）」「ち（血）」のように漢字を添える。分かち書き（単語の間にスペース）。
- 体の事実は子ども向けに丸めてよいが、間違いは入れない（数値は `docs/design.md` の表に合わせる）。
- ステージの文章・ミッション・カード・クイズはすべて `godot/src/autoload/stage_db.gd`。ステージの形とスポーン位置は `blender/stages.py`（Empty の名前 `MK_...` がスポーン）。
- モデルを変えたら GLB を作り直す：`<venv>/bin/python -m blender.characters <name>` / `-m blender.stages <stage_env>`（`blender -b -P blender/stages.py -- stage_mouth` でも可）。
- 生成した GLB・WAV はコミットする。`godot/.godot/` と `blender/out/` はコミットしない。
- Godot 側のコードは「子どもが詰まらない」を最優先：ゲームオーバーなし、はさまったら戻す、ヒントは上書きしない（`Game.hud_busy()`）。

## テスト（必ず通してからコミット）

```bash
export GODOT=/path/to/Godot_v4.7-stable_linux.x86_64
tools/run_tests.sh                 # 全ステージ：インポート → 床プローブ → 自動操縦でクリアまで
tools/run_tests.sh --stage=mouth   # 1 ステージだけ
tools/screenshot.sh mouth /tmp/a.png --play=3   # Xvfb + Mesa でスクリーンショット（見た目の確認）
tools/screenshot.sh model:pod /tmp/b.png        # キャラクター 1 体だけ
```

- `RESULT: OK` と `PROBE RESULT: OK` が出ること。`SCRIPT ERROR` が 1 つも出ないこと。
- 自動操縦は `godot/tests/autopilot.gd`（テストとスクリーンショットで共用）。

## よくある落とし穴

- Godot の trimesh 当たり判定は片面。部屋・くだのメッシュは面を内向きにそろえる（`orient_inward()` = 一貫化＋全反転）。
- マーカーの高さがずれても、ひろいもの・ゴール・神経などは実行時に床へ吸着する（`ModelLib.snap_to_floor`）。
- `set_anchors_preset` ではなく `set_anchors_and_offsets_preset`（前者は 0 サイズのまま）。
- CanvasLayer の下の Control にはテーマが届かないので `Game.add_overlay()` / `_set_screen()` 経由で付ける。
- GDScript のラムダはローカル変数を値でつかむ（テストのフラグはメンバ変数にする）。
- 前は Blender の +Y（Godot の -Z）。
