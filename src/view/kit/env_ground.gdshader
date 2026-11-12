shader_type spatial;
// The gritty yard floor (W3-E). Dark wet asphalt slabs in the decor frame: seams, a baked 128 px detail tile (grain, cracks,
// blotches; one fetch), repaired patches, painted hazard stripes and a worn dashed rim, puddles, and (wet_on) fake reflections of
// the lit sources as streaks along the view direction. Mobile safe: opaque, no discard, no screen or depth texture.
// Channels of floor_tex: R grain, G cracks, B low-frequency blotches (puddles and stains), A streak breakup.

uniform sampler2D floor_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 c_slab_a : source_color;
uniform vec3 c_slab_b : source_color;
uniform vec3 c_seam : source_color;
uniform vec3 c_hazard : source_color;
uniform vec3 c_puddle : source_color;
uniform vec4 play_rect;
uniform vec2 decor_cs;
uniform vec2 warden_xy;
uniform vec2 core_xy;
uniform vec3 c_sky : source_color = vec3(0.1, 0.14, 0.17);
uniform vec4 stripes[3];
uniform float wet_on = 1.0;
uniform float ripples_on = 0.0;
uniform float crack_gain = 1.0;
uniform float refl_gain = 1.0;
uniform float sheen_gain = 0.9;
uniform float albedo_gain = 1.35;
uniform float puddle_lo = 0.5;
uniform float puddle_hi = 0.66;
uniform vec4 grp = vec4(1.0);          // intensity of the source groups: core, lamps, pad 0, pad 1
uniform vec4 src_pos[12];              // x, z_lo, z_hi (reflection of the lit part along the view), half width
uniform vec4 src_col[12];              // rgb (energy included), group index (0..3, 4 = steady)
uniform int src_n = 0;

varying vec3 wpos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = wpos.xz;
	vec2 p = vec2(decor_cs.x * w.x - decor_cs.y * w.y, decor_cs.y * w.x + decor_cs.x * w.y);

	// Slabs and seams.
	vec2 slab = vec2(3.6, 3.0);
	vec2 q = p / slab;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	vec2 d_edge = min(f, 1.0 - f) * slab;
	float seam_d = min(d_edge.x, d_edge.y);
	float aa = max(fwidth(seam_d), 0.002);
	float seam = 1.0 - smoothstep(0.018, 0.018 + aa * 1.4, seam_d);
	float seam_soft = 1.0 - smoothstep(0.0, 0.16, seam_d);
	vec2 hc = hash22(cell);
	vec2 hd = hash22(cell + 11.0);

	// The detail tile (1.8 x 1.5 m) repeats 2 x 2 inside a slab, flipped and shifted per slab.
	vec2 uv = f * 2.0;
	if (hc.x > 0.5) { uv.x = 2.0 - uv.x; }
	if (hc.y > 0.5) { uv.y = 2.0 - uv.y; }
	uv += hd;
	vec4 t = textureGrad(floor_tex, uv, dFdx(q) * 2.0, dFdy(q) * 2.0);

	float tone = hc.x * hc.y;
	vec3 col = mix(c_slab_a, c_slab_b, tone * 1.6 + hd.x * 0.25);
	col *= 0.78 + (t.r) * 0.5;
	col *= 1.0 - seam_soft * 0.35;

	// Repaired patch on some slabs: a darker, smoother rectangle with a bright edge.
	vec2 pc = 0.28 + 0.44 * hd;
	vec2 ph = 0.10 + 0.12 * hash22(cell + 5.0);
	vec2 pd = abs(f - pc) - ph;
	float pk = max(pd.x, pd.y);
	float has_patch = step(0.78, hc.y);
	float p_in = (1.0 - smoothstep(-0.004, 0.004, pk)) * has_patch;
	float p_edge = (1.0 - smoothstep(0.0, 0.01, abs(pk))) * has_patch;
	col = mix(col, col * 0.62, p_in);
	col += c_slab_b * 0.5 * p_edge;

	// Cracks (some slabs more than others) and blotches.
	float crack = t.g * smoothstep(0.1, 0.55, hd.y) * crack_gain;
	float macro = texture(floor_tex, p * 0.0833 + vec2(0.37, 0.11)).b;
	float blot = t.b * 0.6 + macro * 0.4;
	col *= 1.0 - smoothstep(0.62, 0.85, blot) * 0.35;
	col = mix(col, c_seam, crack * 0.8 + seam * 0.8);

	// Puddles (a wet look on every tier; the reflections follow below on MID and HIGH).
	float pm = smoothstep(puddle_lo, puddle_hi, macro * 0.72 + t.b * 0.28 + (hc.x - 0.5) * 0.10);
	pm *= 1.0 - seam * 0.5;
	pm *= smoothstep(1.4, 3.2, length(w - warden_xy));
	pm *= mix(0.6, 1.0, smoothstep(-0.5, 2.0, min(min(w.x - play_rect.x, play_rect.z - w.x), min(w.y - play_rect.y, play_rect.w - w.y))));
	col = mix(col, col * 0.5 + c_puddle * 0.1, pm);
	crack *= 1.0 - pm * 0.7;

	// Hazard paint (world rectangles, diagonal stripes in the decor frame), worn.
	for (int i = 0; i < 3; i++) {
		vec4 s = stripes[i];
		vec2 dd = abs(w - s.xy) - s.zw;
		float inside = 1.0 - smoothstep(-0.03, 0.03, max(dd.x, dd.y));
		float paint = step(0.5, fract((p.x + p.y) * 0.85));
		float worn = smoothstep(0.12, 0.6, t.r + 0.25 * hash12(floor(p * 9.0)) - crack * 0.5);
		col = mix(col, mix(c_seam, c_hazard * 0.85, paint), inside * worn * 0.85);
	}

	// Playable rectangle: darker outside, worn dashed amber rim inside the edge.
	vec2 dmin = w - play_rect.xy;
	vec2 dmax = play_rect.zw - w;
	float edge = min(min(dmin.x, dmax.x), min(dmin.y, dmax.y));
	float inside_rect = smoothstep(-0.12, 0.12, edge);
	col *= mix(0.62, 1.0, inside_rect);
	float along = min(dmin.x, dmax.x) < min(dmin.y, dmax.y) ? w.y : w.x;
	float dash = step(0.38, fract(along * 0.55));
	float rim = (1.0 - smoothstep(0.05, 0.05 + aa * 1.5, abs(edge - 0.2))) * inside_rect;
	rim *= smoothstep(0.2, 0.55, t.r + 0.2 * hc.x);
	col = mix(col, c_hazard * 0.8, rim * dash * 0.42);

	// Far vignette: the yard fades to darkness toward the edges of the picture.
	float far_d = length((w - vec2(0.4, -2.0)) / vec2(15.0, 21.0));
	col *= 1.0 - 0.55 * smoothstep(0.55, 1.35, far_d);

	// Fake reflections of the lit sources on the wet floor (MID and HIGH): a streak along the view direction.
	vec3 refl = vec3(0.0);
	float wet = mix(0.3, 1.0, pm);
	if (wet_on > 0.5) {
		float brk = 0.6 + 0.6 * texture(floor_tex, vec2(w.x * 0.34, w.y * 0.05)).a;
		for (int i = 0; i < 12; i++) {
			if (i >= src_n) { break; }
			vec4 sp = src_pos[i];
			float dx = abs(w.x - sp.x) / sp.w;
			if (dx > 1.0) { continue; }
			float dz = max(max(sp.y - w.y, w.y - sp.z), 0.0);
			float len = 1.7 + 0.45 * (sp.z - sp.y);
			if (dz > len) { continue; }
			vec4 sc = src_col[i];
			float g = sc.a < 3.5 ? grp[int(sc.a)] : 1.0;
			float k = (1.0 - dx * dx) * (1.0 - smoothstep(0.0, len, dz));
			refl += sc.rgb * (k * k * g);
		}
		vec3 sheen = c_sky * pm * sheen_gain * brk;
		float near_core = smoothstep(8.0, 0.8, length(w - core_xy));
		sheen += src_col[0].rgb * near_core * near_core * 0.22 * (0.4 + 0.8 * brk) * grp.x;
		refl = (refl * brk + sheen) * wet * refl_gain;
		if (ripples_on > 0.5 && pm > 0.05) {
			vec2 rc = w * 0.9;
			vec2 rid = floor(rc);
			vec2 rh = hash22(rid);
			float age = fract(TIME * 0.55 + rh.x * 3.1);
			float rd = length(fract(rc) - 0.2 - 0.6 * rh);
			float ring = (1.0 - smoothstep(0.0, 0.025, abs(rd - age * 0.4))) * (1.0 - age) * (1.0 - age);
			refl += c_sky * 1.2 * ring * pm * step(0.6, rh.y);
		}
	}

	ALBEDO = col * albedo_gain;
	ROUGHNESS = mix(0.9, 0.28, pm * (0.4 + 0.6 * wet_on));
	SPECULAR = mix(0.28, 0.5, pm);
	METALLIC = 0.0;
	EMISSION = refl;
}
