---
name: model-from-art
description: Codex が描いた多視点の絵（正面・背面・真横・真上・斜め 45°・表情・分解図）から、このゲームの 3D モデル（丸い部品を組み合わせた GLB）を作って Godot に入れる手順。キャラクター・てき・なかま・小物・ステージの部品の 3D 化、仮モデルの差しかえ、発注書の「3D 変換用の絵」の条件を決めるときに使う。
---

# 絵から 3D モデルを作る（からだのなか だいぼうけん）

アークウォーカー（project-relic）の `model-from-art` で行き着いた「**形のあるものは部品で組み、色は spec の hex で平らに塗る**」をそのまま使う。
このゲームのキャラクターは「丸い塊 1〜3 個＋目＋口」なので、人物の骨・顔貼りは要らない。**絵の外形を測って、球・カプセル・円すい・トーラスの寸法を決める**だけでよい。1 体 20〜40 分が目安。

絵の条件：`docs/art_orders/01_3D変換用の絵の条件.md`（発注のときにそのまま渡す）。
取り込みの全体：`docs/art_orders/取り込み手順.md`。

---

## 0. 結論：3 つの決まり

1. **絵は写さない。寸法と色見本だけを使う。** 絵を各方向から投影して色にすると、まだらになる（アークウォーカーで 4 回直しても残った）。部品ごとに spec の hex 1 色（＋発光部は別マテリアル）。
2. **部品の表を先に作る。** 絵の中の物を 1 つずつ「体（球／カプセル／だ円）」「目・口」「突起（角・トゲ・べん毛・ひれ・枝）」「別部品（動くもの：プロペラ・ふた・ドリル）」に分ける。迷ったら別部品。
3. **報告の前に、4 方向の並び（絵 ↔ モデル）を 1 枚にして見る。** 直した 1 枚だけで「できた」としない。

---

## 1. 受け取ったら最初に確かめる（10 分）

1. 絵がそろっているか：`<ID>_3d_front / back / side_right / top / front_right45`（＋ `bottom`、`parts`、`faces`）。足りなければ**作り始める前に**修正依頼（`docs/art_orders/codex_prompts.md` 3 章）。
2. 透過か（`python -I tools/art_measure.py <png>` でアルファの外形の bbox を出す。無ければ下のスニペット）。背景が塗られていたら修正依頼。
3. 整合：全方向で「底の行」「てっぺんの行」「中心の列」の px が一致するか。ずれが 2% を超える向きは寸法に使わない（その向きは形の確認だけに使う）。
4. 縮尺：spec の全長（m）÷ 外形の幅（px）＝ m/px。この 1 つの値で全部品の寸法を出す。

```python
# アルファから外形を測る（PIL が無ければ godot の Image でもよい）
from PIL import Image; import numpy as np, sys
a = np.array(Image.open(sys.argv[1]).convert("RGBA"))[:, :, 3] > 16
ys, xs = np.where(a); print("bbox", xs.min(), ys.min(), xs.max(), ys.max(), "w", xs.max()-xs.min(), "h", ys.max()-ys.min())
```

---

## 2. 部品の表を書く

結果の文書（`docs/art_orders/<波>_<ID>3D化の結果.md`）の冒頭に書く。例（むしばきん）：

| 部品 | 形 | 寸法（m） | 位置（体の中心を 0、前 +Y） | 色（hex） | 材質 |
|------|----|----------|------------------------|---------|------|
| 体 | 球 | r 0.42 | (0, 0, 0) | #4A3B5C | つやなし |
| 目 ×2 | 球（白）＋球（黒） | r 0.11 / 0.06 | (±0.16, 0.34, 0.08) | #FFFFFF / #222233 | つやあり |
| 角 ×2 | 円すい | r 0.07, h 0.22 | (±0.2, 0, 0.38) 外向き 25° | #6B5A80 | つやなし |
| ドリル | 円すい＋らせんの溝 | r 0.1, h 0.35 | 右手 (0.45, 0.2, -0.05) 前向き | #C8C8D0 | つやあり |

- 寸法は 1 章の m/px で **正面の絵から 幅と高さ、真横の絵から 奥行き** を測る。
- 突起の向きは 45° の絵で確かめる（正面と真横だけでは前後の傾きが決まらない）。
- 表情：目・口は別部品にして、`faces.png` の「通常」で作る。ほかの表情はゲーム側でまだ使わない（将来 シェイプキーにするときは目・口を部品のまま残しておく）。

---

## 3. 作る（`blender/characters.py`）

- `BUILDERS["<ID>"]` の関数を書きかえる。**関数名・GLB 名（`godot/assets/models/characters/<ID>.glb`）・前の向き（Blender +Y）・部品の名前（`Propeller`、`Window`、`Core` など Godot が探す名前）は変えない**。これが仮モデルと本番モデルの差しかえの約束。
- 使う道具は `blender/common.py`：`sphere / capsule / cone / torus / material / eyes / smile / join / export_glb`。足りない形は `common.py` に足す（ステージも使うので共通に）。
- 色は spec の hex を `material(name, hex, emission=…)` で。`roughness` は「つやなし 0.9 / つやあり 0.4」。発光部は `emission` に同じ色。
- 大きさは**実寸（m）で作る**。ゲーム側の `ModelLib.fit()` / `enemy.gd` の `CONFIG.radius` が当たり判定を持つので、モデルの全長が spec と違うと ずれる。変えたら `CONFIG` も合わせる。
- 書き出し：`<venv>/bin/python -m blender.characters <ID>`。

---

## 4. 確かめる

1. `tools/screenshot.sh model:<ID> /tmp/m.png` で 1 体。4 方向は `--yaw=0/90/180/270`（無ければ `godot/tests/shot.gd` に足す）。
2. 絵と並べる：`python -I tools/art_compare.py <ID>`（無ければ ImageMagick `montage` で 2×4）。**外形の一致**を見る（色の細部は見ない）。
3. ゲームの中：`tools/screenshot.sh <stage> /tmp/s.png --play=3`。カメラは後ろ上なので、**上と後ろから見て分かるか**を見る。
4. `tools/run_tests.sh --stage=<stage>`（当たり判定の半径を変えたときは必ず）。

---

## 5. 結果の文書

`docs/art_orders/<波>_<ID>3D化の結果.md`：使った絵、m/px、部品の表、絵との違い（残したもの・理由）、当たり判定の変更、スクリーンショット（`docs/screenshots/`）、かかった時間。
`docs/dashboard.md` 4 章の行を「仮 → 本番」に更新する。

---

## 6. ステージの部品・表面

- 表面の画像（`tex_<stage>_<wall|floor>.png`）は `godot/assets/textures/` に置き、`blender/stages.py` のマテリアルに `image=` で貼る（`common.material()` に画像対応を足す。UV は `tube()` が長さ方向に、`ellipsoid_room()` が経度・緯度で付ける）。1 枚が何 m 四方かは spec の値。
- 部品は 2〜3 章と同じ。`build_<stage>()` の中で `scatter_on_floor()` / 壁への配置に渡す。当たり判定が不要な飾りは名前に `NC_` を付ける。
