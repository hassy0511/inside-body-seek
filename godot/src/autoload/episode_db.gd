extends Node
## カルテ（1 話）の 定義。場所（GLB・マーカー・ものしりカード・既定の ミッション）は StageDB.STAGES。
## ここには 話の 文と、場面（scene）ごとの 上書きだけを 書く。設計は docs/episodes.md。
##
## 書きかたの きまり（tools/build_dashboard.py が 正規表現で 読む）：
## - 各話の 1 行目は「\t\t"id": "epNN", "no": N, "title": "…", "patient": "…", "pattern": "…", "difficulty": N,」
## - 場面は 4 タブで「"place": "<場所 id>",」を 1 行に 単独で 書く（よそうの choices は「{"place": …}」と 波かっこから 始める）
## - 文は ひらがな・カタカナ・わかち書き。漢字は「い（胃）」の ように（ ）の 中だけ（validate() が 調べる）
## - 大事な 種あかしは HUD（intro・goal_say など。時間で 消える）に 書かない。after（ボタンで 進む）と karte に 書く

const SEASON_COMPLETE := false   # 10 話 そろったら true（さいごの カルテの あとに エンディングを 出す）

const PATIENTS := {
	"hana": {"name": "はなちゃん", "color": Color(1.0, 0.72, 0.8)},
	"kenta": {"name": "けんたくん", "color": Color(0.62, 0.86, 1.0)},
	"papa": {"name": "おとうさん", "color": Color(0.6, 0.9, 0.75)},
	"jiji": {"name": "おじいちゃん", "color": Color(1.0, 0.86, 0.35)},
}
const PICO := {"name": "ドクター・ピコ", "color": Color(0.75, 0.92, 1.0)}

## 不調の パターン（story.md 3 章）。カルテの 紙に「げんいんの タイプ」として 出る
const PATTERNS := {
	"A": {"name": "ばいきん・ウイルス", "msg": "てあらい・うがい・はみがきで ふせごう"},
	"B": {"name": "けが", "msg": "きずは あらって きれいに しよう"},
	"C": {"name": "まいにちの くせ", "msg": "まいにちの つみかさねが だいじ"},
	"D": {"name": "からだの まちがい", "msg": "てきを たおすだけが なおす ことじゃ ないよ"},
	"E": {"name": "ばしょ ちがい", "msg": "きめつけないで しらべよう"},
	"F": {"name": "おおきな びょうき", "msg": "がまんしないで はやく おとなと おいしゃさんへ"},
}

## からだの地図の 中での 位置（0〜1）。よそうの 画面が 使う
const ORGAN_POS := {
	"brain": Vector2(0.50, 0.085), "nose": Vector2(0.62, 0.17), "mouth": Vector2(0.50, 0.23),
	"esophagus": Vector2(0.50, 0.33), "lungs": Vector2(0.34, 0.42), "heart": Vector2(0.58, 0.40), "heart2": Vector2(0.72, 0.47),
	"stomach": Vector2(0.58, 0.54), "intestine": Vector2(0.50, 0.66), "vessel": Vector2(0.20, 0.58),
}

## はじめて カルテを ひらいた ときだけ、そうだんの 前に 出す（1 ページ）
const OPENING := [
	{"who": "pico", "text": "ようこそ、ミクロしんりょうじょへ！ ぼくは ドクター・ピコ。\nきみは みならいの ちいさな おいしゃさん。からだの なかから みんなを なおしてあげよう！"},
]
const ENDING := "みんな げんきに なった！\nミクロしんりょうじょは きょうも あいているよ。\nまた そうだんに きてね！"

const MISSION_TYPES := ["defeat", "boss", "cheer", "collect", "deliver", "gate", "sequence", "reach"]
const SPAWN_LOCKED := ["player", "goal", "path", "checkpoint"]
## 文の 長さの 上限（字）。HUD に 出る 文（intro〜clear_say）は 短く：子どもは 操縦しながら 読む
const MAX := {
	"title": 24, "line": 90, "q": 40, "say": 70, "depart": 40, "label": 20,
	"intro": 45, "goal_say": 45, "clear_say": 30, "hint": 60, "mission": 30, "each_say": 30, "done_say": 30,
	"banner": 20, "thanks": 60, "exit": 60, "karte": 62, "quiz_q": 40, "quiz_choice": 20, "explain": 90,
}
## 「い」「は」「ち」＋ 助詞 に 見えるが 臓器では ない ことば（_check_text が 見のがす）
const OK_WORDS := ["はは", "いも", "はで"]

const EPISODES: Array[Dictionary] = [
	{
		"id": "ep01", "no": 1, "title": "は（歯）が ズキズキ", "patient": "hana", "pattern": "A・C", "difficulty": 1,
		"consult": [
			{"who": "hana", "text": "おくの は（歯）が ズキズキ いたいよう。\nきのうの よる、チョコを たべて そのまま ねちゃったの。"},
			{"who": "pico", "text": "ピコッ。それは つらいね。\nミクロごうで ちいさくなって、からだの なかを しらべに いこう！"},
		],
		"guess": {
			"q": "どこが あやしいと おもう？",
			"choices": [
				{"place": "stomach", "say": "いい かんがえだね！ チョコは い（胃）にも いくよ。\nでも いたいのは は（歯）。は（歯）が あるのは どこかな？"},
				{"place": "mouth", "go": true, "hit": true, "say": "うん、くち（口）が あやしいね！\nは（歯）が あるのは くちの なか。しらべに いこう！"},
				{"place": "nose", "say": "いい かんがえだね！ はな（鼻）は くちの おとなり。\nでも いたいのは は（歯）。は（歯）が あるのは どこかな？"},
			],
			"depart": "はなちゃん、おおきく あーん！ ミクロごう、くちから はっしん！",
		},
		"scenes": [
			{
				"place": "mouth",
				"intro": "おくの は（歯）に むしばきんが いるよ。やっつけよう！",
				"hints": [
					{"at": 1.0, "text": "やじるしキー（または スティック）で うごけるよ。", "text_touch": "ひだりの まるを ゆびで うごかすと すすめるよ。"},
					{"at": 9.0, "text": "スペースキー（Aボタン）で おくすりを だすよ。ちかくの むしばきんを じどうで ねらうんだ！", "text_touch": "みぎの「おくすり」ボタンで うつよ。ちかくの むしばきんを じどうで ねらうんだ！"},
				],
				"missions": [
					{"type": "defeat", "target": "mushiba", "count": 4, "text": "むしばきんを やっつけよう"},
					{"type": "reach", "text": "のどの おくの ゴールへ いこう"},
				],
				"goal_say": "むしばきんを ぜんぶ やっつけた！ のどの おくの ゴールへ いこう！",
				"clear_say": "むしばきんを やっつけた！",
				"after": {"banner": "ピコッと はっけん！", "lines": [
					{"who": "pico", "text": "むしばきんが「さん」を だして、おくの は（歯）を とかしていたんだ。\nあまい ものの のこりかすが だいすきなんだよ。"},
				]},
			},
		],
		"karte": {
			"thanks": "ズキズキが らくに なったよ。ありがとう！ はいしゃさんにも いってくるね。",
			"exit": "のどの おくで まわれみぎ！ ガラガラ うがいの おみずに のって、くちから そとへ ぴゅーっ！",
			"what": "むしばきんが「さん」を だして、おくの は（歯）を とかしていた。",
			"why": "あまい ものを たべた あと、はみがきを しないで ねてしまった。",
			"next": "ねる まえは かならず はみがき。あなの あいた は（歯）は、はいしゃさんに なおしてもらおう。",
		},
		"quiz": {"q": "むしばきんが だいすきな ものは どれ？", "choices": ["あまい ものの のこりかす", "おみず", "はブラシ"], "answer": 0, "explain": "むしばきんは あまい ものの のこりかすを たべて、は（歯）を とかす「さん」を だすよ。たべたら はみがき！"},
	},
	{
		"id": "ep02", "no": 2, "title": "おとうさんの い（胃）が しくしく", "patient": "papa", "pattern": "A・C", "difficulty": 1,
		"consult": [
			{"who": "papa", "text": "ごはんの あと、い（胃）の あたりが しくしく いたいんだ。\nしごとが いそがしくて、いつも はやぐいでね。"},
			{"who": "pico", "text": "ピコッ。はやぐいは きに なるね。\nたべものと おなじ みちを とおって、しらべてみよう！"},
		],
		"guess": {
			"q": "どこが あやしいと おもう？",
			"choices": [
				{"place": "lungs", "say": "いい かんがえだね！ はい（肺）は いきを する ところ。\nたべた ごはんが たまるのは どこかな？"},
				{"place": "mouth", "say": "いい かんがえだね！ くち（口）は たべものの いりぐち。\nのみこんだ ごはんが たまるのは どこかな？"},
				{"place": "stomach", "go": true, "hit": true, "say": "うん、ごはんが たまる い（胃）が あやしいね！\nのどから しょくどう（食道）を とおって いこう。"},
			],
			"depart": "おとうさん、おみずと いっしょに ごくん！ ミクロごう、はっしん！",
		},
		"scenes": [
			{
				"place": "esophagus",
				"intro": "よく かまずに のみこんだ かたまりが ごろごろ！ よけて い（胃）まで くだろう。",
				"hints": [
					{"at": 1.0, "text": "ピンクの なみ（ぜんどううんどう）に のると はやく すすめるよ。"},
					{"at": 12.0, "text": "たべものの かたまりは よけてね。はたの ところが チェックポイントだよ。"},
				],
				"missions": [
					{"type": "reach", "text": "かたまりを よけて い（胃）へ いこう"},
				],
				"clear_say": "い（胃）の いりぐちに ついた！",
				"after": {"banner": "てがかり はっけん！", "lines": [
					{"who": "pico", "text": "おおきな かたまりが いっぱい だったね。\nよく かまないと、い（胃）は たくさん はたらかないと いけないんだ。"},
					{"who": "pico", "text": "つぎは い（胃）の なかを しらべよう！"},
				]},
			},
			{
				"place": "stomach",
				"intro": "ピロリきんが い（胃）の かべを いじめている！ やっつけよう。",
				"hints": [
					{"at": 1.0, "text": "きいろい いけ（いえき）に はいると ハートが へるよ。きをつけて！"},
					{"at": 14.0, "text": "なかまには さわるだけで おうえんできるよ。"},
				],
				"missions": [
					{"type": "defeat", "target": "pylori", "count": 4, "text": "ピロリきんを やっつけよう", "done_say": "ピロリきんが へった！ かべの さいぼうも おうえんしよう。"},
					{"type": "cheer", "target": "wallcell", "count": 3, "text": "い（胃）の かべの さいぼうを おうえんしよう", "done_say": "かべが げんきに なった！ ピロリきんも やっつけよう。"},
					{"type": "reach", "text": "ゴールの わっかへ いこう"},
				],
				"goal_say": "やったね！ い（胃）の かべが げんきに なった。ゴールの わっかへ いこう！",
				"clear_say": "おとうさんの い（胃）、もう だいじょうぶ！",
				"after": {"banner": "ピコッと はっけん！", "lines": [
					{"who": "pico", "text": "はやぐいの かたまりと、ピロリきん。\nふたつが い（胃）を つかれさせていたんだね。"},
				]},
			},
		],
		"karte": {
			"thanks": "おなかが らくに なってきたよ。ありがとう！ これからは ゆっくり たべるね。",
			"exit": "い（胃）の いりぐちまで もどって、げっぷに のって くちから そとへ ぽーん！",
			"what": "い（胃）の かべに ピロリきんが すみついていた。おおきな かたまりも い（胃）を つかれさせていた。",
			"why": "いそいで たべて、よく かんでいなかった。ピロリきんは、きづかない うちに い（胃）に ながく すんでいる ことが ある。",
			"next": "ひとくち 30かい、よく かんで たべよう。ピロリきんは びょういんで しらべて、おくすりで なおせるよ。",
		},
		"quiz": {"q": "い（胃）が らくに なる たべかたは どれ？", "choices": ["よく かんで ゆっくり たべる", "かまずに のみこむ", "はしりながら たべる"], "answer": 0, "explain": "よく かむと たべものが こまかくなって、い（胃）が とかしやすく なるよ。"},
	},
	{
		"id": "ep03", "no": 3, "title": "おなかが いたい…どこ？", "patient": "hana", "pattern": "E・C", "difficulty": 1,
		"consult": [
			{"who": "hana", "text": "おなかが いたいよう。\nきのう アイスを 3こ たべたから、きっと い（胃）だよ。"},
			{"who": "pico", "text": "ピコッ。おなかの なかには、い（胃）の ほかにも いろいろ あるよ。\nきめつけないで、しらべてみよう！"},
		],
		"guess": {
			"q": "どこが あやしいと おもう？",
			"choices": [
				{"place": "stomach", "go": true, "say": "はなちゃんと おなじ よそうだね。\nじゃあ まず い（胃）を みに いこう！"},
				{"place": "intestine", "go": true, "hit": true, "say": "いい よそうだね！ おぼえておこう。\nたべものが とおる じゅんばんに、まず い（胃）から しらべるよ。"},
				{"place": "brain", "say": "いい かんがえだね！ でも のう（脳）は あたまの なか。\nいたいのは おなか。おなかに あるのは どこかな？"},
			],
			"depart": "はなちゃん、おみずと いっしょに ごくん！ ミクロごう、はっしん！",
		},
		"scenes": [
			{
				"place": "stomach",
				"spawn": {"skip": ["enemy_pylori"]},
				"intro": "ここは はなちゃんの い（胃）。かべの さいぼうに さわって しらべよう！",
				"hints": [
					{"at": 1.0, "text": "やじるしの さきに かべの さいぼうが いるよ。さわると しらべられるんだ。"},
					{"at": 14.0, "text": "きいろい いけ（いえき）に はいると ハートが へるよ。きをつけて！"},
				],
				"missions": [
					{"type": "cheer", "target": "wallcell", "count": 3, "text": "い（胃）の かべの さいぼうを しらべよう", "each_say": ["この さいぼうは げんき いっぱい！", "ここも だいじょうぶ。ねんえきも たっぷり！"]},
					{"type": "reach", "text": "でぐちから もっと おくへ すすもう"},
				],
				"goal_say": "あれれ？ みんな げんき。ばいきんも いない……。でぐちの わっかへ いこう！",
				"clear_say": "い（胃）を しらべおわった！",
				"after": {"banner": "い（胃）は げんき！", "lines": [
					{"who": "pico", "text": "はなちゃんは「きっと い（胃）」と いっていたけど、い（胃）は どこも わるくなかったね。"},
					{"who": "pico", "text": "いたい ところと わるい ところは、ちがう ことが あるんだ。\nいい しらべかた だったよ！ つぎは もっと おくの ちょう（腸）を しらべよう！"},
				], "lines_hit": [
					{"who": "pico", "text": "い（胃）は どこも わるくなかったね。\nいたい ところと わるい ところは、ちがう ことが あるんだ。"},
					{"who": "pico", "text": "きみの よそうどおり、もっと おくが あやしいね！\nつぎは ちょう（腸）を しらべよう！"},
				]},
			},
			{
				"place": "intestine",
				"arrow": "nearest",
				"intro": "みつけた！ ちょう（腸）で あくだまきんが ふえて、ぜんだまきんが こまっている！",
				"hints": [
					{"at": 1.0, "text": "ひかる えいようを ひろって、みどりの おおきな じゅうもうに とどけよう。"},
					{"at": 15.0, "text": "みどりの ぜんだまきんにも さわって おうえんしてね。やじるしが おしえてくれるよ。"},
				],
				"missions": [
					{"type": "collect", "target": "nutrient", "count": 6, "text": "えいようを あつめよう"},
					{"type": "deliver", "target": "villus", "count": 6, "text": "えいようを じゅうもうに とどけよう"},
					{"type": "cheer", "target": "zendama", "count": 3, "text": "ぜんだまきんを おうえんしよう", "done_say": "ぜんだまきんが げんきに なった！"},
					{"type": "reach", "text": "ちょうの おくの ゴールへ いこう"},
				],
				"goal_say": "やったね！ おなかの なかが げんきに なってきた。おくの ゴールへ いこう！",
				"clear_say": "おなかの なかが げんきに なった！",
				"after": {"banner": "ピコッと はっけん！", "lines": [
					{"who": "pico", "text": "わるかったのは い（胃）じゃなくて、その おくの ちょう（腸）だったね。\nあくだまきんが ふえて、おなかの ちょうしが わるくなっていたんだ。"},
				]},
			},
		],
		"karte": {
			"thanks": "おなかが いたくなくなってきた！ ありがとう！ やさいも たべてみるね。",
			"exit": "かえりは…… うんちと いっしょに ぽとん！ ちゃんと あらうから だいじょうぶ。",
			"what": "ちょう（腸）で あくだまきんが ふえて、おなかの ちょうしが わるくなっていた。い（胃）は げんき だった。",
			"why": "あまい もの ばかりで、やさいが たりなかった。",
			"next": "やさいと ヨーグルトも たべよう。おなかが すごく いたい ときや ずっと いたい ときは、すぐ おとなに いおう。",
		},
		"quiz": {"q": "おなかが いたい とき、わるい ところは いつも い（胃）？", "choices": ["ちがう ところの ことも ある", "かならず い（胃）", "かならず は（歯）"], "answer": 0, "explain": "いたい ところと わるい ところは ちがう ことが あるよ。だから きめつけないで、じゅんばんに しらべるんだ。"},
	},
]


func get_episode(id: String) -> Dictionary:
	for e in EPISODES:
		if e["id"] == id:
			return e
	push_error("unknown episode: %s" % id)
	return {}


func ids() -> Array[String]:
	var out: Array[String] = []
	for e in EPISODES:
		out.append(e["id"])
	return out


func next_id(id: String) -> String:
	var a := ids()
	var i := a.find(id)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else ""


func scene_count(id: String) -> int:
	for e in EPISODES:
		if e["id"] == id:
			return e["scenes"].size()
	return 0


## どれかの 話が 使う 場所（はじめて 出てくる 順）。ずかんが 使う
func used_places() -> Array[String]:
	var out: Array[String] = []
	for e in EPISODES:
		for sc in e["scenes"]:
			if not out.has(sc["place"]):
				out.append(sc["place"])
	return out


## 話す 人の 名前と 色（"pico" か PATIENTS の キー）
func speaker(who: String) -> Dictionary:
	return PICO if who == "pico" else PATIENTS.get(who, PICO)


## カルテえらびに 出す ひとこと：患者が 話す 最初の ページ（無ければ 1 ページ目）
func select_line(ep: Dictionary) -> Dictionary:
	for l in ep["consult"]:
		if l["who"] == ep["patient"]:
			return l
	return ep["consult"][0]


## パターンの 記号の 配列（"A・C" → ["A", "C"]）
func patterns(ep: Dictionary) -> PackedStringArray:
	return String(ep["pattern"]).split("・", false)


## よそうの えらびの 表示名：label が あれば それ、無ければ 場所の「なまえ（漢字）」
func place_label(choice: Dictionary) -> String:
	if choice.has("label"):
		return choice["label"]
	if StageDB.stage_ids().has(choice["place"]):
		var s := StageDB.get_stage(choice["place"])
		return "%s（%s）" % [s["name"], s["kanji"]]
	return ""


## さいしょの よそう（place）が「あたり」（hit: true の えらび）だったか
func guess_is_hit(ep: Dictionary, first_guess: String) -> bool:
	for c in ep.get("guess", {}).get("choices", []):
		if c["place"] == first_guess:
			return c.get("hit", false)
	return false


## あとの はなしの ページ：さいしょの よそうが あたりで lines_hit が あれば それ
func after_lines(ep: Dictionary, i: int, first_guess: String) -> Array:
	var a: Dictionary = ep["scenes"][i].get("after", {})
	if a.has("lines_hit") and guess_is_hit(ep, first_guess):
		return a["lines_hit"]
	return a.get("lines", [])


## 場面 i を Level.setup() に わたす 辞書に する：場所の 辞書の 写し ＋ 場面の 上書き。
## "id" は 場所の id の まま（カードの キー・挿絵の 名前・しょくどうの なみ が そのまま 動く）。
func scene_stage(ep: Dictionary, i: int) -> Dictionary:
	var sc: Dictionary = ep["scenes"][i]
	var st: Dictionary = StageDB.get_stage(sc["place"]).duplicate(true)   # const は 読み取り専用。かならず 写しに 書く
	for k in sc.keys():
		if k != "place" and k != "after":
			st[k] = sc[k]
	st["ep"] = ep["id"]
	st["scene"] = i
	return st


## ずかんで 読みかえす カルテ（CardPopup が "karte" を 見て カルテの 紙を 出す）
func karte_card(ep: Dictionary) -> Dictionary:
	return {"tag": "カルテ %d" % ep["no"], "title": ep["title"], "karte": ep["id"]}


## （ ）の 外に ある 漢字を 1 文字 返す（無ければ ""）
static func kanji_outside_paren(text: String) -> String:
	var depth := 0
	for i in text.length():
		var ch := text[i]
		if ch == "（":
			depth += 1
		elif ch == "）":
			depth = maxi(depth - 1, 0)
		elif depth == 0:
			var u := text.unicode_at(i)
			if (u >= 0x4E00 and u <= 0x9FFF) or u == 0x3005:
				return ch
	return ""


static func _is_kana(u: int) -> bool:
	return (u >= 0x3041 and u <= 0x3096) or (u >= 0x30A1 and u <= 0x30FA) or u == 0x30FC


## 文の きまりの 検査（文の まちがいを 文の 配列で 返す。空なら OK）。テストは 画面に 出た 文にも 使う
static func text_problems(text: String) -> Array[String]:
	var out: Array[String] = []
	var k := kanji_outside_paren(text)
	if k != "":
		out.append("（ ）の 外に 漢字「%s」" % k)
	# わかち書き：かなが 13 字 以上 つづいたら 空白の 入れわすれ
	var run := 0
	for i in text.length():
		run = run + 1 if _is_kana(text.unicode_at(i)) else 0
		if run == 13:
			out.append("かなが 13 字 つづく（わかち書き）：…%s" % text.substr(i - 12, 13))
	# 一文字の 臓器名（い・は・ち）は 漢字を そえる：「いが」「はを」「ちの」の ような 語を さがす
	var words := text.replace("\n", " ").replace("「", " ").replace("」", " ").replace("、", " ").replace("。", " ").replace("！", " ").replace("？", " ").split(" ", false)
	for w in words:
		if w.length() == 2 and w[0] in ["い", "は", "ち"] and w[1] in ["が", "の", "を", "に", "は", "も", "で", "へ", "と", "や"] and not OK_WORDS.has(w):
			out.append("「%s」：一文字の 臓器名は「い（胃）」の ように 書く" % w)
	return out


func _check_text(bad: Array[String], where: String, text: String, max_len: int) -> void:
	if text.strip_edges() == "":
		bad.append("%s: 文が 空" % where)
	if text.length() > max_len:
		bad.append("%s: 長すぎる（%d 字。%d 字まで）" % [where, text.length(), max_len])
	for p in text_problems(text):
		bad.append("%s: %s" % [where, p])


func _check_lines(bad: Array[String], where: String, lines: Array) -> void:
	if lines.size() < 1 or lines.size() > 3:
		bad.append("%s: 1〜3 ページに する（いま %d）" % [where, lines.size()])
	for l in lines:
		if l["who"] != "pico" and not PATIENTS.has(l["who"]):
			bad.append("%s: who「%s」が いない" % [where, l["who"]])
		_check_text(bad, where, l["text"], MAX["line"])


## データの まちがいを 文の 配列で 返す（空なら OK）。tests/smoke.gd が 呼ぶ
func validate() -> Array[String]:
	var bad: Array[String] = []
	_check_lines(bad, "OPENING", OPENING)
	_check_text(bad, "ENDING", ENDING, 200)
	for p in PATIENTS.keys():
		_check_text(bad, "PATIENTS " + p, PATIENTS[p]["name"], 12)
	for p in PATTERNS.keys():
		_check_text(bad, "PATTERNS %s name" % p, PATTERNS[p]["name"], 12)
		_check_text(bad, "PATTERNS %s msg" % p, PATTERNS[p]["msg"], 30)
	# カルテで 行く 場所の ものしりカードと まとめも、同じ 文の きまりで 見る（子どもが 読むので）
	for pid in used_places():
		var st := StageDB.get_stage(pid)
		var cards: Dictionary = st["cards"].duplicate()
		cards["summary"] = st["summary"]
		for key in cards.keys():
			for t in [cards[key]["title"], cards[key]["text"]]:
				for p in text_problems(t):
					bad.append("場所 %s の カード %s: %s" % [pid, key, p])
	var no := 0
	for ep in EPISODES:
		no += 1
		var id: String = ep["id"]
		if id != "ep%02d" % no or int(ep["no"]) != no:
			bad.append("%s: id と no は ep01 から 順番に" % id)
		if not PATIENTS.has(ep["patient"]):
			bad.append("%s: patient が PATIENTS に ない" % id)
		if patterns(ep).size() < 1 or patterns(ep).size() > 2:
			bad.append("%s: pattern は 1〜2 こ（「A・C」の ように 書く）" % id)
		for p in patterns(ep):
			if not PATTERNS.has(p):
				bad.append("%s: pattern「%s」が PATTERNS に ない" % [id, p])
		_check_text(bad, id + " title", ep["title"], MAX["title"])
		_check_lines(bad, id + " consult", ep.get("consult", []))
		if ep.has("guess"):
			var g: Dictionary = ep["guess"]
			var go := 0
			var seen_places: Array = []
			_check_text(bad, id + " guess.q", g["q"], MAX["q"])
			_check_text(bad, id + " guess.depart", g["depart"], MAX["depart"])
			if g["choices"].size() < 2 or g["choices"].size() > 3:
				bad.append("%s: guess.choices は 2〜3 こ" % id)
			for c in g["choices"]:
				if seen_places.has(c["place"]):
					bad.append("%s: guess の 場所「%s」が 2 回 ある" % [id, c["place"]])
				seen_places.append(c["place"])
				if not ORGAN_POS.has(c["place"]):
					bad.append("%s: guess の 場所「%s」が ORGAN_POS に ない" % [id, c["place"]])
				if place_label(c) == "":
					bad.append("%s: guess の 場所「%s」に label が いる" % [id, c["place"]])
				else:
					_check_text(bad, id + " guess.label", place_label(c), MAX["label"])
				_check_text(bad, id + " guess.say", c["say"], MAX["say"])
				if c.get("go", false):
					go += 1
				elif c.get("hit", false):
					bad.append("%s: guess の「%s」は hit なのに go で ない（はずれと 言った あとで あたりと 言う ことに なる）" % [id, c["place"]])
			if go == 0:
				bad.append("%s: guess に go: true の えらびが ない（行き止まりに なる）" % id)
		var n: int = ep["scenes"].size()
		if n < 1 or n > 3:
			bad.append("%s: scenes は 1〜3 こ" % id)
		for i in n:
			var sc: Dictionary = ep["scenes"][i]
			var where := "%s scene %d" % [id, i]
			if not StageDB.stage_ids().has(sc.get("place", "")):
				bad.append("%s: place「%s」が StageDB に ない" % [where, sc.get("place", "")])
				continue
			_check_text(bad, where + " intro", sc.get("intro", ""), MAX["intro"])
			for key in ["goal_say", "clear_say"]:
				if sc.has(key):
					_check_text(bad, where + " " + key, sc[key], MAX[key])
			if not (sc.get("hints") is Array):
				bad.append("%s: hints を 書く（無ければ []。場所の ヒントは 引きつがない）" % where)
			for h in sc.get("hints", []):
				_check_text(bad, where + " hints", h.get("text", ""), MAX["hint"])
				if h.has("text_touch"):
					_check_text(bad, where + " hints", h["text_touch"], MAX["hint"])
				if not h.has("at"):
					bad.append("%s: hints に at が ない" % where)
			if sc.has("arrow") and sc["arrow"] != "nearest":
				bad.append("%s: arrow は \"nearest\" だけ" % where)
			var ms: Array = sc.get("missions", [])
			if ms.is_empty() or ms[ms.size() - 1].get("type", "") != "reach":
				bad.append("%s: missions の さいごは reach に する" % where)
			for m in ms:
				if not MISSION_TYPES.has(m.get("type", "")):
					bad.append("%s: 知らない ミッション type「%s」" % [where, m.get("type", "")])
				_check_text(bad, where + " mission.text", m.get("text", ""), MAX["mission"])
				for t in m.get("each_say", []):
					_check_text(bad, where + " each_say", t, MAX["each_say"])
				if m.has("done_say"):
					_check_text(bad, where + " done_say", m["done_say"], MAX["done_say"])
			var spawn: Dictionary = sc.get("spawn", {})
			for key in spawn.keys():
				if not ["skip", "swap"].has(key):
					bad.append("%s: spawn の 知らない キー「%s」" % [where, key])
			for p in spawn.get("skip", []) + spawn.get("swap", {}).keys():
				if SPAWN_LOCKED.has(String(p).get_slice("_", 0)):
					bad.append("%s: spawn で %s は かえられない" % [where, p])
			if i == n - 1 and not sc.has("after"):
				bad.append("%s: さいごの 場面には after を 書く（原因の 種あかしは ボタンで 進む 画面に）" % where)
			if sc.has("after"):
				_check_text(bad, where + " after.banner", sc["after"].get("banner", "—"), MAX["banner"])
				_check_lines(bad, where + " after", sc["after"].get("lines", []))
				if sc["after"].has("lines_hit"):
					_check_lines(bad, where + " after.lines_hit", sc["after"]["lines_hit"])
		for key in ["what", "why", "next"]:
			_check_text(bad, "%s karte.%s" % [id, key], ep["karte"].get(key, ""), MAX["karte"])
		for key in ["thanks", "exit"]:
			if ep["karte"].has(key):
				_check_text(bad, "%s karte.%s" % [id, key], ep["karte"][key], MAX[key])
		var q: Dictionary = ep["quiz"]
		_check_text(bad, id + " quiz.q", q["q"], MAX["quiz_q"])
		_check_text(bad, id + " quiz.explain", q["explain"], MAX["explain"])
		if q["choices"].size() != 3 or int(q["answer"]) < 0 or int(q["answer"]) > 2:
			bad.append("%s: quiz は 3 たく、answer は 0〜2" % id)
		for c in q["choices"]:
			_check_text(bad, id + " quiz.choices", c, MAX["quiz_choice"])
	return bad
