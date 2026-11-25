extends Node
## カルテ（1 話）の 定義。場所（GLB・マーカー・ものしりカード・既定の ミッション）は StageDB.STAGES。
## ここには 話の 文と、場面（scene）ごとの 上書きだけを 書く。設計は docs/episodes.md。
##
## 書きかたの きまり（tools/build_dashboard.py が 正規表現で 読む）：
## - 各話の 1 行目は「\t\t"id": "epNN", "no": N, "title": "…", "patient": "…", "pattern": "…", "difficulty": N,」
## - 場面は 4 タブで「"place": "<場所 id>",」を 1 行に 単独で 書く（よそうの choices は「{"place": …}」と 波かっこから 始める）
## - PATIENTS と PATTERNS は「"キー": {"name": "…"」の 形で 1 行に 書く（患者の 名前と、げんいんの タイプの 名前を 読む）
## - 文は ひらがな・カタカナ・わかち書き。漢字は「い（胃）」の ように（ ）の 中だけ（validate() が 調べる）
## - 大事な 種あかしは HUD（intro・goal_say など。時間で 消える）に 書かない。after（ボタンで 進む）と karte に 書く
## - からだの 入口と 出口は 話ごとに "enter"／"exit"：{"way": ENTRANCES／EXITS の キー, "say": ピコの ひとこと}（たびの 画面に 出る）
## - 場面は 入口から じゅんばんに。とちゅうの 場所も とばさない（validate_episode() の「みちの きまり」）。
##   とおるだけの 場所は「とおりみち」の 場面："pass": true と "say"（ピコの ひとこと：場所の 名前と しごと）と "hints": []。
##   ミッション・てきは 書かない（Level が ゴールまで いくだけに する）。さいごの 場面は とおりみちに しない

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

## からだの 入口と 出口（カルテの "enter"／"exit" の "way"）。たびの 画面（journey.gd）が ミクロごうを 動かす。
##   at ＝ からだの 出入りする 点（ROUTE_POS か ORGAN_POS の 名前）
##   out ＝ at から からだの 外へ 出る 道（地図の 中の 0〜1。1 を こえて よい。さいごの 点が 外で 止まる 所）
##   name ＝ 画面の ふだ（「いりぐち： …」「でぐち： …」。9 字まで）、go ＝ 動いている あいだの ひとこと（地図の 下。18 字まで）
##   （"name" を 先頭に 書かない：tools/build_dashboard.py が「"キー": {"name"」を 患者と みなす）
##   fx ＝ 出入りの ときの しかけ（water：おみずの つぶ ／ open：おおきく あーん ／ breath：いき ／ spray：おみずが ふきだす ／
##        puff：くうきの かたまり ／ drop：ぽとん ／ spark：きらきら）
const ENTRANCES := {
	"mouth": {"at": "mouth", "out": [Vector2(0.80, 0.21), Vector2(1.0, 0.17)], "fx": "open", "name": "くち（口）", "go": "くち（口）から はいるよ！"},
	"swallow": {"at": "mouth", "out": [Vector2(0.80, 0.21), Vector2(1.0, 0.17)], "fx": "water", "name": "おみずに のって", "go": "おみずに のって くち（口）へ！"},
	"nose": {"at": "nose", "out": [Vector2(0.84, 0.13), Vector2(1.0, 0.09)], "fx": "breath", "name": "はな（鼻）", "go": "いきと いっしょに すいこまれる！"},
	"wound": {"at": "knee", "out": [Vector2(0.80, 0.84), Vector2(1.0, 0.80)], "fx": "spark", "name": "ひざの きずぐち", "go": "ひざの きずぐちから はいるよ！"},
}
const EXITS := {
	"gargle": {"at": "mouth", "out": [Vector2(0.80, 0.21), Vector2(1.0, 0.17)], "fx": "spray", "name": "うがい", "go": "うがいの おみずで そとへ！"},
	"burp": {"at": "mouth", "out": [Vector2(0.80, 0.21), Vector2(1.0, 0.17)], "fx": "puff", "name": "げっぷ", "go": "げっぷに のって そとへ！"},
	"sneeze": {"at": "nose", "out": [Vector2(0.84, 0.13), Vector2(1.0, 0.09)], "fx": "puff", "name": "くしゃみ", "go": "くしゃみで そとへ！"},
	"poop": {"at": "bottom", "out": [Vector2(0.50, 0.80), Vector2(0.72, 0.86), Vector2(1.0, 0.86)], "fx": "drop", "name": "うんち", "go": "うんちと いっしょに ぽとん！"},
	"wound": {"at": "knee", "out": [Vector2(0.80, 0.84), Vector2(1.0, 0.80)], "fx": "spark", "name": "ひざの きずぐち", "go": "きずぐちから そとへ！"},
}
## 道の 点のうち 臓器（ORGAN_POS）で ない もの：のど・おしり・ひざ
const ROUTE_POS := {"throat": Vector2(0.50, 0.27), "bottom": Vector2(0.50, 0.74), "knee": Vector2(0.43, 0.86)}
## からだの 中の 道（となり どうし）。3 つめは あいだに はさむ 点（しょくどうの まがりかど など）。
## 入口から さいしょの 場所へ、さいごの 場所から 出口へは、この 道を いちばん 少ない 数で たどる（route()）
const ROUTE_LINKS := [
	["mouth", "throat"], ["nose", "throat"], ["throat", "esophagus"], ["throat", "lungs", [Vector2(0.42, 0.33)]],
	["esophagus", "stomach", [Vector2(0.50, 0.44)]], ["stomach", "intestine"], ["intestine", "bottom"],
	["knee", "vessel", [Vector2(0.30, 0.72)]], ["vessel", "heart", [Vector2(0.30, 0.36)]], ["heart", "heart2"], ["heart", "lungs"],
	["vessel", "brain", [Vector2(0.24, 0.30), Vector2(0.40, 0.14)]],
]

## はじめて カルテを ひらいた ときだけ、そうだんの 前に 出す（1 ページ）
const OPENING := [
	{"who": "pico", "text": "ようこそ、ミクロしんりょうじょへ！ ぼくは ドクター・ピコ。\nきみは みならいの ちいさな おいしゃさん。からだの なかから みんなを なおしてあげよう！"},
]
const ENDING := "みんな げんきに なった！\nミクロしんりょうじょは きょうも あいているよ。\nまた そうだんに きてね！"

const MISSION_TYPES := ["defeat", "boss", "cheer", "collect", "deliver", "gate", "sequence", "reach"]
const SPAWN_LOCKED := ["player", "goal", "path", "checkpoint"]
## 文の 長さの 上限（字）。HUD に 出る 文（intro〜clear_say）は 短く：子どもは 操縦しながら 読む
const MAX := {
	"title": 24, "line": 90, "q": 40, "say": 70, "label": 20, "enter": 60, "exit": 60,
	"intro": 45, "goal_say": 45, "clear_say": 30, "hint": 60, "mission": 30, "each_say": 30, "done_say": 30,
	"banner": 20, "thanks": 60, "karte": 62, "quiz_q": 40, "quiz_choice": 20, "explain": 90,
	"pass_say": 70, "pass_to": 30,
}
## 1 話の 場面の 数：ぜんぶで MAX_SCENES こまで、とおりみちで ない 場面は MAX_PLAY_SCENES こまで
const MAX_SCENES := 5
const MAX_PLAY_SCENES := 3
## とおりみちの 場面に 書けない キー（Level が ゴールまで いくだけに する。種あかしの after も 無い）
const PASS_FORBIDDEN := ["missions", "after", "spawn", "goal_say"]
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
		},
		"enter": {"way": "mouth", "say": "はなちゃん、おおきく あーん！ ミクロごう、くちから はっしん！"},
		"exit": {"way": "gargle", "say": "のどの おくで まわれみぎ！ ガラガラ うがいの おみずに のって、くちから そとへ ぴゅーっ！"},
		"scenes": [
			{
				"place": "mouth",
				"intro": "おくの は（歯）に むしばきんが いるよ。やっつけよう！",
				"hints": [
					{"at": 1.0, "text": "← → キーで むきを かえるよ。↑ キーで まえへ すすむ。↓ キーで うしろへ。スティックでも できるよ。", "text_touch": "ひだりの まるを ゆびで よこに ひくと むきが かわるよ。うえに ひくと まえへ すすむ。"},
					{"at": 9.0, "text": "スペースキー（Aボタン）で おくすりを だすよ。ミクロごうの まえに いる むしばきんを ねらうんだ！", "text_touch": "みぎの「おくすり」ボタンで うつよ。ミクロごうの まえに いる むしばきんを ねらうんだ！"},
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
				{"place": "stomach", "go": true, "hit": true, "say": "うん、ごはんが たまる い（胃）が あやしいね！\nくち（口）から しょくどう（食道）を とおって いこう。"},
			],
		},
		"enter": {"way": "swallow", "say": "おとうさん、おみずを ひとくち のんで！ ミクロごうは おみずに のって くち（口）へ。"},
		"exit": {"way": "burp", "say": "い（胃）の いりぐちまで もどって、げっぷに のって くちから そとへ ぽーん！"},
		"scenes": [
			{
				"place": "mouth",
				"pass": true,
				"say": "ここは くち（口）。は（歯）で たべものを かみくだいて、だえきで やわらかく する ところだよ。",
				"hints": [],
			},
			{
				"place": "esophagus",
				"intro": "かまずに のみこんだ かたまりが ごろごろ！ よけながら なみに のって くだろう。",
				"lumps": 9,
				"hints": [
					{"at": 1.0, "text": "うしろから くる なみに のると はやく すすめるよ。", "until_ride": true},
					{"at": 9.0, "text": "← → キーで かたまりを よけよう。ぶつかると なみから おちちゃう。", "text_touch": "ひだりの まるを よこに ひいて かたまりを よけよう。ぶつかると なみから おちちゃう。"},
				],
				"missions": [
					{"type": "reach", "text": "かたまりを よけて い（胃）へ いこう"},
				],
				"clear_say": "い（胃）の いりぐちに ついた！",
				"after": {"banner": "てがかり はっけん！", "lines": [
					{"who": "pico", "text": "しょくどうの きんにくは なみの ように じゅんばんに しまって、たべものを い（胃）へ おくるんだ。\nこれを「ぜんどううんどう」と いうよ。"},
					{"who": "pico", "text": "でも おおきな かたまりが いっぱい だったね。\nよく かまないと、い（胃）は たくさん はたらかないと いけないんだ。"},
					{"who": "pico", "text": "たべものは しょくどうに のこらないよ。のみこんで から 10びょう くらいで い（胃）に つくんだ。\nつぎは い（胃）の なかを しらべよう！"},
				]},
			},
			{
				"place": "stomach",
				"intro": "ピロリきんが い（胃）の かべを いじめている！ やっつけよう。",
				"hints": [
					{"at": 1.0, "text": "オレンジいろの いけ（いえき）に はいると ハートが へるよ。きをつけて！"},
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
		},
		"enter": {"way": "swallow", "say": "はなちゃん、おみずを ひとくち のんで！ ミクロごうは おみずに のって くち（口）へ。"},
		"exit": {"way": "poop", "say": "かえりは…… うんちと いっしょに ぽとん！ ちゃんと あらうから だいじょうぶ。"},
		"scenes": [
			{
				"place": "mouth",
				"pass": true,
				"say": "ここは くち（口）。は（歯）で たべものを かみくだいて、だえきで やわらかく する ところだよ。",
				"hints": [],
			},
			{
				"place": "esophagus",
				"pass": true,
				"say": "ここは しょくどう（食道）。かべが なみの ように うごいて、たべものを い（胃）へ おくる くだだよ。",
				"hints": [],
			},
			{
				"place": "stomach",
				"spawn": {"skip": ["enemy_pylori"]},
				"intro": "ここは はなちゃんの い（胃）。かべの さいぼうに さわって しらべよう！",
				"hints": [
					{"at": 1.0, "text": "やじるしの さきに かべの さいぼうが いるよ。さわると しらべられるんだ。"},
					{"at": 14.0, "text": "オレンジいろの いけ（いえき）に はいると ハートが へるよ。きをつけて！"},
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


## 場面 i が とおりみち（とおるだけの 場所）か
static func is_pass(ep: Dictionary, i: int) -> bool:
	var sc: Array = ep.get("scenes", [])
	if i < 0 or i >= sc.size():
		return false
	var v = sc[i].get("pass", false)
	return v is bool and v   # 「== true」で くらべると 文字や 数の ときに 型の エラー（まちがいは validate_episode が 知らせる）


## とおりみちの 場面が 1 つでも あるか（遊びなおしの「とおりみちを とばす」を 出すか）
static func has_pass(ep: Dictionary) -> bool:
	for i in ep.get("scenes", []).size():
		if is_pass(ep, i):
			return true
	return false


## i より あとの 場面の 番号（skip_pass なら とおりみちを とばす）。無ければ -1。i ＝ -1 は 入口
static func next_scene(ep: Dictionary, i: int, skip_pass := false) -> int:
	for k in range(i + 1, ep.get("scenes", []).size()):
		if not (skip_pass and is_pass(ep, k)):
			return k
	return -1


## 場所の 表示名「しょくどう（食道）」
func place_name(place: String) -> String:
	if not StageDB.stage_ids().has(place):
		return ""
	var s := StageDB.get_stage(place)
	return "%s（%s）" % [s["name"], s["kanji"]]


## 1 話で とおる 場所（場面の 順）。みちの ちず・出口の 画面・カルテの「とおった みち」が 使う
func stops(ep: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for sc in ep.get("scenes", []):
		out.append(String(sc.get("place", "")))
	return out


## とおりみちの ミッションの 文（"to"。無ければ つぎの 場所から 作る：「しょくどう（食道）へ すすもう」）
func pass_to(ep: Dictionary, i: int) -> String:
	var sc: Dictionary = ep["scenes"][i]
	if sc.has("to"):
		return sc["to"]
	var n := next_scene(ep, i)
	if n < 0:
		return "ゴールへ すすもう"
	return "%sへ すすもう" % place_name(ep["scenes"][n]["place"])


## みちの ちずの ピコの ひとこと（from ＝ おえた 場面。-1 は 入口。to ＝ つぎの 場面）。
## とおりみちの あとは その say（場所の 名前と しごと）。ふつうの 場面の あとは つぎの 場所の 名前
func hop_say(ep: Dictionary, from: int, to: int) -> String:
	if is_pass(ep, from):
		return ep["scenes"][from].get("say", "")
	var nm := place_name(ep["scenes"][to]["place"]) if to >= 0 and to < ep["scenes"].size() else ""
	if from < 0:
		return "とおりみちは もう しっているね。 いっきに %sまで いこう！" % nm
	return "つぎは %s。\nミクロごう、しゅっぱつ！" % nm


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
	if ep["consult"].is_empty():   # データの まちがい（validate() が 止める）。それでも カルテえらびは 開く
		return {"who": ep["patient"], "text": ""}
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
		if k != "place" and k != "after" and k != "say" and k != "to":
			st[k] = sc[k]
	if is_pass(ep, i):
		# とおりみち：やる ことは ゴールまで いくだけ。HUD は「いま 何を するか」だけ（場所の 説明は みちの ちずの say）
		var to := pass_to(ep, i)
		st["missions"] = [{"type": "reach", "text": to}]
		st["intro"] = sc.get("intro", to + "！")
		st["clear_say"] = sc.get("clear_say", "%sを とおりぬけた！" % place_name(sc["place"]))
		st["hints"] = sc.get("hints", [])
		st.erase("goal_say")
	st["ep"] = ep["id"]
	st["scene"] = i
	return st


## 地図の 点の 位置（0〜1）：臓器（ORGAN_POS）か 道の 点（ROUTE_POS）。無ければ (-1, -1)
func map_point(key: String) -> Vector2:
	return ORGAN_POS.get(key, ROUTE_POS.get(key, Vector2(-1, -1)))


## からだの 中の 道：点 a から 点 b まで（ROUTE_LINKS を いちばん 少ない 数で たどる）。地図の 中の 0〜1 の 点の 列。
## a と b が 同じなら その 1 点。道が 無ければ 空
func route(a: String, b: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var keys := route_keys(a, b)
	for i in keys.size():
		if i > 0:
			out.append_array(_link_mids(keys[i - 1], keys[i]))
		out.append(map_point(keys[i]))
	return out


## からだの 中の 道の 点の 名前：a から b まで（a・b も ふくむ。ROUTE_LINKS を いちばん 少ない 数で たどる）。
## a と b が 同じなら [a]。道が 無ければ 空。みちの きまり（validate_episode）と みちの ちずが 使う
func route_keys(a: String, b: String) -> Array[String]:
	var keys: Array[String] = []
	if map_point(a).x < 0.0 or map_point(b).x < 0.0:
		return keys
	var prev := {a: ""}
	var queue: Array[String] = [a]
	while not queue.is_empty() and not prev.has(b):
		var cur: String = queue.pop_front()
		for l in ROUTE_LINKS:
			for k in 2:
				if l[k] == cur and not prev.has(l[1 - k]):
					prev[l[1 - k]] = cur
					queue.append(l[1 - k])
	if not prev.has(b):
		return keys
	keys.append(b)
	while keys[0] != a:
		keys.push_front(prev[keys[0]])
	return keys


## 1 話の みち 全体：入口の 点 → 場面の 場所 → … → さいごの 場所 の 点の 名前の 列と、地図の 上の 点の 列。
## {"keys": [...], "points": PackedVector2Array, "at": {場面の 番号: points の 中の 番号}, "entry": 入口の 点の 名前}
## 入口から つぎの 場所まで（みちの ちず）は points を at[from]〜at[to] で 切って 使う
func trip(ep: Dictionary) -> Dictionary:
	var way: Dictionary = ENTRANCES.get(ep.get("enter", {}).get("way", ""), {})
	var entry: String = way.get("at", "")
	var scenes: Array = ep.get("scenes", [])
	var keys: Array[String] = []
	var pts := PackedVector2Array()
	var at := {}
	var cur := entry if map_point(entry).x >= 0.0 else (String(scenes[0]["place"]) if not scenes.is_empty() else "")
	if cur != "":
		keys.append(cur)
		pts.append(map_point(cur))
	at[-1] = 0
	for i in scenes.size():
		var place: String = scenes[i].get("place", "")
		var seg := route_keys(cur, place)
		if seg.is_empty():
			# 道が 無い（validate() が 止める）：まっすぐ つなぐ
			if map_point(place).x >= 0.0:
				keys.append(place)
				pts.append(map_point(place))
		else:
			for k in range(1, seg.size()):
				pts.append_array(_link_mids(seg[k - 1], seg[k]))
				keys.append(seg[k])
				pts.append(map_point(seg[k]))
		at[i] = maxi(pts.size() - 1, 0)
		if map_point(place).x >= 0.0:
			cur = place
	return {"keys": keys, "points": pts, "at": at, "entry": entry}


## a から b への 道の あいだの 点（書いた 向きと 逆なら 逆順）
func _link_mids(a: String, b: String) -> PackedVector2Array:
	for l in ROUTE_LINKS:
		if l.size() > 2 and l[0] == a and l[1] == b:
			return PackedVector2Array(l[2])
		if l.size() > 2 and l[0] == b and l[1] == a:
			var r := PackedVector2Array(l[2])
			r.reverse()
			return r
	return PackedVector2Array()


## たびの 画面の 中身。mode ＝ "enter"（外 → 入口 → さいしょの 場所）か "exit"（さいごの 場所 → 出口 → 外）。
## 返す もの：way（ENTRANCES／EXITS の 1 件）、say（ピコの ひとこと）、place（さいしょ／さいごの 場所 id）、
## inside（からだの 中の 道。入口の 点 … 場所 の 順。exit も 同じ 向き）、out（入口の 点から 外への 道。さいごが 外）
func journey(ep: Dictionary, mode: String) -> Dictionary:
	var d: Dictionary = ep.get(mode, {})
	var ways: Dictionary = ENTRANCES if mode == "enter" else EXITS
	var way: Dictionary = ways.get(d.get("way", ""), {})
	var scenes: Array = ep.get("scenes", [])
	var place: String = "" if scenes.is_empty() else scenes[0 if mode == "enter" else scenes.size() - 1].get("place", "")
	var inside := route(way.get("at", ""), place) if not way.is_empty() else PackedVector2Array()
	var out := PackedVector2Array([map_point(way.get("at", ""))])
	out.append_array(PackedVector2Array(way.get("out", [])))
	if inside.is_empty() or out[0].x < 0.0:
		# データの まちがい（validate() が 止める）。それでも 画面が こわれない ように、場所から 横へ 出入りする
		var pp := map_point(place) if map_point(place).x >= 0.0 else Vector2(0.5, 0.5)
		inside = PackedVector2Array([pp])
		out = PackedVector2Array([pp, Vector2(1.0, pp.y)])
	return {"way": way, "say": d.get("say", ""), "place": place, "inside": inside, "out": out}


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
	text = text.replace("\u2060", "")   # 画面の 文には 行の 折りかた用の 見えない しるし（ui_theme.gd の nobreak）が 入って いる
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
		if not StageDB.stage_ids().has(pid):
			continue   # 名前の まちがいは、下の 場面の しらべが「StageDB に ない」と 知らせる
		var st := StageDB.get_stage(pid)
		var cards: Dictionary = st["cards"].duplicate()
		cards["summary"] = st["summary"]
		for key in cards.keys():
			for t in [cards[key]["title"], cards[key]["text"]]:
				for p in text_problems(t):
					bad.append("場所 %s の カード %s: %s" % [pid, key, p])
	_check_ways(bad)
	var no := 0
	for ep in EPISODES:
		no += 1
		bad.append_array(validate_episode(ep, no))
	return bad


## 1 話の データの まちがい（no ＝ 何話目か）。validate() が 全部の 話に 呼ぶ。テストは こわした 写しも わたす
func validate_episode(ep: Dictionary, no: int) -> Array[String]:
	var bad: Array[String] = []
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
		if g.has("depart"):
			bad.append("%s: guess.depart は もう 使わない。しゅっぱつの ひとことは \"enter\": {\"way\": …, \"say\": …} の say に 書く" % id)
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
	var plays := 0
	for i in n:
		if not is_pass(ep, i):
			plays += 1
	if n < 1 or n > MAX_SCENES:
		bad.append("%s: scenes は 1〜%d こ" % [id, MAX_SCENES])
	if plays > MAX_PLAY_SCENES:
		bad.append("%s: とおりみちで ない 場面は %d こまで（いま %d）" % [id, MAX_PLAY_SCENES, plays])
	for i in n:
		var sc: Dictionary = ep["scenes"][i]
		var where := "%s scene %d" % [id, i]
		if not StageDB.stage_ids().has(sc.get("place", "")):
			bad.append("%s: place「%s」が StageDB に ない" % [where, sc.get("place", "")])
			continue
		if sc.has("pass") and not (sc["pass"] is bool):
			bad.append("%s: pass は true か false" % where)
		if is_pass(ep, i):
			# とおりみち：ピコの ひとこと（say）が いる。やる こと（missions など）は 書かない。さいごの 場面には しない
			_check_text(bad, where + " say", sc.get("say", ""), MAX["pass_say"])
			if sc.has("to"):
				_check_text(bad, where + " to", sc["to"], MAX["pass_to"])
			else:
				_check_text(bad, where + " to（つぎの 場所から 作った 文）", pass_to(ep, i), MAX["pass_to"])
			for key in PASS_FORBIDDEN:
				if sc.has(key):
					bad.append("%s: とおりみち（pass）には %s を 書かない" % [where, key])
			if i == n - 1:
				bad.append("%s: さいごの 場面は とおりみち（pass）に しない" % where)
			if not (sc.get("hints") is Array):
				bad.append("%s: hints を 書く（無ければ []。場所の ヒントは 引きつがない）" % where)
			for key in ["intro", "clear_say"]:
				if sc.has(key):
					_check_text(bad, where + " " + key, sc[key], MAX[key])
			continue
		if sc.has("say") or sc.has("to"):
			bad.append("%s: say・to は とおりみち（\"pass\": true）の 場面だけ" % where)
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
		# かたまり（lumps）は なみ（"waves"）の ある 場所（しょくどう）だけ。ほかでは 出ない ので まちがい
		if sc.has("lumps") and not StageDB.get_stage(sc["place"]).has("waves"):
			bad.append("%s: lumps は なみ（waves）の ある 場所だけ（%s には ない）" % [where, sc["place"]])
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
	if ep["karte"].has("thanks"):
		_check_text(bad, "%s karte.thanks" % id, ep["karte"]["thanks"], MAX["thanks"])
	if ep["karte"].has("exit"):
		bad.append("%s: karte.exit は もう 使わない。出口の ひとことは \"exit\": {\"way\": …, \"say\": …} の say に 書く" % id)
	_check_journey(bad, ep, "enter")
	_check_journey(bad, ep, "exit")
	_check_route(bad, ep)
	var q: Dictionary = ep["quiz"]
	_check_text(bad, id + " quiz.q", q["q"], MAX["quiz_q"])
	_check_text(bad, id + " quiz.explain", q["explain"], MAX["explain"])
	if q["choices"].size() != 3 or int(q["answer"]) < 0 or int(q["answer"]) > 2:
		bad.append("%s: quiz は 3 たく、answer は 0〜2" % id)
	for c in q["choices"]:
		_check_text(bad, id + " quiz.choices", c, MAX["quiz_choice"])
	return bad


## 入口（enter）・出口（exit）：かならず 書く。way は ENTRANCES／EXITS の キー。場所への 道が ROUTE_LINKS に ある こと
func _check_journey(bad: Array[String], ep: Dictionary, mode: String) -> void:
	var id: String = ep["id"]
	var ways: Dictionary = ENTRANCES if mode == "enter" else EXITS
	var what := "入口（からだに はいる 所）" if mode == "enter" else "出口（からだから でる 所）"
	var keys := ", ".join(PackedStringArray(ways.keys()))
	if not (ep.get(mode) is Dictionary):
		bad.append("%s: %s が ない。\"%s\": {\"way\": <%s の どれか>, \"say\": ピコの ひとこと} を 書く" % [id, mode, mode, keys])
		return
	var d: Dictionary = ep[mode]
	if not ways.has(d.get("way", "")):
		bad.append("%s: %s.way「%s」を 知らない。%s は %s から えらぶ" % [id, mode, d.get("way", ""), what, keys])
	_check_text(bad, "%s %s.say" % [id, mode], d.get("say", ""), MAX[mode])
	if not ways.has(d.get("way", "")):
		return
	var j := journey(ep, mode)
	if j["place"] != "" and StageDB.stage_ids().has(j["place"]) and j["inside"].is_empty():
		bad.append("%s: %s「%s」と 場所「%s」の あいだの 道が ROUTE_LINKS に ない" % [id, mode, d["way"], j["place"]])


## みちの きまり：入口の 点から さいしょの 場所へ、そこから つぎの 場所へ、と 道（ROUTE_LINKS）を たどる。
## とちゅうの 点で 場所（StageDB に ある もの）は、かならず その じゅんばんで 場面に ある こと（とばさない）。
## 場所で ない 点（のど・ひざ・おしり）は 地図に えがくだけ
func _check_route(bad: Array[String], ep: Dictionary) -> void:
	var id: String = ep["id"]
	var way: Dictionary = ENTRANCES.get(ep.get("enter", {}).get("way", ""), {})
	if way.is_empty():
		return   # 入口の まちがいは _check_journey が 知らせる
	var cur: String = way.get("at", "")
	var missing: Array[String] = []
	var first := true
	for sc in ep.get("scenes", []):
		var place: String = sc.get("place", "")
		if not StageDB.stage_ids().has(place):
			return   # 場所の まちがいは 場面の しらべが 知らせる
		var seg := route_keys(cur, place)
		if seg.is_empty():
			bad.append("%s: 「%s」から「%s」への 道が ROUTE_LINKS に ない" % [id, cur, place])
			return
		# seg の さいごは この 場面の 場所。その 前の 点を 見る（はじめの 区間は 入口の 点も。あとの 区間の 先頭は 前の 場面）
		for k in range(0 if first else 1, seg.size() - 1):
			var key: String = seg[k]
			if StageDB.stage_ids().has(key) and not missing.has(key):
				missing.append(key)
		first = false
		cur = place
	var here := stops(ep)
	for key in missing:
		if here.has(key):
			bad.append("%s: 「%s」の じゅんばんが ちがう（scenes は みちの とおりに ならべる）" % [id, key])
		else:
			bad.append("%s: みちの とちゅうの「%s」が scenes に ない" % [id, key])


## 入口・出口の 一覧の 文と 点（validate() が 1 回 見る）
func _check_ways(bad: Array[String]) -> void:
	for mode in ["enter", "exit"]:
		var ways: Dictionary = ENTRANCES if mode == "enter" else EXITS
		for k in ways.keys():
			var w: Dictionary = ways[k]
			_check_text(bad, "%s %s name" % [mode, k], w.get("name", ""), 9)
			_check_text(bad, "%s %s go" % [mode, k], w.get("go", ""), 18)
			if map_point(w.get("at", "")).x < 0.0:
				bad.append("%s %s: at「%s」が ORGAN_POS にも ROUTE_POS にも ない" % [mode, k, w.get("at", "")])
			if w.get("out", []).is_empty():
				bad.append("%s %s: out（外への 道）が ない" % [mode, k])
