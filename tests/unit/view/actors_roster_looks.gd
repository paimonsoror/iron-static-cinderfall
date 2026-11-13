extends GdUnitTestSuite
## V4-R legibility (VARIETY_SPEC 5.6 rule 5, GDD 6.3: "silhouettes differ in height and footprint first, detail second", size classes far
## apart): every enemy and boss model against every other, rasterised the way the game camera sees it (orthographic, 50 degrees of pitch,
## the machine turned four ways) at its real size, so two machines that a player could confuse fail here. Plus the weapons from above.

const STYLED: int = LookDevStyle.Look.STYLISED
const YAWS: Array[float] = [0.0, 1.5708, 3.1416, 4.7124]
const BOSSES: Array[StringName] = [&"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig", &"siege_hulk"]
const WEAPONS: Array[StringName] = [
	&"pistol", &"smg", &"scattergun", &"assault_rifle", &"hornet_rack", &"lmg", &"slag_mortar", &"cutting_torch", &"arc_projector", &"rail_lance",
]
## The largest picture overlap two different machines may have at their real size, and the largest overlap of their shapes once both
## are drawn at the same area (so a scaled copy of a machine is not a new machine).
const MAX_REAL_IOU: float = 0.7
const MAX_SHAPE_IOU: float = 0.8

var _masks: Dictionary[StringName, Array] = {}


func before() -> void:  # once for the suite: the masks of all 18 models take a few seconds
	MatLib.configure(TestContent.variety().tokens)
	LookActorsStyle.rollout_override = -1
	for id: StringName in Ids.ENEMIES:
		var m: ArrayMesh = ActorMeshes.enemy_look(id, STYLED)
		var per_yaw: Array = []
		for yaw: float in YAWS:
			per_yaw.append(ActorsRosterKit.silhouette(m, yaw))
		_masks[id] = per_yaw


func _worst(a: StringName, b: StringName, shape: bool) -> float:
	var worst: float = 0.0
	var ma: Array = _masks[a]
	var mb: Array = _masks[b]
	for k: int in YAWS.size():
		var pa: PackedByteArray = ma[k]
		var pb: PackedByteArray = mb[k]
		if shape:
			worst = maxf(worst, ActorsRosterKit.iou(ActorsRosterKit.shape(pa), ActorsRosterKit.shape(pb)))
		else:
			worst = maxf(worst, ActorsRosterKit.iou(pa, pb))
	return worst


func test_no_two_machines_share_a_silhouette_at_their_real_sizes() -> void:
	var ids: Array[StringName] = Ids.ENEMIES.duplicate()
	var rows: Array[String] = []
	var top: float = 0.0
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var v: float = _worst(ids[i], ids[j], false)
			top = maxf(top, v)
			if v > 0.35:
				rows.append("%s|%s %.2f" % [ids[i], ids[j], v])
			assert_float(v).override_failure_message("%s and %s overlap %.2f at real size" % [ids[i], ids[j], v]).is_less(MAX_REAL_IOU)
	print("SILHOUETTE real-size worst overlap %.2f; pairs over 0.35: %s" % [top, ", ".join(rows)])


func test_no_two_machines_of_a_size_class_share_a_shape() -> void:
	var classes: Array[Array] = [
		[&"mote", &"shard"],
		[&"skitter", &"borer", &"rusher", &"ward_pylon"],
		[&"hollow_warden", &"burster", &"spitter", &"splitter", &"shieldbearer", &"reclaimer", &"jammer"],
		[&"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig", &"siege_hulk"],
	]
	var top: float = 0.0
	var rows: Array[String] = []
	for group: Array in classes:
		for i: int in group.size():
			for j: int in range(i + 1, group.size()):
				var a: StringName = group[i]
				var b: StringName = group[j]
				var v: float = _worst(a, b, true)
				top = maxf(top, v)
				if v > 0.6:
					rows.append("%s|%s %.2f" % [a, b, v])
				assert_float(v).override_failure_message("%s and %s have the same shape (%.2f)" % [a, b, v]).is_less(MAX_SHAPE_IOU)
	print("SILHOUETTE shape worst overlap %.2f; pairs over 0.6: %s" % [top, ", ".join(rows)])


func test_every_machine_has_a_signature_the_picture_shows() -> void:
	# SPEC 5.1: each specialist carries one tall or wide part (tube, mast, ring, slab, tank, drill): the picture's bounding box says so
	var ext: Dictionary[StringName, Vector2] = {}
	for id: StringName in Ids.ENEMIES:
		var pm: Array = _masks[id]
		var pic: PackedByteArray = pm[1]  # seen from the side
		ext[id] = ActorsRosterKit.extent(pic)
	print("EXTENT side view (m): %s" % ext)
	assert_float(ext[&"reclaimer"].y).is_greater(ext[&"hollow_warden"].y)  # the mast makes it the tallest of the bodies
	assert_float(ext[&"reclaimer"].x / ext[&"reclaimer"].y).is_greater(0.35)  # ...on a low wide crawler
	assert_float(ext[&"shieldbearer"].x).is_greater(ext[&"hollow_warden"].x * 0.7)  # a shield as wide as itself
	assert_float(ext[&"splitter"].x).is_greater_equal(ext[&"hollow_warden"].x * 0.8)  # as wide as a Hollow Warden...
	assert_float(ext[&"splitter"].y).is_less(ext[&"hollow_warden"].y)  # ...and lower
	assert_float(ext[&"borer"].y).is_less(ext[&"skitter"].y * 1.1)  # low
	assert_float(ext[&"ward_pylon"].x).is_less(ext[&"ward_pylon"].y * 0.6)  # a post
	for id: StringName in [&"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig"]:
		assert_float(ext[id].x * ext[id].y).is_greater(ext[&"siege_hulk"].x * ext[&"siege_hulk"].y * 0.5)  # a boss fills the picture like the Hulk


func test_the_weapons_differ_from_above() -> void:
	var plans: Dictionary[StringName, PackedByteArray] = {}
	var lengths: Dictionary[StringName, float] = {}
	for id: StringName in WEAPONS:
		var m: ArrayMesh = ActorMeshes.warden_part(id, STYLED)
		plans[id] = ActorsRosterKit.plan(m)
		lengths[id] = m.get_aabb().size.z
	var top: float = 0.0
	for i: int in WEAPONS.size():
		for j: int in range(i + 1, WEAPONS.size()):
			var v: float = ActorsRosterKit.iou(plans[WEAPONS[i]], plans[WEAPONS[j]])
			top = maxf(top, v)
			assert_float(v).override_failure_message("%s and %s look alike from above (%.2f)" % [WEAPONS[i], WEAPONS[j], v]).is_less(0.78)
	print("WEAPON plan worst overlap %.2f; lengths %s" % [top, lengths])
	# length first (SPEC 3.5): the rail lance is the longest, the LMG next, the scattergun is the shortest of the long guns
	assert_float(lengths[&"rail_lance"]).is_greater(lengths[&"lmg"])
	assert_float(lengths[&"lmg"]).is_greater(lengths[&"assault_rifle"])
	assert_float(lengths[&"assault_rifle"]).is_greater(lengths[&"scattergun"])
	assert_float(lengths[&"scattergun"]).is_greater(lengths[&"pistol"])
	assert_float(lengths[&"rail_lance"]).is_greater_equal(lengths[&"smg"] * 1.6)
