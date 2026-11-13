class_name ArsenalWKit
extends RefCounted
## Helpers for the V4-W suites of tests/unit/sim_arsenal (the other weapons, levels and shot hooks). Built on VarietyCKit:
## worlds come from TestContent.variety() only, enemies are placed with spawn_enemy and the systems are stepped directly.
## Positions are relative to the Warden at (-5.2, 7.0); the enemies come from the +x side.


## A combat world whose slot 0 holds `weapon` at `level` with a full magazine.
static func world(weapon: int, level: int = 1) -> SimWorld:
	var w: SimWorld = VarietyCKit.world()
	arm(w, weapon, level)
	return w


## Slot 0 gets `weapon` at `level`, magazine refilled to what the level allows.
static func arm(w: SimWorld, weapon: int, level: int = 1) -> void:
	ArsenalSystem.give_weapon(w, 0, weapon)
	w.arsenal.slot_level[0] = level
	w.arsenal.slot_magazine[0] = ArsenalSystem.magazine_size_of(w, 0)


## A combat world on content that lists the given directives (an id that the slice data does not have is appended), each
## held with the given stacks; slot 0 holds `weapon` at `level`.
static func directive_world(held: Dictionary[StringName, int], weapon: int = Ids.WP_PISTOL, level: int = 1) -> SimWorld:
	var content: ContentSet = TestContent.variety()
	for id: StringName in held:
		if content.directive(id) == null:
			var d: DirectiveDef = DirectiveDef.new()
			d.id = id
			d.index = content.directives.size()
			d.max_stacks = 3
			content.directives.append(d)
	var w: SimWorld = SimWorld.new(SimConfig.create(content, 1))
	w.phase = GameState.Id.SPAWNING
	for id: StringName in held:
		w.draft.stacks[content.directive_index(id)] = held[id]
	arm(w, weapon, level)
	return w


## An enemy at the Warden's position plus (dx, dz) with a huge hit point pool; `target` makes it the best-ranked enemy.
static func foe(w: SimWorld, type_index: int, dx: float, dz: float, target: bool = false) -> int:
	var i: int = VarietyCKit.place_rel(w, type_index, dx, dz)
	VarietyCKit.tough(w, i)
	if target:
		w.enemies.path_dist[i] = 1.0
	return i


## One tick of the weapon step followed by the hazard step (tick steps 9 and 11).
static func both_tick(w: SimWorld) -> void:
	VarietyCKit.begin_tick(w)
	WeaponSystem.step(w)
	HazardSystem.step(w)


static func run_both(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		both_tick(w)


## Runs weapon and hazard ticks until the Warden has fired `shots` times (at most `limit` ticks). Returns the tick.
static func run_until_shots(w: SimWorld, shots: int, limit: int = 2000) -> int:
	var n: int = 0
	while w.warden.shots_fired < shots and n < limit:
		both_tick(w)
		n += 1
	return w.tick


## The damage dealt by every hit so far, in order (ENEMY_DAMAGED payload f), optionally of one victim id only.
static func dealt(w: SimWorld, victim_id: int = 0) -> Array[float]:
	var out: Array[float] = []
	for e: SimEvent in VarietyCKit.events_of(w, SimEventKind.Id.ENEMY_DAMAGED):
		if victim_id == 0 or e.a == victim_id:
			out.append(e.f)
	return out


## The ticks on which the Warden fired, over `ticks` weapon-and-hazard ticks from now.
static func shot_ticks(w: SimWorld, ticks: int) -> Array[int]:
	var out: Array[int] = []
	for _n: int in ticks:
		var before: int = w.warden.shots_fired
		both_tick(w)
		if w.warden.shots_fired > before:
			out.append(w.tick)
	return out


## Stops the Warden from firing for a long while (hazards and the rest of the tick order keep running).
static func hold_fire(w: SimWorld) -> void:
	w.arsenal.swap_left = 100000
