class_name FireLine
extends RefCounted
## Firing kind L (VARIETY_SPEC 3.3): a `charge_ticks` wind-up during which the line is fixed, then every enemy whose body
## is within `area_m` / 2 of the line (the rail lance: 0.25 m) is hit, nearest to the Warden first.
## The line runs from the Warden through the target's position at the moment the charge began, on to `range_m`: its far
## end is stored in ArsenalState.charge_x and charge_z, so the view can draw the whole line while it charges (the HUD
## reads the countdown, ArsenalState.charge_left). ArsenalSystem drives the sequence: `begin` starts the charge,
## `fire` (called once the charge is done and the cadence allows the shot) resolves the line. Every enemy on the line
## takes the full damage (`pierce` -1: no falloff); `armor_ignore` applies as for any direct hit.

const ARMED: int = -1  ## ArsenalState.charge_left while a finished charge waits for the cadence


## Starts the wind-up on the Warden's locked target. False when there is none.
static func begin(world: SimWorld, def: WeaponDef) -> bool:
	var w: WardenState = world.warden
	var store: EnemyStore = world.enemies
	var target: int = store.index_of(w.target_id)
	if target < 0:
		return false
	var dx: float = store.x[target] - w.x
	var dz: float = store.z[target] - w.z
	var len_m: float = sqrt(dx * dx + dz * dz)
	if len_m < 0.0001:
		dx = 1.0
		dz = 0.0
		len_m = 1.0
	var reach: float = ArsenalSystem.range_of(world, def)
	var a: ArsenalState = world.arsenal
	a.charge_x = w.x + dx / len_m * reach
	a.charge_z = w.z + dz / len_m * reach
	a.charge_left = maxi(1, def.charge_ticks)
	return true


## Resolves the line fixed by `begin`. Pushes SHOT_FIRED(source, the nearest enemy on the line, else the locked target).
static func fire(world: SimWorld, slot: int, def: WeaponDef, source: int) -> bool:
	var a: ArsenalState = world.arsenal
	var w: WardenState = world.warden
	var hit: PackedInt32Array = on_line(world, w.x, w.z, a.charge_x, a.charge_z, def.area_m * 0.5)
	var first_id: int = world.enemies.id[hit[0]] if not hit.is_empty() else w.target_id
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, first_id)
	var level: int = a.slot_level[slot]
	for i: int in hit:
		DamageResolver.warden_hit(world, i, def, level, 1.0, 0, source)
	a.charge_left = 0
	return true


## Store indices of the living enemies whose body is within `half_width` of the segment A-B, nearest to A first (the lower
## id on a tie).
static func on_line(
	world: SimWorld, ax: float, az: float, bx: float, bz: float, half_width: float
) -> PackedInt32Array:
	var store: EnemyStore = world.enemies
	var found: PackedInt32Array = PackedInt32Array()
	var keys: PackedFloat64Array = PackedFloat64Array()
	var frac: PackedFloat64Array = PackedFloat64Array([0.0])
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		var off: float = FireTargets.segment_distance(store.x[i], store.z[i], ax, az, bx, bz, frac)
		if off - world.content.enemies[store.type[i]].radius > half_width + 0.000001:
			continue
		var at: int = found.size()
		while at > 0 and (keys[at - 1] > frac[0] or (keys[at - 1] == frac[0] and store.id[found[at - 1]] > store.id[i])):
			at -= 1
		found.insert(at, i)
		keys.insert(at, frac[0])
	return found
