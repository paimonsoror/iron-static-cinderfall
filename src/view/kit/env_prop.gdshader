shader_type spatial;
// Props of the gritty yard (W3-E): containers, crates, barrels, barriers, lamp posts. The vertex colour is the baked albedo (paint,
// rust, shading; linear) and its alpha is the edge wear. The shader adds what a vertex cannot: vertical grime and rust streaks (one
// fetch of the floor tile in world space), a wet foot (darker and glossier near the ground) and a thin cool rim against the warm
// lamps. Mobile safe: opaque, no discard, no screen or depth texture.

uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 rust_col : source_color = vec3(0.55, 0.28, 0.12);
uniform vec3 wear_col : source_color = vec3(0.62, 0.64, 0.64);
uniform vec3 rim_col : source_color = vec3(0.16, 0.62, 0.72);
uniform float grime_gain = 1.0;
uniform float rim_gain = 0.16;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float wall = 1.0 - abs(wnrm.y);
	vec4 t = texture(grime_tex, vec2((wpos.x + wpos.z) * 0.31, wpos.y * 0.045));
	float streak = smoothstep(0.40, 0.88, t.r * 0.55 + t.a * 0.55);
	float foot = 1.0 - smoothstep(0.0, 1.1, wpos.y);
	base = mix(base, base * rust_col * 3.2, streak * wall * 0.6 * grime_gain);
	base *= 1.0 - 0.32 * foot * grime_gain;
	base = mix(base, wear_col, clamp(COLOR.a, 0.0, 1.0) * 0.5);
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = base;
	ROUGHNESS = clamp(mix(0.78, 0.42, foot * 0.8 + streak * 0.2), 0.3, 1.0);
	SPECULAR = 0.4;
	METALLIC = 0.0;
	EMISSION = rim_col * pow(1.0 - nv, 3.0) * rim_gain * (0.35 + wall);
}
