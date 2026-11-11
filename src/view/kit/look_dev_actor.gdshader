// Hard-surface actor shading for the stylised looks (W3-C). Mobile-renderer safe: no screen or depth texture, no
// discard, opaque, one light() function. Inputs from the mesh: COLOR.rgb = baked tint * ambient occlusion,
// COLOR.a = edge wear mask (chamfers = 1). Parameters are set per material by LookDevMat; nothing is per instance.
//  - soft lighting ramp: half-lambert through a smoothstep, lightly banded, with a cool tinted shadow side
//  - fresnel rim light in the faction color (cyan), stronger on faces that look up; a warm bounce from the amber pad on
//    the lower, sideways and downward faces; the light color is desaturated so the cyan arena lights do not tint plates
//  - edge wear: chamfers show bare metal; optional generated detail texture (panel seams, scratches, grime)
//  - fill_strength: a headlight toward the game camera, so what the camera sees is not left at the ambient level
//  - value_gain lifts the albedo above what the 8 bit vertex colours can hold (round 3: legibility at the real camera)
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec3 albedo_tint : source_color = vec3(0.8);
uniform float value_gain : hint_range(0.5, 3.0) = 1.0;  // lifts the whole surface value: vertex colours are 8 bit, so a tint can never go above 1
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.5;
uniform float diffuse_gain : hint_range(0.0, 2.0) = 0.85;
uniform float light_sat : hint_range(0.0, 1.0) = 0.15;  // the arena's cyan lights tint plates mint; keep them bone and let the rim carry the cyan
uniform float ramp_soft : hint_range(0.05, 1.0) = 0.55;
uniform float ramp_bands : hint_range(1.0, 6.0) = 3.0;
uniform float band_mix : hint_range(0.0, 1.0) = 0.3;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.03;
uniform vec3 shade_tint : source_color = vec3(0.3, 0.45, 0.95);
uniform vec3 bounce_color : source_color = vec3(1.0, 0.6, 0.28);
uniform float bounce_strength : hint_range(0.0, 3.0) = 0.12;
uniform float bounce_height = 1.3;
uniform vec3 fill_dir = vec3(0.0, 0.866, 0.5);  // toward the game camera (pitch 60 degrees), world space
uniform float fill_strength : hint_range(0.0, 2.0) = 0.0;  // a headlight: faces that look at the camera are lifted (no light node, no extra pass)
uniform vec3 rim_color : source_color = vec3(0.22, 0.79, 0.86);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 3.0) = 0.6;
uniform vec3 wear_color : source_color = vec3(0.8, 0.82, 0.85);
uniform float wear_strength : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.0;
uniform float detail_scale = 2.5;

varying vec3 v_pos;
varying vec3 v_nrm;
varying float v_wy;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	v_wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec4 vc = COLOR;
	vec3 alb = albedo_tint * vc.rgb * value_gain;
	float wear = clamp(vc.a * wear_strength, 0.0, 1.0);
	if (detail_strength > 0.001) {
		vec3 an = abs(v_nrm);
		vec2 uv = v_pos.xy;
		if (an.y > an.x && an.y > an.z) {
			uv = v_pos.xz;
		} else if (an.x > an.z) {
			uv = v_pos.zy;
		}
		vec3 d = texture(detail_tex, uv * detail_scale).rgb;
		alb *= 1.0 - d.r * 0.5 * detail_strength;
		alb *= mix(1.0, 0.7 + 0.3 * d.b, detail_strength);
		wear = clamp(wear + d.g * 0.5 * detail_strength * smoothstep(0.25, 0.9, vc.r), 0.0, 1.0);
	}
	alb = mix(alb, wear_color * (0.5 + 0.5 * vc.r), wear);
	ALBEDO = alb;
	ROUGHNESS = mix(roughness, roughness * 0.45, wear);
	METALLIC = 0.0;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	vec3 nw = mat3(INV_VIEW_MATRIX) * NORMAL;
	float up = 0.35 + 0.65 * clamp(nw.y * 0.5 + 0.5, 0.0, 1.0);
	EMISSION += rim_color * fres * rim_strength * up * clamp(vc.r * 1.3, 0.0, 1.0);
	// camera-side fill: the arena lights come from the front and the sides, so the back and the top that the camera sees would
	// stay at the ambient level; this lifts them in proportion to the albedo (dark parts stay dark, plates come up)
	float cam = clamp(dot(nw, normalize(fill_dir)) * 0.5 + 0.5, 0.0, 1.0);
	EMISSION += alb * fill_strength * cam * cam;
	// warm bounce from the amber pad under the Warden: horizontal and downward faces near the ground
	float bounce = bounce_strength * clamp(0.5 - nw.y * 0.6, 0.0, 1.0) * clamp(1.0 - v_wy / bounce_height, 0.0, 1.0);
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
	SPECULAR_LIGHT += lc * ATTENUATION * spec_strength * pow(ndh, shin) * smoothstep(0.0, 0.3, ndl);  // the same desaturated light: warm sun highlights turned dark parts copper
}
