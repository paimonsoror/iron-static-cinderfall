extends GdUnitTestSuite
## W3-C look switch: names, tier gates, the generated detail texture, the actor materials per look and tier.

const TIERS: Array[int] = [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]
## FNV-1a of the 128 x 128 RGBA8 detail texture (mip 0). A change means the generator changed: update it knowingly.
const DETAIL_CHECKSUM: int = 7203830939633419196


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)
	LookDevStyle.glow_override = -1
	LookDevMat.overrides.clear()


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)
	LookDevStyle.glow_override = -1
	LookDevMat.overrides.clear()


func test_the_shipped_default_is_the_current_look_and_names_round_trip() -> void:
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.CURRENT)
	for look: int in 3:
		assert_int(LookDevStyle.from_name(LookDevStyle.name_of(look))).is_equal(look)
	assert_int(LookDevStyle.from_name("STYLISED_PLUS")).is_equal(LookDevStyle.Look.STYLISED_PLUS)
	assert_int(LookDevStyle.from_name(" Stylised ")).is_equal(LookDevStyle.Look.STYLISED)
	assert_int(LookDevStyle.from_name("nope")).is_equal(-1)
	LookDevStyle.set_current(99)
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.STYLISED_PLUS)
	LookDevStyle.set_current(-4)
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.CURRENT)


func test_debug_flag_parses_the_three_looks() -> void:
	var a: DebugArgs = DebugArgs.parse(PackedStringArray(["--look=stylised_plus", "--zoom=3", "--view=side", "--solo"]))
	assert_int(a.look).is_equal(LookDevStyle.Look.STYLISED_PLUS)
	assert_float(a.zoom).is_equal(3.0)
	assert_str(a.view).is_equal("side")
	assert_bool(a.solo).is_true()
	assert_int(DebugArgs.parse(PackedStringArray(["--look=current"])).look).is_equal(LookDevStyle.Look.CURRENT)
	assert_int(DebugArgs.parse(PackedStringArray(["--look=bogus"])).look).is_equal(-1)
	assert_int(DebugArgs.parse(PackedStringArray()).look).is_equal(-1)
	var split: DebugArgs = DebugArgs.parse(PackedStringArray(["--capture-scene=res://x.tscn --look=stylised --zoom=2.5"]))
	assert_int(split.look).is_equal(LookDevStyle.Look.STYLISED)
	assert_float(split.zoom).is_equal(2.5)


func test_current_look_switches_nothing_on_at_any_tier() -> void:
	for tier: int in TIERS:
		var c: int = LookDevStyle.Look.CURRENT
		assert_bool(LookDevStyle.styled_geometry(c)).is_false()
		assert_bool(LookDevStyle.ramp_enabled(c, tier)).is_false()
		assert_bool(LookDevStyle.rim_enabled(c, tier)).is_false()
		assert_bool(LookDevStyle.wear_enabled(c, tier)).is_false()
		assert_bool(LookDevStyle.detail_enabled(c, tier)).is_false()
		assert_bool(LookDevStyle.glow_enabled(c, tier)).is_false()
		assert_bool(LookDevStyle.muzzle_light_enabled(c, tier)).is_false()
		assert_bool(LookDevStyle.secondary_motion_enabled(c, tier)).is_false()
		assert_float(LookDevStyle.accent_energy(c, tier)).is_equal(1.0)


func test_low_tier_keeps_only_the_baked_vertex_colours() -> void:
	var low: int = VisualQuality.Tier.LOW
	for look: int in [LookDevStyle.Look.STYLISED, LookDevStyle.Look.STYLISED_PLUS]:
		assert_bool(LookDevStyle.styled_geometry(look)).is_true()
		assert_bool(LookDevStyle.ramp_enabled(look, low)).is_false()
		assert_bool(LookDevStyle.rim_enabled(look, low)).is_false()
		assert_bool(LookDevStyle.wear_enabled(look, low)).is_false()
		assert_bool(LookDevStyle.detail_enabled(look, low)).is_false()
		assert_bool(LookDevStyle.glow_enabled(look, low)).is_false()
		assert_bool(LookDevStyle.muzzle_light_enabled(look, low)).is_false()
		assert_float(LookDevStyle.accent_energy(look, low)).is_equal(1.0)


func test_mid_and_high_gates_follow_the_look() -> void:
	var s: int = LookDevStyle.Look.STYLISED
	var p: int = LookDevStyle.Look.STYLISED_PLUS
	for tier: int in [VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		assert_bool(LookDevStyle.ramp_enabled(s, tier)).is_true()
		assert_bool(LookDevStyle.rim_enabled(s, tier)).is_true()
		assert_bool(LookDevStyle.wear_enabled(s, tier)).is_true()
		assert_bool(LookDevStyle.detail_enabled(s, tier)).is_false()  # the texture is a PLUS touch
		assert_bool(LookDevStyle.glow_enabled(s, tier)).is_false()
		assert_bool(LookDevStyle.detail_enabled(p, tier)).is_true()
	assert_bool(LookDevStyle.glow_enabled(p, VisualQuality.Tier.HIGH)).is_true()
	assert_bool(LookDevStyle.muzzle_light_enabled(p, VisualQuality.Tier.HIGH)).is_true()
	assert_bool(LookDevStyle.muzzle_light_enabled(p, VisualQuality.Tier.MID)).is_false()
	assert_bool(LookDevStyle.muzzle_light_enabled(s, VisualQuality.Tier.HIGH)).is_false()
	assert_float(LookDevStyle.accent_energy(p, VisualQuality.Tier.MID)).is_greater(
		LookDevStyle.accent_energy(s, VisualQuality.Tier.MID)
	)
	assert_float(LookDevStyle.rim_strength(p)).is_greater(LookDevStyle.rim_strength(s))


func test_glow_override_is_for_the_cost_measurement_only() -> void:
	var p: int = LookDevStyle.Look.STYLISED_PLUS
	assert_int(DebugArgs.parse(PackedStringArray(["--glow=0"])).glow).is_equal(0)
	assert_int(DebugArgs.parse(PackedStringArray(["--glow=1"])).glow).is_equal(1)
	assert_int(DebugArgs.parse(PackedStringArray(["--glow=x"])).glow).is_equal(-1)
	LookDevStyle.glow_override = 0
	assert_bool(LookDevStyle.glow_enabled(p, VisualQuality.Tier.HIGH)).is_false()
	LookDevStyle.glow_override = 1
	assert_bool(LookDevStyle.glow_enabled(LookDevStyle.Look.CURRENT, VisualQuality.Tier.LOW)).is_true()
	LookDevStyle.glow_override = -1
	assert_bool(LookDevStyle.glow_enabled(LookDevStyle.Look.CURRENT, VisualQuality.Tier.LOW)).is_false()


func test_detail_texture_is_deterministic_tileable_and_has_all_channels() -> void:
	var a: Image = LookDevTex.image()
	var b: Image = LookDevTex.image()
	assert_int(a.get_width()).is_equal(LookDevTex.SIZE)
	assert_int(a.get_format()).is_equal(Image.FORMAT_RGBA8)
	assert_bool(a.has_mipmaps()).is_true()
	assert_bool(a.get_data() == b.get_data()).is_true()
	assert_int(LookDevTex.checksum()).is_equal(LookDevTex.checksum())
	assert_object(LookDevTex.texture()).is_same(LookDevTex.texture())
	var seams: float = 0.0
	var scratches: float = 0.0
	var grime_min: float = 1.0
	var grime_max: float = 0.0
	for y: int in LookDevTex.SIZE:
		for x: int in LookDevTex.SIZE:
			var c: Color = a.get_pixel(x, y)
			seams = maxf(seams, c.r)
			scratches = maxf(scratches, c.g)
			grime_min = minf(grime_min, c.b)
			grime_max = maxf(grime_max, c.b)
			assert_float(c.a).is_equal(1.0)
	assert_float(seams).is_greater(0.8)
	assert_float(scratches).is_greater(0.3)
	assert_float(grime_max - grime_min).is_greater(0.3)


func test_detail_texture_checksum_is_pinned() -> void:
	if DETAIL_CHECKSUM == 0:
		print("DETAIL_CHECKSUM is %d" % LookDevTex.checksum())
	else:
		assert_int(LookDevTex.checksum()).is_equal(DETAIL_CHECKSUM)


func test_materials_are_shared_per_role_look_and_tier_class() -> void:
	var look: int = LookDevStyle.Look.STYLISED_PLUS
	for role: StringName in [&"ceramic", &"gunmetal", &"emit_cyan"]:
		assert_object(LookDevMat.surface(role, look, VisualQuality.Tier.MID)).is_same(
			LookDevMat.surface(role, look, VisualQuality.Tier.HIGH)
		)
	var count: int = LookDevMat.cached_count()
	for i: int in 20:
		var _m: Material = LookDevMat.surface(&"ceramic", look, i % 3)
	assert_int(LookDevMat.cached_count()).is_less_equal(count + 1)
	# roles outside the actor kit and the CURRENT look are the plain palette materials
	assert_object(LookDevMat.surface(&"rubber", look, VisualQuality.Tier.HIGH)).is_same(MatLib.mat(&"rubber"))
	assert_object(LookDevMat.surface(&"ceramic", LookDevStyle.Look.CURRENT, 2)).is_same(MatLib.mat(&"ceramic"))


func test_low_tier_materials_are_standard_vertex_color_materials_without_shader() -> void:
	for look: int in [LookDevStyle.Look.STYLISED, LookDevStyle.Look.STYLISED_PLUS]:
		for role: StringName in [&"ceramic", &"gunmetal"]:
			var m: Material = LookDevMat.surface(role, look, VisualQuality.Tier.LOW)
			assert_bool(m is ShaderMaterial).is_false()
			var std: StandardMaterial3D = m as StandardMaterial3D
			assert_bool(std.vertex_color_use_as_albedo).is_true()
			assert_bool(std.rim_enabled).is_false()
		var accent: StandardMaterial3D = LookDevMat.surface(&"emit_cyan", look, VisualQuality.Tier.LOW) as StandardMaterial3D
		assert_float(accent.emission_energy_multiplier).is_equal(1.0)


func test_mid_and_high_materials_use_the_shader_with_a_cyan_rim_and_the_palette() -> void:
	var tokens: VisualTokens = TestContent.baseline().tokens
	var cyan: Color = tokens.color(&"warden_cyan")
	for tier: int in [VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		var sm: ShaderMaterial = LookDevMat.surface(&"ceramic", LookDevStyle.Look.STYLISED, tier) as ShaderMaterial
		assert_object(sm).is_not_null()
		assert_object(sm.shader).is_not_null()
		assert_that(sm.get_shader_parameter(&"rim_color")).is_equal(cyan)
		assert_float(sm.get_shader_parameter(&"rim_strength")).is_greater(0.0)
		assert_that(sm.get_shader_parameter(&"albedo_tint")).is_equal(tokens.color(&"bone_ceramic"))
		assert_float(sm.get_shader_parameter(&"detail_strength")).is_equal(0.0)
	var plus: ShaderMaterial = LookDevMat.surface(&"gunmetal", LookDevStyle.Look.STYLISED_PLUS, VisualQuality.Tier.HIGH) as ShaderMaterial
	assert_float(plus.get_shader_parameter(&"detail_strength")).is_greater(0.0)
	assert_object(plus.get_shader_parameter(&"detail_tex")).is_same(LookDevTex.texture())
	var accent: StandardMaterial3D = LookDevMat.surface(&"emit_cyan", LookDevStyle.Look.STYLISED_PLUS, VisualQuality.Tier.HIGH) as StandardMaterial3D
	assert_float(accent.emission_energy_multiplier).is_greater(1.0)
	assert_that(accent.emission).is_equal(cyan)


func test_configure_repaints_the_look_materials() -> void:
	var sm: ShaderMaterial = LookDevMat.surface(&"ceramic", LookDevStyle.Look.STYLISED, VisualQuality.Tier.MID) as ShaderMaterial
	var tokens: VisualTokens = TestContent.baseline().tokens
	tokens.palette[&"bone_ceramic"] = Color("#223344")
	MatLib.configure(tokens)
	LookDevMat.refresh()
	assert_that(sm.get_shader_parameter(&"albedo_tint")).is_equal(Color("#223344"))
	MatLib.configure(TestContent.baseline().tokens)
	LookDevMat.refresh()
	assert_that(sm.get_shader_parameter(&"albedo_tint")).is_equal(TestContent.baseline().tokens.color(&"bone_ceramic"))
