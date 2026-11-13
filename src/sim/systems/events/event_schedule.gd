class_name EventSchedule
extends RefCounted
## The plan side of EventSystem: what happens when a wave or an act begins, and when a planned world event may start
## its warning (VARIETY_SPEC 7.3, 9.3; CONTENT 6 "Schedule rules"). The plan (RunPlan.waves[].events, a pure function of
## the seed) decides WHAT and WHEN; nothing here rolls an event in reaction to how the run goes. This file only applies the
## published rules that can still say no at the moment of the warning:
##   - mercy (rule 4): a harmful event whose warning would start while the core is below `mercy_core_frac` is cancelled;
##   - no harmful event in waves 1 and 2, and wave 3's event is helpful (rule 2); at most one harmful event per wave in
##     acts I and II, two in act III (rule 3); a boss wave takes boss-safe events only;
##   - never two tool-denying events at once (rule 3): a Static Front waits until no brownout, Low Power or Static Front
##     is in progress (it starts a little later, it is not dropped).
## A cancelled event pushes EVENT_CANCELLED(event, reason) and counts in EventState.cancelled.

const HELPFUL_ONLY_WAVE: int = 3
const NO_HARM_THROUGH_WAVE: int = 2
const HARM_LIMIT_ACTS_I_II: int = 1
const HARM_LIMIT_ACT_III: int = 2
const STATIC_FRONT: StringName = &"static_front"


## A wave starts (PhaseAwaits.begin_wave): the plan cursor and the per-wave counters restart, the Core Vent is charged,
## the drums and charges of a new act are laid, and a modifier that takes the turrets offline starts its clock.
static func begin_wave(world: SimWorld, wave: int) -> void:
	var es: EventState = world.events_state
	es.plan_cursor = 0
	es.used_this_wave.fill(0)
	for def: EventDef in world.content.events:
		if def.who == EventDef.Who.PLAYER and def.params.has(&"charges_per_wave"):
			EventSlots.set_charges(world, def.index, roundi(def.param(&"charges_per_wave")))
	if world.plan == null:
		return
	var pw: PlannedWave = world.plan.wave(wave)
	if pw == null:
		return
	var previous: PlannedWave = world.plan.wave(wave - 1)
	if previous == null or previous.act != pw.act:
		_begin_act(world, pw.act)
	if world.mods.turret_offline_ticks > 0.0:
		es.turret_offline_ticks = maxi(es.turret_offline_ticks, roundi(world.mods.turret_offline_ticks))


## Starts the warning of every planned event of the wave whose time has come (EventSystem.step, in combat).
static func launch_due(world: SimWorld) -> void:
	var es: EventState = world.events_state
	if world.plan == null:
		return
	var pw: PlannedWave = world.plan.wave(world.wave)
	if pw == null:
		return
	var elapsed: int = world.tick - wave_start_tick(world)
	while es.plan_cursor < pw.events.size():
		var planned: PlannedEvent = pw.events[es.plan_cursor]
		var def: EventDef = world.content.events[planned.event_index]
		if elapsed < planned.start_offset or (def.id == STATIC_FRONT and tool_denied(world)):
			break
		es.plan_cursor += 1
		var reason: int = refusal(world, def, pw)
		if reason != Reason.Id.OK:
			es.cancelled += 1
			world.events.push(SimEventKind.Id.EVENT_CANCELLED, def.index, reason)
			continue
		es.used_this_wave[def.index] += 1
		es.last_world_event = def.index
		EventSlots.open(world, def.index)


## Reason.Id.OK when the planned event may start its warning now; else why it is cancelled.
static func refusal(world: SimWorld, def: EventDef, pw: PlannedWave) -> int:
	if pw.is_boss and not def.boss_safe:
		return Reason.Id.WRONG_STATE
	if not def.harmful:
		return Reason.Id.OK
	if world.wave <= NO_HARM_THROUGH_WAVE or world.wave == HELPFUL_ONLY_WAVE:
		return Reason.Id.WRONG_STATE
	var limit: int = HARM_LIMIT_ACT_III if pw.act >= 3 else HARM_LIMIT_ACTS_I_II
	if harmful_this_wave(world) >= limit:
		return Reason.Id.WRONG_STATE
	var frac: float = world.content.run.mercy_core_frac if world.content.run != null else 0.0
	if world.core_hp < frac * world.core_max_hp:
		return Reason.Id.LOCKED_BY_EVENT
	return Reason.Id.OK


## Harmful events whose warning started in the current wave.
static func harmful_this_wave(world: SimWorld) -> int:
	var n: int = 0
	for def: EventDef in world.content.events:
		if def.harmful:
			n += world.events_state.used_this_wave[def.index]
	return n


## True while a tool-denying state is in progress: a Static Front (warning or running), a brownout or Low Power.
static func tool_denied(world: SimWorld) -> bool:
	var es: EventState = world.events_state
	if es.ability_lock_ticks > 0 or es.turret_offline_ticks > 0:
		return true
	for event_index: int in es.a_event:
		if world.content.events[event_index].id == STATIC_FRONT:
			return true
	return false


## The wave is over: world events end now and every timer they set is cleared (the intermission is not part of them).
static func end_of_wave(world: SimWorld) -> void:
	var es: EventState = world.events_state
	if not _dirty(world, es):
		return
	EventSlots.end_world_events(world)
	es.ability_lock_ticks = 0
	es.turret_offline_ticks = 0
	es.turret_rate_ticks = 0
	es.turret_rate_milli = 1000
	es.scrap_mult_ticks = 0
	es.scrap_mult_milli = 1000
	es.brownout_cancelled = 0
	es.squat_ids = PackedInt32Array()


## The tick the current wave began on (RunStats keeps it; 0 when the wave number is out of its range).
static func wave_start_tick(world: SimWorld) -> int:
	if world.wave < 0 or world.wave >= world.stats.wave_start_tick.size():
		return 0
	return world.stats.wave_start_tick[world.wave]


## An act begins: its three drums are laid and the player events earn their per-act charges (not at the very start of
## the run: the starting charges are that).
static func _begin_act(world: SimWorld, act: int) -> void:
	HazardDrums.place(world, act)
	if act <= 1:
		return
	for def: EventDef in world.content.events:
		if def.who != EventDef.Who.PLAYER:
			continue
		var n: float = def.param(&"charges_per_act")
		if def.id == &"deadfall_strike":
			n += world.mods.strike_per_act
		elif def.id == &"freight_call":
			n += world.mods.freight_per_act
		if n >= 1.0:
			EventSlots.grant(world, def.index, roundi(n))


static func _dirty(world: SimWorld, es: EventState) -> bool:
	if es.ability_lock_ticks > 0 or es.turret_offline_ticks > 0 or es.turret_rate_ticks > 0 or es.scrap_mult_ticks > 0:
		return true
	if not es.squat_ids.is_empty():
		return true
	for event_index: int in es.a_event:
		if world.content.events[event_index].who == EventDef.Who.WORLD:
			return true
	return false
