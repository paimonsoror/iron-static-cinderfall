extends GdUnitTestSuite
## W3-C round 3 (Warden v3): value and legibility at the real camera, the heavy proportions, the cyan lights that must exist on
## LOW as well, the look-dev flags (`--hide-warden`, `--msaa`, `--fxaa`) and the per-tier anti-aliasing switch.

const STYLISED: int = LookDevStyle.Look.STYLISED
const PLUS: int = LookDevStyle.Look.STYLISED_PLUS


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)
	LookDevStyle.msaa_override = -1
	LookDevStyle.fxaa_override = -1


func after_test() -> void:
	LookDevStyle.msaa_override = -1
	LookDevStyle.fxaa_override = -1


## Area of the emissive triangles of a mesh whose normal points within `cos_min` of `dir`.
func _lit_area(mesh: ArrayMesh, dir: Vector3, cos_min: float) -> float:
	var total: float = 0.0
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s).resource_name != "emit_cyan":
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t: int in range(0, idx.size(), 3):
			if norms[idx[t]].dot(dir) < cos_min:
				continue
			total += 0.5 * (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]]).length()
	return total


func test_the_pack_carries_one_large_cyan_back_panel_in_the_mesh_itself() -> void:
	# the biggest lit shape the camera sees: part of the mesh (an unshaded surface), not of a shader, so it is on LOW too
	var pack: ArrayMesh = ActorMeshes.warden_part(&"pack", STYLISED)
	assert_float(_lit_area(pack, Vector3.BACK, 0.95)).is_greater(0.12)
	assert_float(_lit_area(pack, Vector3.UP, 0.95)).is_greater(0.03)  # and a strip across the top
	var low: StandardMaterial3D = LookDevMat.surface(&"emit_cyan", STYLISED, VisualQuality.Tier.LOW) as StandardMaterial3D
	assert_object(low).is_not_null()
	assert_int(low.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)


func test_there_are_cyan_shoulder_lights_and_a_helmet_top_mark_facing_the_camera() -> void:
	var torso: ArrayMesh = ActorMeshes.warden_part(&"torso", STYLISED)
	# the camera looks from above and behind: up-facing lights on the pauldrons and on the helmet fin
	assert_float(_lit_area(torso, Vector3.UP, 0.9)).is_greater(0.02)
	assert_float(_lit_area(torso, Vector3.FORWARD, 0.9)).is_greater(0.01)  # the visor slot and the power core


func test_accents_stay_below_the_clip_point_in_the_stylised_look() -> void:
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		var c: Color = LookDevMat.accent_color(LookDevStyle.accent_energy(STYLISED, tier))
		assert_float(maxf(c.r, maxf(c.g, c.b))).is_less(250.0 / 255.0)
	assert_float(LookDevStyle.accent_energy(PLUS, VisualQuality.Tier.HIGH)).is_greater(1.0)  # only PLUS goes HDR


func test_the_plate_materials_are_lifted_by_the_value_gain_on_every_tier() -> void:
	var tokens: VisualTokens = TestContent.baseline().tokens
	assert_float(LookDevStyle.value_gain(STYLISED, false)).is_greater(2.0)
	assert_float(LookDevStyle.value_gain(STYLISED, true)).is_less(LookDevStyle.value_gain(STYLISED, false))
	var base: Color = tokens.color(&"gunmetal")
	var low: StandardMaterial3D = LookDevMat.surface(&"gunmetal", STYLISED, VisualQuality.Tier.LOW) as StandardMaterial3D
	assert_float(low.albedo_color.r).is_equal_approx(base.r * LookDevStyle.value_gain(STYLISED, false) * LookDevStyle.LOW_GAIN_SCALE, 0.001)
	for tier: int in [VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		var sm: ShaderMaterial = LookDevMat.surface(&"gunmetal", STYLISED, tier) as ShaderMaterial
		assert_float(sm.get_shader_parameter(&"value_gain")).is_equal(LookDevStyle.value_gain(STYLISED, false))
		assert_float(sm.get_shader_parameter(&"fill_strength")).is_greater(0.0)
		assert_float(sm.get_shader_parameter(&"rim_strength")).is_greater(0.5)  # a thin cyan rim from above


func test_the_shader_has_the_camera_fill_and_the_gain_and_no_copper_specular() -> void:
	var code: String = LookDevMat.shader().code
	assert_bool(code.contains("uniform float value_gain")).is_true()
	assert_bool(code.contains("uniform float fill_strength")).is_true()
	assert_bool(code.contains("SPECULAR_LIGHT += lc")).is_true()  # the desaturated light, so a warm sun cannot tint dark parts


func test_the_figure_is_heavy_a_big_helmet_wide_shoulders_a_wider_right_pauldron() -> void:
	var torso: ArrayMesh = ActorMeshes.warden_part(&"torso", STYLISED)
	var aabb: AABB = torso.get_aabb()
	var height: float = aabb.end.y + HeroMeshes.WARDEN_WAIST_Y
	assert_float(LookDevHead.HS.y / height).is_greater_equal(0.18)  # the helmet is about a fifth of the figure
	assert_float(aabb.size.x / LookDevWarden.WAIST_WIDTH).is_greater_equal(2.0)  # shoulders about twice the waist
	assert_float(aabb.end.x).is_greater(-aabb.position.x)  # right pauldron bigger than the left
	assert_float(height).is_between(1.85, 1.95)  # the same height as before: scale unchanged


func test_the_footprint_stays_inside_the_old_one() -> void:
	var legs: AABB = ActorMeshes.warden_part(&"legs", STYLISED).get_aabb()
	var torso: AABB = ActorMeshes.warden_part(&"torso", STYLISED).get_aabb()
	assert_float(maxf(legs.end.x, -legs.position.x)).is_less(0.5)
	assert_float(maxf(torso.end.x, -torso.position.x)).is_less(0.66)
	assert_float(legs.position.z).is_greater(-0.35)


func test_the_flags_parse() -> void:
	assert_bool(DebugArgs.parse(PackedStringArray(["--hide-warden"])).hide_warden).is_true()
	assert_bool(DebugArgs.parse(PackedStringArray([])).hide_warden).is_false()
	assert_int(DebugArgs.parse(PackedStringArray(["--msaa=4"])).msaa).is_equal(4)
	assert_int(DebugArgs.parse(PackedStringArray(["--msaa=2"])).msaa).is_equal(2)
	assert_int(DebugArgs.parse(PackedStringArray(["--msaa=0"])).msaa).is_equal(0)
	assert_int(DebugArgs.parse(PackedStringArray(["--msaa=3"])).msaa).is_equal(-1)
	assert_int(DebugArgs.parse(PackedStringArray(["--fxaa=1"])).fxaa).is_equal(1)
	assert_int(DebugArgs.parse(PackedStringArray(["--fxaa=x"])).fxaa).is_equal(-1)


func test_anti_aliasing_is_per_tier_and_never_touches_current() -> void:
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		assert_int(LookDevStyle.msaa_samples(LookDevStyle.Look.CURRENT, tier)).is_equal(0)
	assert_int(LookDevStyle.msaa_samples(STYLISED, VisualQuality.Tier.LOW)).is_equal(LookDevStyle.MSAA_LOW)
	assert_int(LookDevStyle.msaa_samples(STYLISED, VisualQuality.Tier.MID)).is_equal(LookDevStyle.MSAA_MID)
	assert_int(LookDevStyle.msaa_samples(STYLISED, VisualQuality.Tier.HIGH)).is_equal(LookDevStyle.MSAA_HIGH)
	LookDevStyle.msaa_override = 4
	assert_int(LookDevStyle.msaa_samples(LookDevStyle.Look.CURRENT, VisualQuality.Tier.LOW)).is_equal(4)


func test_apply_aa_sets_the_viewport_and_switching_back_to_current_restores_it() -> void:
	var vp: SubViewport = auto_free(SubViewport.new())
	LookDevStyle.apply_aa(vp, STYLISED, VisualQuality.Tier.HIGH)
	assert_int(vp.msaa_3d).is_equal(_enum_of(LookDevStyle.MSAA_HIGH))
	LookDevStyle.apply_aa(vp, LookDevStyle.Look.CURRENT, VisualQuality.Tier.HIGH)
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(vp.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	LookDevStyle.fxaa_override = 1
	LookDevStyle.apply_aa(vp, STYLISED, VisualQuality.Tier.MID)
	assert_int(vp.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)


func _enum_of(samples: int) -> int:
	match samples:
		4:
			return Viewport.MSAA_4X
		2:
			return Viewport.MSAA_2X
	return Viewport.MSAA_DISABLED
