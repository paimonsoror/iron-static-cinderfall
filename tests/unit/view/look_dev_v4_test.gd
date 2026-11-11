extends GdUnitTestSuite
## W3-C round 4 (Warden v4, the freeze): the helmet reads as a helmet (a wrapping visor band, no mouth slot), the chest is a set
## of layered plates, the bone plates are never cream, the lower body carries mid values, the back panel has depth, the steel
## specular is low, and the hard-surface materials are in the boot warm-up.

const STYLISED: int = LookDevStyle.Look.STYLISED


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


## [positions, normals, tints] of the triangles' vertices of the surfaces whose material is `role`.
func _verts(mesh: ArrayMesh, role: StringName) -> Array:
	var pos: PackedVector3Array = PackedVector3Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	var tint: PackedFloat32Array = PackedFloat32Array()
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s).resource_name != String(role):
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i: int in idx:
			pos.append(v[i])
			nrm.append(n[i])
			tint.append((c[i].r + c[i].g + c[i].b) / 3.0)
	return [pos, nrm, tint]


func test_the_visor_is_a_band_that_wraps_the_helmet() -> void:
	var torso: ArrayMesh = ActorMeshes.warden_part(&"torso", STYLISED)
	var lit: Array = _verts(torso, &"emit_cyan")
	var pos: PackedVector3Array = lit[0]
	var wide: float = 0.0
	var z_centre: float = 0.0
	var z_edge: float = 0.0
	var helmet_y: float = LookDevHead.HC.y
	for p: Vector3 in pos:
		if absf(p.y - helmet_y) > 0.12 or p.z > 0.0:
			continue  # only the front half of the helmet region (the visor, not the fin or the pod)
		wide = maxf(wide, absf(p.x))
		if absf(p.x) < 0.02:
			z_centre = minf(z_centre, p.z)
		if absf(p.x) > 0.15:
			z_edge = minf(z_edge, p.z)
	assert_float(wide).is_greater(0.15)  # it reaches around the sides
	assert_float(z_edge).is_greater(z_centre + 0.06)  # and the ends sit well behind the middle: it follows the curve


func test_there_is_no_mouth_slot_under_the_visor() -> void:
	var dark: Array = _verts(ActorMeshes.warden_part(&"torso", STYLISED), &"gunmetal")
	var pos: PackedVector3Array = dark[0]
	var tint: PackedFloat32Array = dark[2]
	var y: float = LookDevHead.HC.y
	for i: int in pos.size():
		var p: Vector3 = pos[i]
		# the front centre of the lower face: nothing dark (the jaw is a smooth steel ellipsoid, the slits are on its sides)
		if absf(p.x) < 0.06 and p.z < -0.18 and p.y > y - 0.22 and p.y < y - 0.05:
			assert_float(tint[i]).is_greater(0.12)


func test_the_bone_plates_are_off_white_never_cream() -> void:
	var tokens: VisualTokens = TestContent.baseline().tokens
	var base: Color = tokens.color(&"bone_ceramic").srgb_to_linear()
	var tint: Color = LookDevWarden._bone(1.0)
	var lit: Vector3 = Vector3(base.r * tint.r, base.g * tint.g, base.b * tint.b)
	var hi: float = maxf(lit.x, maxf(lit.y, lit.z))
	var lo: float = minf(lit.x, minf(lit.y, lit.z))
	assert_float((hi - lo) / hi).is_less(0.08)  # neutral: red, green and blue within 8 percent
	assert_float(lit.x).is_greater_equal(lit.z * 0.9)


func test_the_lower_body_carries_mid_values_and_only_the_joints_are_dark() -> void:
	assert_float(LookDevWarden.THIGH).is_greater_equal(0.5)
	assert_float(LookDevWarden.CALF).is_greater_equal(0.3)
	assert_float(LookDevWarden.PELVIS).is_greater_equal(0.4)
	assert_float(LookDevWarden.SUIT).is_less(0.2)  # the suit is only the joint gaps now
	var legs: Array = _verts(ActorMeshes.warden_part(&"legs", STYLISED), &"gunmetal")
	var tint: PackedFloat32Array = legs[2]
	var sum: float = 0.0
	for t: float in tint:
		sum += t
	assert_float(sum / float(tint.size())).is_greater(0.2)  # the mean vertex value of the leg steel, AO included: not black posts


func test_the_chest_is_layered_plates_with_a_core_inset_and_the_shoulders_have_straps() -> void:
	var torso: ArrayMesh = ActorMeshes.warden_part(&"torso", STYLISED)
	# plates: many front-facing steel triangles at different depths in front of the chest block
	var steel: Array = _verts(torso, &"gunmetal")
	var pos: PackedVector3Array = steel[0]
	var nrm: PackedVector3Array = steel[1]
	var depths: Dictionary = {}
	for i: int in pos.size():
		if nrm[i].z < -0.9 and pos[i].y > 0.2 and pos[i].y < 0.62 and absf(pos[i].x) < 0.3:
			depths[roundi(pos[i].z * 100.0)] = true
	assert_int(depths.size()).is_greater_equal(3)
	# the core: a cyan hexagon on the chest, in front of its dark ring
	var lit: Array = _verts(torso, &"emit_cyan")
	var lit_pos: PackedVector3Array = lit[0]
	var core_z: float = 0.0
	for p: Vector3 in lit_pos:
		if absf(p.x) < 0.06 and p.y > 0.38 and p.y < 0.48:
			core_z = minf(core_z, p.z)
	assert_float(core_z).is_less(-0.25)
	# straps: two dark thin boxes on the yoke
	var dark_on_yoke: int = 0
	for i: int in pos.size():
		if absf(pos[i].x - 0.14) < 0.03 and absf(pos[i].y - 0.664) < 0.004:
			dark_on_yoke += 1
	assert_int(dark_on_yoke).is_greater(0)


func test_the_back_panel_has_depth_and_a_brighter_core() -> void:
	var pack: ArrayMesh = ActorMeshes.warden_part(&"pack", STYLISED)
	var frame: Array = _verts(pack, &"gunmetal")
	var lit: Array = _verts(pack, &"emit_cyan")
	var f_pos: PackedVector3Array = frame[0]
	var f_nrm: PackedVector3Array = frame[1]
	var l_pos: PackedVector3Array = lit[0]
	var l_nrm: PackedVector3Array = lit[1]
	var l_tint: PackedFloat32Array = lit[2]
	var frame_z: float = -1.0
	var cell_z: float = 1.0
	for i: int in f_pos.size():
		if f_nrm[i].z > 0.9:
			frame_z = maxf(frame_z, f_pos[i].z)
	var dim: float = 1.0
	var bright: float = 0.0
	for j: int in l_pos.size():
		if l_nrm[j].z > 0.9:
			cell_z = minf(cell_z, l_pos[j].z)
			dim = minf(dim, l_tint[j])
			bright = maxf(bright, l_tint[j])
	assert_float(frame_z).is_greater(cell_z + 0.01)  # the cells are sunk behind the frame
	assert_float(bright - dim).is_greater(0.15)  # dim cells, bright cores
	assert_float(bright).is_greater_equal(0.99)


func test_the_steel_specular_is_low_and_the_accent_material_takes_vertex_colour() -> void:
	for tier: int in [VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		var sm: ShaderMaterial = LookDevMat.surface(&"gunmetal", STYLISED, tier) as ShaderMaterial
		assert_float(sm.get_shader_parameter(&"spec_strength")).is_less_equal(0.15)
	var accent: StandardMaterial3D = LookDevMat.surface(&"emit_cyan", STYLISED, VisualQuality.Tier.LOW) as StandardMaterial3D
	assert_bool(accent.vertex_color_use_as_albedo).is_true()  # the panel cells are dimmer than the cores on every tier


func test_the_hard_surface_materials_are_in_the_boot_warm_up() -> void:
	assert_bool(LookDevMat.warm_materials(LookDevStyle.Look.CURRENT).is_empty()).is_true()
	var warm: Array[Material] = LookDevMat.warm_materials(STYLISED)
	assert_int(warm.size()).is_greater_equal(4)  # a shader and a baked variant of two roles, and the accent
	var has_shader: bool = false
	for m: Material in warm:
		has_shader = has_shader or m is ShaderMaterial
	assert_bool(has_shader).is_true()
	var mesh: ArrayMesh = ShaderWarmup.build_mesh([], warm)
	assert_int(ShaderWarmup.material_count(mesh)).is_equal(MatLib.IDS.size() + warm.size())
	var last: Array = mesh.surface_get_arrays(mesh.get_surface_count() - 1)
	assert_bool(last[Mesh.ARRAY_COLOR] != null).is_true()  # the vertex format of the Warden meshes
	var plain: Array = mesh.surface_get_arrays(0)
	assert_bool(plain[Mesh.ARRAY_COLOR] == null).is_true()  # the old quads are unchanged


func test_the_arena_view_starts_in_the_process_wide_look() -> void:
	LookDevStyle.set_current(STYLISED)
	var view: ArenaView = auto_free(ArenaView.new())
	assert_int(view.current_look()).is_equal(STYLISED)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)
	var plain: ArenaView = auto_free(ArenaView.new())
	assert_int(plain.current_look()).is_equal(LookDevStyle.Look.CURRENT)
