class_name HarnessCensus
extends RefCounted
## What the scorecard needs from a whole run besides the totals of HarnessChecker: the directives that were ever on
## offer (S13), the peak of bodied enemies and of minis per wave (S17), the most blasts in one tick (S17), and the core
## integrity at the end of each act (S1). Fed by SimHarness with each tick's drained events right after the step; reads
## the world, never writes it, needs no random stream.

## Ticks between two counts of the living enemies (a peak is read to within a tenth of a second).
const SAMPLE_PERIOD: int = 4

var peak_bodied: PackedInt32Array = PackedInt32Array()  ## index = wave number (0 = before the first wave)
var peak_minis: PackedInt32Array = PackedInt32Array()
var max_blasts_per_tick: int = 0
## Directive index -> true once the draft showed it in any slot, after any reroll.
var offered: Dictionary[int, bool] = {}
## Core integrity (0..1) when the last wave of act `a + 1` was cleared; -1 while the act was not finished.
var act_end_core: PackedFloat64Array = PackedFloat64Array()

var _last_wave_of_act: PackedInt32Array = PackedInt32Array()


func _init(world: SimWorld) -> void:
	var waves: int = PhaseSystem.wave_count(world)
	peak_bodied.resize(waves + 1)
	peak_minis.resize(waves + 1)
	var acts: int = 1
	if world.plan != null:
		for planned: PlannedWave in world.plan.waves:
			acts = maxi(acts, planned.act)
	act_end_core.resize(acts)
	act_end_core.fill(-1.0)
	_last_wave_of_act.resize(acts)
	if world.plan != null:
		for planned: PlannedWave in world.plan.waves:
			_last_wave_of_act[planned.act - 1] = maxi(_last_wave_of_act[planned.act - 1], planned.index)


func after_step(world: SimWorld, events: Array[SimEvent]) -> void:
	var blasts: int = 0
	for e: SimEvent in events:
		match e.kind:
			SimEventKind.Id.AREA_BLAST:
				blasts += 1
			SimEventKind.Id.DRAFT_OFFERED, SimEventKind.Id.DRAFT_REROLLED:
				_note_offer(world)
			SimEventKind.Id.WAVE_CLEARED:
				_note_clear(world, e.a)
			_:
				pass
	max_blasts_per_tick = maxi(max_blasts_per_tick, blasts)
	if world.tick % SAMPLE_PERIOD == 0 and GameState.is_combat(world.phase):
		_sample_peaks(world)


## The Recovered Data the run would bank: the result formula (Formulas.data_reward), the Data of the `rw_data` route
## rewards on waves that were cleared, and the `data_per_wave` stat of the directives. An estimate for the scorecard's
## S14 comparison; the profile's own grant stays the business of the game layer.
static func data_of(world: SimWorld) -> int:
	var total: float = float(Formulas.data_reward(world.result(), world.waves_completed, world.core_hp, world.content.mission))
	total += world.mods.data_per_wave * float(world.waves_completed)
	if world.plan != null and world.content.run != null:
		for wave_number: int in mini(world.waves_completed, world.stats.route_choices.size() - 1):
			var picked: RouteOption = _picked_option(world, wave_number + 1)
			if picked == null or picked.reward_index < 0 or picked.reward_index >= world.content.run.route_rewards.size():
				continue
			for op: OpDef in world.content.run.route_rewards[picked.reward_index].ops:
				if op.kind == OpDef.Kind.GRANT and op.target == &"data":
					total += op.amount(world.plan.wave(wave_number + 1).act)
	return roundi(total)


## Directive indices ever offered, ascending.
func offered_indices() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for index: int in offered:
		out.append(index)
	out.sort()
	return out


static func _picked_option(world: SimWorld, wave_number: int) -> RouteOption:
	var planned: PlannedWave = world.plan.wave(wave_number)
	var choice: int = world.stats.route_choices[wave_number] if wave_number < world.stats.route_choices.size() else -1
	if planned == null or choice < 0 or choice >= planned.options.size():
		return null
	return planned.options[choice]


func _note_offer(world: SimWorld) -> void:
	for index: int in world.draft.offer:
		if index >= 0:
			offered[index] = true


func _note_clear(world: SimWorld, wave_number: int) -> void:
	for a: int in _last_wave_of_act.size():
		if _last_wave_of_act[a] == wave_number:
			act_end_core[a] = PolicySenses.core_fraction(world)


func _sample_peaks(world: SimWorld) -> void:
	var store: EnemyStore = world.enemies
	var minis: int = 0
	var bodied: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		if (world.ext.flags[i] & EnemyExtState.F_MINI) != 0:
			minis += 1
		else:
			bodied += 1
	var w: int = clampi(world.wave, 0, peak_bodied.size() - 1)
	peak_bodied[w] = maxi(peak_bodied[w], bodied)
	peak_minis[w] = maxi(peak_minis[w], minis)
