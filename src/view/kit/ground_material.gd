class_name GroundMaterial
extends RefCounted
## The yard floor: one big quad with a simple procedural spatial shader (no textures, no render passes).
## Wet charcoal concrete: slab seams and per-slab tone dressed at the decor yaw (GDD 4.2), weathered hazard
## stripes, a dashed rim marking the playable rectangle, soft puddles that read as gloss (lower roughness plus a
## faint reflection of the nearest lights), darker outside the rectangle. Colors come only from the palette tokens.
## The "B-4" stencil is a Label3D in ArenaView, not part of this shader.

const SHADER_CODE: String = """
shader_type spatial;

uniform vec3 c_slab_a : source_color;
uniform vec3 c_slab_b : source_color;
uniform vec3 c_seam : source_color;
uniform vec3 c_puddle : source_color;
uniform vec3 c_hazard : source_color;
uniform vec3 c_amber : source_color;
uniform vec3 c_cyan : source_color;
uniform vec4 play_rect;
uniform vec2 decor_cs;
uniform vec2 core_xy;
uniform vec2 warden_xy;
uniform vec2 pad0_xy;
uniform vec2 pad1_xy;
uniform vec4 stripes[3];
uniform float quality = 1.0;

varying vec3 wpos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = wpos.xz;
	// Decor frame: the world rotated so floor seams and stripes sit at the decor yaw.
	vec2 p = vec2(decor_cs.x * w.x - decor_cs.y * w.y, decor_cs.y * w.x + decor_cs.x * w.y);

	// Slabs with seams.
	vec2 slab = vec2(3.6, 3.0);
	vec2 q = p / slab;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	vec2 d_edge = min(f, 1.0 - f) * slab;
	float seam_d = min(d_edge.x, d_edge.y);
	float aa = max(fwidth(seam_d), 0.002);
	float seam = 1.0 - smoothstep(0.025, 0.025 + aa * 1.4, seam_d);
	float wear = smoothstep(0.0, 0.32, seam_d);

	float tone = hash12(cell);
	vec3 col = mix(c_slab_a, c_slab_b, tone * 0.85);
	float mottle = vnoise(p * 0.9) * 0.5 + vnoise(p * 2.7) * 0.25;
	col *= 0.9 + mottle * 0.2;
	col *= 0.82 + 0.18 * wear;
	col = mix(col, c_seam, seam * 0.75);

	// Puddles: soft, low-frequency, calmer on LOW (one noise sample).
	float n1 = vnoise(p * 0.26 + vec2(3.1, 7.7));
	float n2 = quality > 0.5 ? vnoise(p * 0.71 + vec2(11.7, 2.3)) : n1;
	float pm = smoothstep(0.64, 0.74, n1 * 0.7 + n2 * 0.3);
	pm *= 1.0 - seam * 0.6;
	pm *= smoothstep(3.0, 6.5, length(w - core_xy)) * smoothstep(1.4, 3.0, length(w - warden_xy));
	pm *= mix(0.55, 1.0, smoothstep(-0.5, 2.0, min(min(w.x - play_rect.x, play_rect.z - w.x), min(w.y - play_rect.y, play_rect.w - w.y))));
	col = mix(col, c_puddle, pm * 0.4);

	// Hazard stripes (world rectangles, diagonal paint in the decor frame), weathered.
	for (int i = 0; i < 3; i++) {
		vec4 s = stripes[i];
		vec2 dd = abs(w - s.xy) - s.zw;
		float inside = 1.0 - smoothstep(-0.03, 0.03, max(dd.x, dd.y));
		float paint = step(0.5, fract((p.x + p.y) * 0.85));
		float worn = 0.5 + 0.5 * vnoise(p * 3.3 + vec2(float(i) * 5.0, 1.0));
		vec3 stripe_col = mix(c_seam, c_hazard, paint);
		col = mix(col, stripe_col, inside * worn * 0.8);
	}

	// Playable rectangle: darker outside, dashed amber rim just inside the edge.
	vec2 dmin = w - play_rect.xy;
	vec2 dmax = play_rect.zw - w;
	float edge = min(min(dmin.x, dmax.x), min(dmin.y, dmax.y));
	float inside_rect = smoothstep(-0.12, 0.12, edge);
	col *= mix(0.6, 1.0, inside_rect);
	float along = min(dmin.x, dmax.x) < min(dmin.y, dmax.y) ? w.y : w.x;
	float dash = step(0.38, fract(along * 0.55));
	float rim = (1.0 - smoothstep(0.05, 0.05 + aa * 1.5, abs(edge - 0.2))) * inside_rect;
	col = mix(col, c_hazard, rim * dash * 0.32);

	// Far vignette: the yard fades to darkness well beyond the rectangle.
	float far_d = length((w - vec2(0.4, -2.0)) / vec2(22.0, 30.0));
	col *= 1.0 - 0.5 * smoothstep(0.85, 1.7, far_d);

	// Fake reflections in puddles: amber near the core, cyan near the Warden and pads.
	vec3 refl = vec3(0.0);
	if (quality > 0.5) {
		refl += c_amber * smoothstep(8.0, 0.5, length(w - core_xy)) * 0.7;
		refl += c_cyan * smoothstep(4.2, 0.3, length(w - warden_xy)) * 0.4;
		refl += c_cyan * smoothstep(3.4, 0.3, length(w - pad0_xy)) * 0.45;
		refl += c_cyan * smoothstep(3.4, 0.3, length(w - pad1_xy)) * 0.45;
	}

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.34, pm);
	SPECULAR = mix(0.25, 0.45, pm);
	METALLIC = 0.0;
	EMISSION = pm * (refl * 0.28 + c_cyan * 0.03);
}
"""

static var _shader: Shader = null


## The ground material for this arena, colored from the palette tokens.
static func build(arena: ArenaDef, tokens: VisualTokens) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader
	m.resource_name = "ground"
	var obs: Color = tokens.color(&"obsidian")
	var steel: Color = tokens.color(&"gunmetal")
	m.set_shader_parameter(&"c_slab_a", obs.lerp(steel, 0.17))
	m.set_shader_parameter(&"c_slab_b", obs.lerp(steel, 0.30))
	m.set_shader_parameter(&"c_seam", obs.darkened(0.45))
	m.set_shader_parameter(&"c_puddle", obs.lerp(tokens.color(&"warden_cyan"), 0.2))
	m.set_shader_parameter(&"c_hazard", tokens.color(&"core_amber"))
	m.set_shader_parameter(&"c_amber", tokens.color(&"core_amber"))
	m.set_shader_parameter(&"c_cyan", tokens.color(&"warden_cyan"))
	m.set_shader_parameter(&"play_rect", Vector4(arena.min_x, arena.min_z, arena.max_x, arena.max_z))
	var yaw: float = deg_to_rad(arena.decor_yaw_deg)
	m.set_shader_parameter(&"decor_cs", Vector2(cos(yaw), sin(yaw)))
	m.set_shader_parameter(&"core_xy", Vector2(arena.core_x, arena.core_z))
	m.set_shader_parameter(&"warden_xy", Vector2(arena.warden_x, arena.warden_z))
	var pads: Array[Vector2] = [Vector2(-999.0, -999.0), Vector2(-999.0, -999.0)]
	for i: int in mini(2, arena.turret_pads.size()):
		pads[i] = arena.turret_pads[i]
	m.set_shader_parameter(&"pad0_xy", pads[0])
	m.set_shader_parameter(&"pad1_xy", pads[1])
	m.set_shader_parameter(&"stripes", _stripes(arena))
	set_quality(m, VisualQuality.Tier.MID)
	return m


## Cheaper noise and no fake reflections on LOW.
static func set_quality(m: ShaderMaterial, tier: int) -> void:
	m.set_shader_parameter(&"quality", 0.0 if tier == VisualQuality.Tier.LOW else 1.0)


## Hazard-paint patches as (center_x, center_z, half_x, half_z) in world meters: beside the "B-4" stencil near the
## Warden and a threshold strip at the top spawn edge (just outside the playable rectangle). The third slot is unused.
static func _stripes(arena: ArenaDef) -> PackedVector4Array:
	var out: PackedVector4Array = PackedVector4Array()
	out.append(Vector4(arena.min_x + 5.2, arena.max_z - 0.9, 1.7, 0.32))
	out.append(Vector4((arena.min_x + arena.max_x) * 0.5 + 5.5, arena.min_z - 0.9, 5.4, 0.28))
	out.append(Vector4(-999.0, -999.0, 0.0, 0.0))
	return out
