shader_type spatial;
// ただよう あわ（つば）。ふちだけ うっすら 見える。
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha = 0.5;

void fragment() {
	float f = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float glint = smoothstep(0.93, 0.99, dot(normalize(NORMAL), normalize(vec3(-0.45, 0.6, 0.66))));
	ALBEDO = tint;
	float near = smoothstep(3.0, 8.0, length(VERTEX));   // カメラの すぐ 前では 消える
	ALPHA = clamp(alpha * (0.10 + 0.9 * pow(f, 2.2)) + glint * 0.7, 0.0, 1.0) * COLOR.a * near;
}
