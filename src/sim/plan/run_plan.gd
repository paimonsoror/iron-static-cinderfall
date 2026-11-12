class_name RunPlan
extends RefCounted
## Everything about a run that is decided at tick 0 (VARIETY_SPEC 9.3): the bosses, both options of every wave, the
## world events, the fuel drum points. Built by RunPlanSystem.build(world) inside SimWorld._init and hashed.
## `chosen` is the one part that changes during the run: the route picked for each wave (PICK_ROUTE).

var boss_ids: PackedInt32Array = PackedInt32Array()  ## enemy index per act
var boss_variant: int = 0  ## index into RunDef.hulk_variants
var waves: Array[PlannedWave] = []  ## index 0 = wave 1
var chosen: PackedInt32Array = PackedInt32Array()  ## per wave: the option index picked (0 until a choice is made)
var drum_points: PackedInt32Array = PackedInt32Array()  ## per act, 3 indices into ArenaDef.drum_points


func wave_count() -> int:
	return waves.size()


## The plan of wave `wave_number` (1-based), or null.
func wave(wave_number: int) -> PlannedWave:
	if wave_number < 1 or wave_number > waves.size():
		return null
	return waves[wave_number - 1]


## The route that spawns in wave `wave_number`: the chosen option, or null when the wave is not planned.
func option(wave_number: int) -> RouteOption:
	var w: PlannedWave = wave(wave_number)
	if w == null or w.options.is_empty():
		return null
	var pick: int = chosen[wave_number - 1] if wave_number - 1 < chosen.size() else 0
	return w.options[clampi(pick, 0, w.options.size() - 1)]


## A plan of the legacy scripted waves: one fixed option per wave, no boss ids, no events. RunPlanSystem returns it
## until V2-A generates real plans, so a run on variety content still plays the tuned 5 waves.
static func from_legacy(legacy_waves: Array[WaveDef]) -> RunPlan:
	var plan: RunPlan = RunPlan.new()
	for wd: WaveDef in legacy_waves:
		var w: PlannedWave = PlannedWave.new()
		w.index = wd.index
		var o: RouteOption = RouteOption.new()
		o.groups = wd.groups.duplicate()
		w.options.append(o)
		plan.waves.append(w)
		plan.chosen.append(0)
	return plan


func hash_into(h: StateHasher) -> void:
	h.put_ints(boss_ids)
	h.put_int(boss_variant)
	h.put_int(waves.size())
	for w: PlannedWave in waves:
		w.hash_into(h)
	h.put_ints(chosen)
	h.put_ints(drum_points)


func to_dict() -> Dictionary:
	var wave_rows: Array = []
	for w: PlannedWave in waves:
		wave_rows.append(w.to_dict())
	return {
		"boss_ids": Array(boss_ids), "boss_variant": boss_variant, "waves": wave_rows, "chosen": Array(chosen),
		"drum_points": Array(drum_points),
	}


static func from_dict(d: Dictionary) -> RunPlan:
	var plan: RunPlan = RunPlan.new()
	plan.boss_ids = SnapUtil.ints(d.get("boss_ids", []))
	plan.boss_variant = roundi(SnapUtil.num(d.get("boss_variant", 0)))
	var wave_rows: Array = d.get("waves", [])
	for row_v: Variant in wave_rows:
		var row: Dictionary = row_v
		plan.waves.append(PlannedWave.from_dict(row))
	plan.chosen = SnapUtil.ints(d.get("chosen", []))
	plan.drum_points = SnapUtil.ints(d.get("drum_points", []))
	return plan
