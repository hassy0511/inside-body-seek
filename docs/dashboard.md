# ダッシュボード（いまの状態）

最終更新：2026-10-19

ゲームの仕組み・文章・テスト・音は Claude が進め、**絵と 3D モデルのデザインは Codex に発注する**（`docs/art_orders/README.md`）。
いまの見た目はすべて仮（Blender スクリプトで自動生成）。納品があれば同じ名前のファイルを置きかえるだけで本番に差しかわる（`docs/art_orders/取り込み手順.md`）。

---

## 1. 全体の段階

| 段階 | 内容 | 状態 |
|------|------|------|
| 企画 | `docs/design.md`（10 ステージ、操作、ミッション、学び） | 済 |
| 仕組み | プレイヤー・カメラ・ミッション・カード・クイズ・ほし・セーブ・タッチ操作 | 済（全 10 ステージが自動テストでクリアまで通る） |
| ステージ | 口・食道・胃・小腸・血管・心臓右・肺・心臓左・脳・鼻 | 済（形は仮。口・食道は磨き込み済み） |
| 音 | 効果音・BGM（numpy 生成） | 済（仮。差しかえ可） |
| 絵・モデル | Codex に発注 → 納品 → Claude が 3D 化・組み込み | **発注の準備 済。W0 を出すところ** |
| 配布 | エクスポート（PC／Web／スマホ） | 未 |

## 2. いま動いていること・ユーザーに確認したいこと

- **W0 アートバイブルの発注**：`docs/art_orders/codex_prompts.md` 1 章の文を Codex に貼る（7 章にも同じ文）。納品されたら 3 案から 1 案を選んでもらう。
- 選定後、第2弾（W1-01 主人公たち、W2-01 てき、W2-02 なかま）を 3 本同時に出せる。

## 3. 絵の発注と納品

| 波 | 発注書 | 出した日 | 納品 | 確認 | 組み込み |
|----|-------|---------|------|------|---------|
| W0 | `W0_01_アートバイブル.md` | 未 | — | — | — |
| W1 | `W1_01_主人公たち.md` | W0 選定後 | — | — | — |
| W2 | `W2_01_てき.md` | W0 選定後 | — | — | — |
| W2 | `W2_02_なかま.md` | W0 選定後 | — | — | — |
| W2 | `W2_03_アイテムと小物.md` | 第3弾 | — | — | — |
| W3 | `W3_01_からだのぶたい.md` | 第4弾 | — | — | — |
| W4 | `W4_01_UI.md` | 第3弾 | — | — | — |
| W4 | `W4_02_ものしりカードの挿絵.md` | 第3弾 | — | — | — |

## 4. 3D モデルの状態

すべて仮（`blender/characters.py` / `blender/stages.py` の自動生成）。**GLB の名前と、Godot が探す部品名（`Propeller`、`Window`）は差しかえの約束なので変えない。**

| 種類 | ID（GLB 名） | 状態 | 発注書 |
|------|------------|------|-------|
| 主人公 | pod（＋Window・Propeller）、pico | 仮 | W1-01 |
| てき | mushiba、pylori、akudama、virus、boss_virus | 仮 | W2-01 |
| なかま | rbc、wbc、zendama、wallcell、villus、neuron | 仮 | W2-02 |
| アイテム | nutrient_a/b/c、heart_item、food、cholesterol、dust | 仮 | W2-03 |
| しかけ | ゴール・チェックポイント・べん・なみ・おくすりバブル・いえき（コードで生成） | 仮 | W2-03 |
| ステージ | stage_mouth … stage_nose（10） | 仮（表面の画像は未対応） | W3-01 |
| UI | コードで描画（`ui_theme.gd`）。PNG があれば自動で使う | 仮 | W4-01 |
| カードの挿絵 | 3D モデルのプレビューで代用。PNG があれば自動で使う | 仮 | W4-02 |

### 納品 PNG の差しかえ先（コードの変更なしで差しかわる）
| 納品物 | 置き場所 |
|-------|---------|
| ものしりカードの挿絵 | `godot/assets/ui/cards/card_<stage>_<key>.png`（story は `card_story_intro.png`） |
| ピコの顔（HUD） | `godot/assets/ui/pico_face_normal.png` |
| タイトルの絵・ロゴ | `godot/assets/ui/title_keyvisual.png`、`title_logo.png` |
| からだの地図 | `godot/assets/ui/bodymap_hana.png`（SVG より優先） |
| ステージのアイコン | `godot/assets/ui/stage_icons/stage_icon_<stage>.png` |
| エンディングの はなちゃん | `godot/assets/ui/hana_fullbody_happy.png` |
| そのほかの UI 部品（ハート・ボタン・9 分割の枠） | `godot/assets/ui/`（取り込み時に `ui_theme.gd` へ StyleBoxTexture を足す） |

## 5. 残課題

- ステージの表面の画像（テクスチャ）の貼り付けは未実装（W3 の納品に合わせて `common.material(image=)` と UV を足す）。
- 表情の切りかえ（うれしい・いたい）はまだ使っていない（モデルで目・口を別部品にしておく）。
- エクスポート設定（PC／Web／Android）。
- 効果音・BGM の本番化（必要なら別途発注）。

## 6. 記録

- 2026-10-19：Codex への発注の仕組みを整備（発注書 8 本、プロンプト、取り込み手順、差しかえ用のコード）。口・食道の磨き込みを取り込み。
- それ以前：`docs/progress.md`。

## 7. Codex に出す依頼文（貼るだけ）

### W0 アートバイブル（いま出す）

```text
あなたはゲーム開発プロジェクト『からだのなか だいぼうけん』の作画担当です。リポジトリ https://github.com/hassy0511/inside-body-seek を取得し、ブランチ claude/great-wright-k5ui35 の docs/art_orders/codex_prompts.md を開いて、「1. W0：アートバイブル（最初に出す）」のコードブロックを最後まで読み、その指示どおりに作業して納品（art/w0 へ push）してください。
指示の中で読むよう書かれている文書と絵は必ず読んでください。見つからないファイルがあれば作業を止めて報告してください。
絵は必ず画像生成機能で描いてください。3D ソフトで作った画像やプログラムで描いた図形は不可です。描けないときは、spec の冒頭に「未納品」と書いてください。
```

### 第2弾（W0 の選定後に、`<選定案>` を a/b/c のどれかにして出す）

```text
あなたはゲーム開発プロジェクト『からだのなか だいぼうけん』の作画担当です。リポジトリ https://github.com/hassy0511/inside-body-seek を取得し、ブランチ claude/great-wright-k5ui35 の docs/art_orders/codex_prompts.md を開いて、「2. W1〜W4：個別の発注」のコードブロックを最後まで読み、次の値を当てはめて、その指示どおりに作業して納品してください。
- <発注書> = W1_01_主人公たち.md
- <波> = art/w1-hero
- <フォルダ> = art/concepts/W1_hero/
- <コミット文> = art: W1-01 hero (pod, pilot, pico, hana)
- <選定案> = <a/b/c>
指示の中で読むよう書かれている文書と絵は必ず読んでください。見つからないファイルがあれば作業を止めて報告してください。
絵は必ず画像生成機能で描いてください。3D ソフトで作った画像やプログラムで描いた図形は不可です。描けないときは、spec の冒頭に「未納品」と書いてください。
```

（W2-01 は `<発注書> = W2_01_てき.md`、`<波> = art/w2-enemies`、`<フォルダ> = art/concepts/W2_enemies/`、`<コミット文> = art: W2-01 enemies`。W2-02 は `W2_02_なかま.md` / `art/w2-friends` / `art/concepts/W2_friends/` / `art: W2-02 friends`。）
