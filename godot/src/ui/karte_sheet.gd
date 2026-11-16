## カルテの 紙：「なにが おきていた？／どうして？／これからは？」＋ げんいんの タイプ（不調の パターン）。
## カルテ画面の 段 1 と、ずかんの ポップアップ（card.gd）が 同じ ものを 使う（見た目と はみ出しの 検査を 1 か所に）。
## 「げんいんの タイプ」は シリーズで 学ぶ こと（EpisodeDB.PATTERNS）：同じ タイプの 話を 子どもが つなげて 読める。
## 挿絵 cards/card_<ep>_karte.png が あれば 3 つの 段の 左に 出す（無ければ 文が 幅 いっぱい）。

const T := preload("res://src/ui/ui_theme.gd")

const HEADS := ["なにが おきていた？", "どうして？", "これからは？"]
const KEYS := ["what", "why", "next"]
const COLORS := [Color(0.9, 0.35, 0.5), Color(0.3, 0.5, 0.75), Color(0.25, 0.6, 0.45)]
const WIDTH := 848.0         # 紙の 幅（パネル 940 − ふち）
const MAX_HEIGHT := 405.0    # これより 高いと 入らない（カルテ画面の 段 1 は 417、ずかんの ポップアップは 427 まで 入る）
const PIC_SIZE := Vector2(176, 220)   # 挿絵の わく。広く すると 文の 幅が へって 行が ふえる
const STAMP := Color(0.85, 0.42, 0.25)


## reserve_pic は テスト用：挿絵が 無くても 挿絵の 列を 空けて 作る（絵が 届いた ときの 高さを 先に 調べる）
static func build(ep: Dictionary, reserve_pic := false) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = WIDTH
	vb.add_theme_constant_override("separation", 8)
	var k: Dictionary = ep["karte"]
	var pic: Control = T.art_rect("cards/card_%s_karte" % ep["id"], PIC_SIZE)
	if pic == null and reserve_pic:
		pic = Control.new()
		pic.custom_minimum_size = PIC_SIZE
	var text_w := WIDTH - 18.0
	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 8)
	if pic != null:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 16)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(pic)
		top.add_child(sections)
		vb.add_child(top)
		text_w -= PIC_SIZE.x + 16.0
	else:
		vb.add_child(sections)
	for i in 3:
		# 段：左に 色の おび、右に 見出しと 本文
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var bar := Panel.new()
		bar.custom_minimum_size = Vector2(6, 0)
		bar.add_theme_stylebox_override("panel", T.rounded(COLORS[i], 3, 0))
		row.add_child(bar)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(T.label(HEADS[i], 20, COLORS[i]))
		var body := T.body(k[KEYS[i]], 22)
		body.custom_minimum_size.x = text_w
		col.add_child(body)
		row.add_child(col)
		sections.add_child(row)
	# げんいんの タイプ：はんこの ような ふだ ＋ ひとこと を 1 行ずつ
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	var head := T.label("げんいんの タイプ", 20, STAMP)
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	prow.add_child(head)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	for p in EpisodeDB.patterns(ep):
		var info: Dictionary = EpisodeDB.PATTERNS[p]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var chip := PanelContainer.new()
		var sb := T.rounded(Color(1.0, 0.96, 0.92), 10, 3, STAMP)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		chip.add_theme_stylebox_override("panel", sb)
		chip.add_child(T.label(info["name"], 20, STAMP))
		line.add_child(chip)
		var ml := T.label(info["msg"], 20, Color(0.45, 0.4, 0.42))
		ml.add_theme_font_override("font", Game.font_regular)
		line.add_child(ml)
		list.add_child(line)
	prow.add_child(list)
	vb.add_child(prow)
	return vb
