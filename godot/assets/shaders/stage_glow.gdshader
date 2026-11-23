shader_type spatial;
// 場所の 中の「光る 面」（くちびるの むこうの おそと など）。光・かげ・きりを 受けない。
render_mode unshaded, fog_disabled, cull_back;

uniform vec3 tint : source_color = vec3(1.0);
uniform float energy = 1.0;

void fragment() {
	ALBEDO = tint * COLOR.rgb * energy;
}
