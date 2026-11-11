extends GdUnitTestSuite
## MatLib: one shared instance per id, colors straight from the palette tokens, no per-instance data.


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)


func _tok(token: StringName) -> Color:
	return TestContent.baseline().tokens.color(token)


func test_mat_returns_the_same_instance_for_the_same_id() -> void:
	for id: StringName in MatLib.IDS:
		assert_object(MatLib.mat(id)).is_same(MatLib.mat(id))
	assert_object(MatLib.mat(&"gunmetal")).is_not_same(MatLib.mat(&"ceramic"))


func test_palette_colors_match_the_tokens() -> void:
	assert_that(MatLib.mat(&"ceramic").albedo_color).is_equal(_tok(&"bone_ceramic"))
	assert_that(MatLib.mat(&"gunmetal").albedo_color).is_equal(_tok(&"gunmetal"))
	assert_that(MatLib.mat(&"hazard").albedo_color).is_equal(_tok(&"core_amber"))
	assert_that(MatLib.mat(&"emit_cyan").albedo_color).is_equal(_tok(&"warden_cyan"))
	assert_that(MatLib.mat(&"emit_amber").albedo_color).is_equal(_tok(&"core_amber"))
	assert_that(MatLib.mat(&"emit_red").albedo_color).is_equal(_tok(&"chorus_red"))
	assert_that(MatLib.mat(&"emit_cyan").emission).is_equal(_tok(&"warden_cyan"))
	# The token hexes themselves are the contract (GDD 12.1).
	assert_that(_tok(&"warden_cyan")).is_equal(Color("#39C9DB"))
	assert_that(_tok(&"core_amber")).is_equal(Color("#F1A34A"))
	assert_that(_tok(&"chorus_red")).is_equal(Color("#D94D4D"))


func test_configure_repaints_existing_instances() -> void:
	var before: StandardMaterial3D = MatLib.mat(&"emit_amber")
	var tokens: VisualTokens = TestContent.baseline().tokens
	tokens.palette[&"core_amber"] = Color("#112233")
	MatLib.configure(tokens)
	assert_object(MatLib.mat(&"emit_amber")).is_same(before)
	assert_that(before.albedo_color).is_equal(Color("#112233"))
	assert_that(MatLib.mat(&"pool_amber").albedo_color.r).is_equal(Color("#112233").r)
	MatLib.configure(TestContent.baseline().tokens)
	assert_that(before.albedo_color).is_equal(_tok(&"core_amber"))


func test_light_pools_are_additive_textured_and_share_one_falloff() -> void:
	var tex: ImageTexture = MatLib.glow_texture()
	assert_object(MatLib.glow_texture()).is_same(tex)
	for id: StringName in [&"pool_amber", &"pool_lamp", &"pool_cyan", &"pool_red"]:
		var m: StandardMaterial3D = MatLib.mat(id)
		assert_int(m.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)
		assert_int(m.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
		assert_object(m.albedo_texture).is_same(tex)
		assert_float(m.albedo_color.a).is_between(0.05, 1.0)
	# Radial falloff: bright in the middle, transparent at the border.
	var img: Image = MatLib.glow_image()
	assert_float(img.get_pixel(32, 32).a).is_greater(0.9)
	assert_float(img.get_pixel(0, 0).a).is_equal(0.0)


func test_every_id_has_a_defined_look_and_unknown_ids_are_magenta() -> void:
	for id: StringName in MatLib.IDS:
		assert_that(MatLib.mat(id).albedo_color).is_not_equal(Color.MAGENTA)
	assert_that(MatLib.mat(&"no_such_material").albedo_color).is_equal(Color.MAGENTA)


func test_emissive_and_additive_materials_are_unshaded_and_need_no_per_instance_data() -> void:
	for id: StringName in [&"emit_cyan", &"emit_amber", &"emit_red", &"flash_white", &"add_cyan", &"add_amber", &"rain"]:
		assert_int(MatLib.mat(id).shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	# Plain StandardMaterial3D everywhere (Mobile renderer, no ShaderMaterial in the shared palette).
	for id: StringName in MatLib.IDS:
		assert_object(MatLib.mat(id)).is_instanceof(StandardMaterial3D)
