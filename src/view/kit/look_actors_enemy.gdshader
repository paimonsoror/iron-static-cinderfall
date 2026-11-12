// Weathered hard-surface shading of the CHORUS machines (W3-D, MID and HIGH). A sibling of look_dev_actor.gdshader (the
// Warden's, untouched): same soft ramp, cool shade side and camera-side fill, plus
//  - warm orange rim and bounce (the fires and the muzzle flashes of the arena) instead of the Warden's cyan rim,
//  - per-pixel grit: dirt speckle, fine scratches, gravity streaks and paint chips from a cheap object-space hash noise (no
//    texture), where the baked vertex alpha (edge wear and chips) turns the plates into bare dark metal and the frame into bright metal,
//  - panel seams: thin dark lines on a jittered object-space grid (plus a per-panel tone), only on faces that are near axis aligned,
//    so flat armour reads as riveted plates at 3x and in the three-quarter view for the price of a few ALU operations.
// Mobile-renderer safe: opaque, no screen or depth texture, no discard, one light(). Per-material uniforms only; nothing is per
// instance (the hit flash is material_override). Inputs: COLOR.rgb = baked tint x AO x grime, COLOR.a = wear and chip mask.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec3 albedo_tint : source_color = vec3(0.8);
uniform float value_gain : hint_range(0.5, 4.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.1;
uniform float diffuse_gain : hint_range(0.0, 2.0) = 0.85;
uniform float light_sat : hint_range(0.0, 1.0) = 0.25;
uniform float ramp_soft : hint_range(0.05, 1.0) = 0.55;
uniform float ramp_bands : hint_range(1.0, 6.0) = 3.0;
uniform float band_mix : hint_range(0.0, 1.0) = 0.3;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.05;
uniform vec3 shade_tint : source_color = vec3(0.32, 0.4, 0.8);
uniform vec3 bounce_color : source_color = vec3(1.0, 0.55, 0.2);
uniform float bounce_strength : hint_range(0.0, 3.0) = 0.4;
uniform float bounce_height = 2.2;
uniform vec3 fill_dir = vec3(0.0, 0.866, 0.5);
uniform float fill_strength : hint_range(0.0, 2.0) = 0.5;
uniform vec3 rim_color : source_color = vec3(0.98, 0.52, 0.2);
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
uniform float rim_strength : hint_range(0.0, 3.0) = 0.7;
uniform vec3 wear_color : source_color = vec3(0.12, 0.12, 0.13);
uniform float wear_strength : hint_range(0.0, 1.0) = 0.8;
uniform float grit_strength : hint_range(0.0, 1.0) = 0.6;
uniform float grit_scale = 11.0;
uniform float streak_strength : hint_range(0.0, 1.0) = 0.5;
uniform float panel_strength : hint_range(0.0, 1.0) = 0.5;
uniform float panel_scale = 2.3;
uniform float panel_tone : hint_range(0.0, 0.5) = 0.12;

varying vec3 v_pos;
varying vec3 v_nrm;
varying float v_wy;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash31(i), hash31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	v_wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec4 vc = COLOR;
	vec3 alb = albedo_tint * vc.rgb * value_gain;
	float wear = clamp(vc.a * wear_strength, 0.0, 1.0);
	if (grit_strength > 0.001) {
		float n = vnoise(v_pos * grit_scale);
		float fine = vnoise(v_pos * grit_scale * 3.1 + 7.3);
		float speck = smoothstep(0.62, 0.86, n * 0.6 + fine * 0.4);
		float scratch = smoothstep(0.9, 0.97, vnoise(vec3(v_pos.x * 1.5 + v_pos.z * 0.8, v_pos.y * 38.0, v_pos.z * 1.5 - v_pos.x * 0.6) * 4.0 + 3.1));
		float drip = smoothstep(0.5, 0.88, vnoise(vec3(v_pos.x * 15.0, v_pos.y * 1.7, v_pos.z * 15.0) + 11.0));
		float low = 1.0 - clamp(v_pos.y / bounce_height, 0.0, 1.0);
		alb *= 1.0 - grit_strength * (0.45 * speck + 0.2 * (1.0 - n));
		alb *= 1.0 - streak_strength * drip * (0.35 + 0.65 * low) * 0.6;
		wear = clamp(wear + grit_strength * (0.55 * scratch + 0.35 * speck * smoothstep(0.3, 0.8, vc.r)), 0.0, 1.0);
	}
	vec3 an = abs(v_nrm);
	float flat_face = smoothstep(0.72, 0.9, max(an.x, max(an.y, an.z)));
	if (panel_strength > 0.001 && flat_face > 0.001) {
		vec2 pc = v_pos.xy;
		if (an.y > an.x && an.y > an.z) {
			pc = v_pos.xz;
		} else if (an.x > an.z) {
			pc = v_pos.zy;
		}
		pc *= panel_scale;
		vec2 cell = floor(pc);
		vec2 fp = fract(pc);
		float edge = min(min(fp.x, 1.0 - fp.x), min(fp.y, 1.0 - fp.y));
		float seam = 1.0 - smoothstep(0.0, 0.06, edge);
		float tone = hash31(vec3(cell, dot(an, vec3(1.0, 2.0, 3.0)))) - 0.5;
		alb *= (1.0 + panel_tone * tone * 2.0) * (1.0 - panel_strength * seam * flat_face * 0.6);
	}
	wear = smoothstep(0.3, 0.7, wear);
	alb = mix(alb, wear_color * (0.45 + 0.55 * vc.r), wear);
	ALBEDO = alb;
	ROUGHNESS = mix(roughness, roughness * 0.5, wear);
	METALLIC = 0.0;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	vec3 nw = mat3(INV_VIEW_MATRIX) * NORMAL;
	float up = 0.35 + 0.65 * clamp(nw.y * 0.5 + 0.5, 0.0, 1.0);
	EMISSION += rim_color * fres * rim_strength * up * clamp(vc.r * 1.3, 0.0, 1.0);
	float cam = clamp(dot(nw, normalize(fill_dir)) * 0.5 + 0.5, 0.0, 1.0);
	EMISSION += alb * fill_strength * cam * cam;
	float bounce = bounce_strength * clamp(0.5 - nw.y * 0.5, 0.0, 1.0) * clamp(1.0 - v_wy / bounce_height, 0.0, 1.0);
	EMISSION += alb * bounce_color * bounce;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	float ramp = smoothstep(0.5 - ramp_soft * 0.5, 0.5 + ramp_soft * 0.5, wrap);
	float band = floor(ramp * ramp_bands + 0.5) / ramp_bands;
	ramp = mix(ramp, band, band_mix);
	vec3 lit = mix(shade_tint * shade_floor, vec3(1.0), ramp);
	vec3 lc = mix(vec3(dot(LIGHT_COLOR, vec3(0.3333))), LIGHT_COLOR, light_sat);
	DIFFUSE_LIGHT += lc * ATTENUATION * lit * diffuse_gain / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, h), 0.0);
	float shin = mix(10.0, 120.0, 1.0 - roughness);
	SPECULAR_LIGHT += lc * ATTENUATION * spec_strength * pow(ndh, shin) * smoothstep(0.0, 0.3, ndl);
}
