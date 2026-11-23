shader_type spatial;
// 場所（ステージ）の 面：つやの ない ねんどの おもちゃの ような 見えかた。
// 色 ＝ 画像（無ければ tint）× 頂点カラー（GLB に 焼きこんだ かげの 倍率）。
// 画像は 世界座標の 3 方向から はる（1 枚 = tile m 四方）。だから GLB を 作りなおさずに 画像を 差しかえられる。
// 使いかたは src/level/stage_look.gd。
render_mode specular_disabled, ambient_light_disabled, cull_back;

uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float tex_amount = 0.0;
uniform float tile = 4.0;
// まわりの 明るさ：上を 向いた 面と 下を 向いた 面で 色を 変える（かげの 中も にごらない）
uniform vec3 hemi_up = vec3(0.6);
uniform vec3 hemi_down = vec3(0.45);
// ふちの やわらかい 明るさ
uniform vec3 rim_color = vec3(1.0, 0.85, 0.85);
uniform float rim = 0.12;
// 光の 受けかた：light_wrap が 大きいほど かげの さかいが やわらかい。light_gain は 明るさの 倍率
uniform float light_gain = 1.0;
uniform float light_wrap = 0.6;
// ミクロごうの ライトなど、たいよう いがいの 光の 倍率（近くの 面が 白く とばない ように）
uniform float lamp_gain = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 base = tint;
	if (tex_amount > 0.0) {
		vec3 w = pow(abs(n), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 p = wpos / tile;
		vec3 c = texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
		base *= mix(vec3(1.0), c, tex_amount);
	}
	base *= COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	vec3 amb = mix(hemi_down, hemi_up, n.y * 0.5 + 0.5);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * (amb + rim_color * rim * fres);
}

void light() {
	float nl = max((dot(NORMAL, LIGHT) + light_wrap) / (1.0 + light_wrap), 0.0);
	DIFFUSE_LIGHT += nl * ATTENUATION * LIGHT_COLOR * (light_gain * (LIGHT_IS_DIRECTIONAL ? 1.0 : lamp_gain) / PI);
}
