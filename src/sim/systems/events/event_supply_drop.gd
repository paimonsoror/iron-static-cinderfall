class_name EventSupplyDrop
extends RefCounted
## ACCORD DROP (`supply_drop`; VARIETY_SPEC 7.1, CONTENT 6): world, helpful, boss-safe. The warning (3 s) picks one of the
## arena's drop points from the stream `event.place:<wave>` and shows it. Then a crate lands there (SalvageSystem.drop_crate:
## 12 s with no bodied enemy within 2 m secures it, 40 s and it is lost; nothing happens when a crate is already on the
## field) and the `squatters` (3) nearest skitters or rushers that are still on the march divert to stand on it: until the crate
## is secured or lost they walk to it and stand on its ring, so the crate is contested (stunned squatters stop where they
## are, but still contest). The Warden's turret pad covers drop points 1 and 3.
## The diversion is steered after MovementSystem, by HazardSystem.step -> `steer`: the squatter's position of this tick
## is rebuilt from where it stood before the movement step, so the movement system's own step toward the core is undone.
## Rules of every event: no direct damage to the core, the Warden or a turret; a warning before the effect.
## params: squatters, squat_ring_m.


## One stage of this event for the active slot `slot` of EventState (EventSystem.Stage: WARN, START, TICK, FINISH).
static func run(world: SimWorld, slot: int, stage: int) -> void:
	if stage == EventSystem.Stage.WARN:
		_pick(world, slot)
	elif stage == EventSystem.Stage.START:
		_land(world, slot)


## Squatters walk to the crate (called by HazardSystem.step, after the movement step of the same tick).
static func steer(world: SimWorld) -> void:
	var es: EventState = world.events_state
	if es.squat_ids.is_empty():
		return
	var s: SalvageState = world.salvage
	if not s.crate_active or not GameState.is_combat(world.phase):
		es.squat_ids = PackedInt32Array()
		return
	var def: EventDef = world.content.event_def(&"supply_drop")
	var ring: float = def.param(&"squat_ring_m") if def != null else 0.6
	var store: EnemyStore = world.enemies
	var kept: PackedInt32Array = PackedInt32Array()
	for enemy_id: int in es.squat_ids:
		var i: int = store.index_of(enemy_id)
		if i < 0:
			continue
		kept.append(enemy_id)
		if store.stun_ticks[i] > 0:
			continue
		var angle: float = float(kept.size() - 1) * TAU / 3.0
		var tx: float = s.crate_x + ring * cos(angle)
		var tz: float = s.crate_z + ring * sin(angle)
		var from_x: float = store.prev_x[i]
		var from_z: float = store.prev_z[i]
		var dx: float = tx - from_x
		var dz: float = tz - from_z
		var d: float = sqrt(dx * dx + dz * dz)
		var step: float = world.nav.t_step[store.type[i]]
		if d <= step:
			store.x[i] = tx
			store.z[i] = tz
		else:
			store.x[i] = from_x + dx / d * step
			store.z[i] = from_z + dz / d * step
	es.squat_ids = kept


static func _pick(world: SimWorld, slot: int) -> void:
	var points: PackedVector2Array = world.content.arena.drop_points
	if points.is_empty():
		return
	var stream: RandomNumberGenerator = world.rng.stream(StringName("event.place:%d" % world.wave))
	var point: Vector2 = points[stream.randi_range(0, points.size() - 1)]
	world.events_state.a_x[slot] = point.x
	world.events_state.a_z[slot] = point.y


static func _land(world: SimWorld, slot: int) -> void:
	var es: EventState = world.events_state
	var points: PackedVector2Array = world.content.arena.drop_points
	var point: int = -1
	for k: int in points.size():
		if absf(points[k].x - es.a_x[slot]) < 0.001 and absf(points[k].y - es.a_z[slot]) < 0.001:
			point = k
	if point < 0 or not SalvageSystem.drop_crate(world, point, false):
		return
	var def: EventDef = world.content.events[es.a_event[slot]]
	var taken: PackedInt32Array = PackedInt32Array()
	var store: EnemyStore = world.enemies
	es.squat_ids = PackedInt32Array()
	for _n: int in roundi(def.param(&"squatters")):
		var best: int = _nearest_marcher(world, es.a_x[slot], es.a_z[slot], taken)
		if best < 0:
			break
		taken.append(best)
		es.squat_ids.append(store.id[best])


## The skitter or rusher on the march (not in a slot, not taken yet) nearest to (x, z); ties go to the lower id. -1: none.
static func _nearest_marcher(world: SimWorld, x: float, z: float, taken: PackedInt32Array) -> int:
	var store: EnemyStore = world.enemies
	var best: int = -1
	var best_d2: float = INF
	for i: int in store.high_water:
		if store.alive[i] == 0 or taken.has(i) or store.state[i] != EnemyStore.ST_MOVING:
			continue
		if store.type[i] != Ids.EN_SKITTER and store.type[i] != Ids.EN_RUSHER:
			continue
		var dx: float = store.x[i] - x
		var dz: float = store.z[i] - z
		var d2: float = dx * dx + dz * dz
		if d2 < best_d2 or (d2 == best_d2 and store.id[i] < store.id[best]):
			best = i
			best_d2 = d2
	return best
