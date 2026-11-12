## カルテの 紙：「なにが おきていた？／どうして？／これからは？」＋ げんいんの タイプ（不調の パターン）。
## カルテ画面の 段 1 と、ずかんの ポップアップ（card.gd）が 同じ ものを 使う（見た目と はみ出しの 検査を 1 か所に）。
## 「げんいんの タイプ」は シリーズで 学ぶ こと（EpisodeDB.PATTERNS）：同じ タイプの 話を 子どもが つなげて 読める。

const T := preload("res://src/ui/ui_theme.gd")

const HEADS := ["なにが おきていた？", "どうして？", "これからは？"]
const KEYS := ["what", "why", "next"]
const COLORS := [Color(0.9, 0.35, 0.5), Color(0.3, 0.5, 0.75), Color(0.25, 0.6, 0.45)]
const WIDTH := 848.0         # 紙の 幅（パネル 940 − ふち）
const MAX_HEIGHT := 400.0    # これより 高いと ずかんの ポップアップ（940×640）に 入らない（カルテ画面は 430 まで 入る）


static func build(ep: Dictionary) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = WIDTH
	vb.add_theme_constant_override("separation", 4)
	var k: Dictionary = ep["karte"]
	for i in 3:
		vb.add_child(T.label(HEADS[i], 20, COLORS[i]))
		var body := T.label(k[KEYS[i]], 22, T.INK)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = WIDTH
		body.add_theme_font_override("font", Game.font_regular)
		vb.add_child(body)
	# げんいんの タイプ：左に 見出し、右に「ふだ ＋ ひとこと」を 1 行ずつ
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var head := T.label("げんいんの タイプ", 20, Color(0.75, 0.5, 0.2))
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(head)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	for p in EpisodeDB.patterns(ep):
		var info: Dictionary = EpisodeDB.PATTERNS[p]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var chip := PanelContainer.new()
		var sb := T.rounded(Color(1.0, 0.95, 0.8), 14, 3, Color(0.85, 0.6, 0.1))
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		chip.add_theme_stylebox_override("panel", sb)
		chip.add_child(T.label(info["name"], 20, Color(0.6, 0.4, 0.05)))
		line.add_child(chip)
		var ml := T.label(info["msg"], 20, Color(0.45, 0.4, 0.42))
		ml.add_theme_font_override("font", Game.font_regular)
		line.add_child(ml)
		list.add_child(line)
	row.add_child(list)
	vb.add_child(row)
	return vb
