class_name PlanPatch
extends RefCounted
## The three directives that change the future of the run plan (VARIETY_SPEC 9.3, CONTENT 3.6): open_gate, chorus_handshake
## and static_pact. RunPlanSystem.patch calls `apply` when one is taken (and RunPlanSystem.build for those a kit gave at
## tick 0). A patch touches the waves after `world.wave` only, draws from the stream `plan.patch:<directive>:<w>` (a
## PlanRng stream, never `world.rng`) and so is a pure function of (seed, directive, wave): the same pick gives the same
## plan. The plan is hashed and saved, so a patch survives a resume.
##
##   open_gate         every group interval of the remaining waves x the directive's `spawn_interval_mul`
##   chorus_handshake  +`extra_elites` elite(s) in every remaining normal wave, in both options (gets a crate per third kill)
##   static_pact       a static_front in every remaining normal wave. Boss waves and the opener are left alone (a boss wave
##                     takes boss-safe events only). A power_surge of that wave goes (the two never overlap), and in acts
##                     I and II so does a harmful event (one harmful event per wave). Its time is drawn like the planned
##                     events: uniformly inside the event window of the wave.

const STATIC_FRONT: StringName = &"static_front"
const POWER_SURGE: StringName = &"power_surge"
const HARMFUL_SINGLE_UNTIL_ACT: int = 2  ## acts I and II allow one harmful event per wave


static func apply(world: SimWorld, directive_index: int) -> void:
	if world.plan == null or directive_index < 0 or directive_index >= world.content.directives.size():
		return
	var def: DirectiveDef = world.content.directives[directive_index]
	match def.id:
		&"open_gate":
			_open_gate(world, def)
		&"chorus_handshake":
			_chorus_handshake(world, def)
		&"static_pact":
			_static_pact(world, def)


## The planned waves after the current one, in order.
static func remaining(world: SimWorld) -> Array[PlannedWave]:
	var out: Array[PlannedWave] = []
	for pw: PlannedWave in world.plan.waves:
		if pw.index > world.wave:
			out.append(pw)
	return out


static func _stream(world: SimWorld, def: DirectiveDef, wave_index: int) -> RandomNumberGenerator:
	return PlanRng.stream(world.config.run_seed, StringName("plan.patch:%s:%d" % [String(def.id), wave_index]))


static func _is_normal(world: SimWorld, pw: PlannedWave) -> bool:
	var slot: WaveSlotDef = world.content.run.wave_slot(pw.index)
	return slot != null and slot.kind == WaveSlotDef.Kind.NORMAL


static func _open_gate(world: SimWorld, def: DirectiveDef) -> void:
	var factor: float = WaveBuilder.stat(def.ops, &"spawn_interval_mul", 1.0)
	if is_equal_approx(factor, 1.0):
		return
	for pw: PlannedWave in remaining(world):
		for o: RouteOption in pw.options:
			for g: SpawnGroupDef in o.groups:
				g.interval_ticks = maxi(1, roundi(float(g.interval_ticks) * factor))


static func _chorus_handshake(world: SimWorld, def: DirectiveDef) -> void:
	var extra: int = roundi(WaveBuilder.stat(def.ops, &"extra_elites", 0.0))
	if extra <= 0:
		return
	for pw: PlannedWave in remaining(world):
		if not _is_normal(world, pw):
			continue
		var stream: RandomNumberGenerator = _stream(world, def, pw.index)
		for o: RouteOption in pw.options:
			for _n: int in extra:
				_add_elite(world, pw, o, stream)


## One more elite in `option`: a random eligible body that is not an elite yet, with affixes rolled like the plan's own.
static func _add_elite(world: SimWorld, pw: PlannedWave, option: RouteOption, stream: RandomNumberGenerator) -> void:
	var cand_group: PackedInt32Array = PackedInt32Array()
	var cand_ordinal: PackedInt32Array = PackedInt32Array()
	for g: int in option.groups.size():
		if not PlanElites.eligible(world.content, option.groups[g].enemy_index, pw.act):
			continue
		for k: int in option.groups[g].count:
			if not _is_elite(option, g, k):
				cand_group.append(g)
				cand_ordinal.append(k)
	if cand_group.is_empty():
		return
	var pick: int = PlanRng.index(stream, cand_group.size())
	var e: PlannedElite = PlannedElite.new()
	e.group = cand_group[pick]
	e.ordinal = cand_ordinal[pick]
	e.affix_mask = PlanElites.roll_affixes(world.content, option.groups[e.group].enemy_index, pw.act, stream)
	var at: int = option.elites.size()
	while at > 0 and (option.elites[at - 1].group > e.group or (option.elites[at - 1].group == e.group and option.elites[at - 1].ordinal > e.ordinal)):
		at -= 1
	option.elites.insert(at, e)


static func _is_elite(option: RouteOption, group: int, ordinal: int) -> bool:
	for e: PlannedElite in option.elites:
		if e.group == group and e.ordinal == ordinal:
			return true
	return false


static func _static_pact(world: SimWorld, def: DirectiveDef) -> void:
	var content: ContentSet = world.content
	var front: int = content.event_index(STATIC_FRONT)
	if front < 0:
		return
	for pw: PlannedWave in remaining(world):
		if not _is_normal(world, pw):
			continue
		var moment: float = PlanRng.unit(_stream(world, def, pw.index))
		var kept: Array[PlannedEvent] = []
		var has_front: bool = false
		for e: PlannedEvent in pw.events:
			var event_def: EventDef = content.events[e.event_index]
			if e.event_index == front:
				has_front = true
			elif event_def.id == POWER_SURGE or (event_def.harmful and pw.act <= HARMFUL_SINGLE_UNTIL_ACT):
				continue
			kept.append(e)
		if has_front:
			pw.events = kept
			continue
		var window: int = content.run.wave_slot(pw.index).window_ticks
		var planned: PlannedEvent = PlannedEvent.new()
		planned.event_index = front
		planned.start_offset = roundi(lerpf(content.run.event_window_min, content.run.event_window_max, moment) * float(window))
		var at: int = kept.size()
		while at > 0 and kept[at - 1].start_offset > planned.start_offset:
			at -= 1
		kept.insert(at, planned)
		pw.events = kept
