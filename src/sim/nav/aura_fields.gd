class_name AuraFields
extends RefCounted
## The spatial parts of the enemy statuses (StatusSystem calls them once per tick, tick step 7): which enemies stand
## in an OVERCLOCKER's aura, which stand behind a shieldbearer's ward, whom a reclaimer repairs, which turret pads a
## jammer covers. The results go into the derived per-enemy tables of NavState (speed_mul, period_mul, cover), which
## are rebuilt from hashed state every tick and are therefore neither hashed nor saved.


## OVERCLOCKER (CONTENT 4.3): every other living enemy within EliteSystem.OVERCLOCK_RANGE_M of one of `sources` (store
## indices of overclockers that are not stunned) moves faster and attacks faster. Auras do not stack; a boss is not
## affected (its script owns its timing).
static func overclock(world: SimWorld, sources: PackedInt32Array) -> void:
	var es: EnemyStore = world.enemies
	var nav: NavState = world.nav
	var r2: float = EliteSystem.OVERCLOCK_RANGE_M * EliteSystem.OVERCLOCK_RANGE_M
	var xs: PackedFloat64Array = es.x
	var zs: PackedFloat64Array = es.z
	var alive: PackedByteArray = es.alive
	var period: PackedFloat64Array = nav.period_mul
	var speed: PackedFloat64Array = nav.speed_mul
	var boss: PackedByteArray = nav.t_boss
	for o: int in sources:
		var ox: float = xs[o]
		var oz: float = zs[o]
		for j: int in es.high_water:
			if alive[j] == 0 or j == o or period[j] != 1.0 or boss[es.type[j]] == 1:
				continue
			var dx: float = xs[j] - ox
			var dz: float = zs[j] - oz
			if dx * dx + dz * dz <= r2:
				period[j] = EliteSystem.OVERCLOCK_PERIOD_MUL
				speed[j] *= EliteSystem.OVERCLOCK_SPEED_MUL


## Shieldbearer wards (CONTENT 4.2): every other living enemy within `ward_radius` of a bearer whose pool is not empty
## is covered by it (`nav.cover` = the bearer's store index); a boss is never covered. An enemy inside two wards is covered by the bearer that
## comes first in `bearers` (store order).
static func cover(world: SimWorld, bearers: PackedInt32Array) -> void:
	var es: EnemyStore = world.enemies
	var nav: NavState = world.nav
	var xs: PackedFloat64Array = es.x
	var zs: PackedFloat64Array = es.z
	var alive: PackedByteArray = es.alive
	var covered: PackedInt32Array = nav.cover
	for b: int in bearers:
		if world.ext.ward_milli[b] <= 0:
			continue
		var radius: float = world.content.enemies[es.type[b]].beh(&"ward_radius")
		var r2: float = radius * radius
		var bx: float = xs[b]
		var bz: float = zs[b]
		for j: int in es.high_water:
			if alive[j] == 0 or j == b or covered[j] >= 0 or nav.t_boss[es.type[j]] == 1:
				continue
			var dx: float = xs[j] - bx
			var dz: float = zs[j] - bz
			if dx * dx + dz * dz <= r2:
				covered[j] = b


## The enemies the reclaimer at store index `healer` would repair now, written to `out` (cleared first): up to
## `tether_count` damaged living enemies within `tether_range` that are neither bosses nor minis nor still under the
## ground, the most damaged first (lowest hp / max hp), ties by the lower id. Returns the count.
static func tether_targets(world: SimWorld, healer: int, out: PackedInt32Array) -> int:
	out.clear()
	var es: EnemyStore = world.enemies
	var def: EnemyDef = world.content.enemies[es.type[healer]]
	var want: int = roundi(def.beh(&"tether_count"))
	var reach: float = def.beh(&"tether_range")
	if want <= 0 or reach <= 0.0:
		return 0
	var r2: float = reach * reach
	var skip: int = EnemyExtState.F_MINI | EnemyExtState.F_EMERGING
	var frac: PackedFloat64Array = PackedFloat64Array()
	for j: int in es.high_water:
		if es.alive[j] == 0 or j == healer or es.hp[j] >= es.max_hp[j] or es.max_hp[j] <= 0.0:
			continue
		if (world.ext.flags[j] & skip) != 0 or world.content.enemies[es.type[j]].is_boss:
			continue
		var dx: float = es.x[j] - es.x[healer]
		var dz: float = es.z[j] - es.z[healer]
		if dx * dx + dz * dz > r2:
			continue
		var f: float = es.hp[j] / es.max_hp[j]
		var at: int = out.size()
		while at > 0 and (frac[at - 1] > f or (frac[at - 1] == f and es.id[out[at - 1]] > es.id[j])):
			at -= 1
		if at >= want:
			continue
		out.insert(at, j)
		frac.insert(at, f)
		if out.size() > want:
			out.resize(want)
			frac.resize(want)
	return out.size()


## The hit points one tether restores per pulse of `pulse_ticks`: `heal_per_s` x the act's HP tier.
static func tether_pulse(world: SimWorld, def: EnemyDef, pulse_ticks: int) -> float:
	return def.beh(&"heal_per_s") * EliteSystem.hp_tier(world) * float(pulse_ticks) / 60.0


## The lowest `cooldown_rate` of the living jammers that are above the ground, 1.0 without one.
static func jam_cooldown_rate(world: SimWorld) -> float:
	var es: EnemyStore = world.enemies
	var special: PackedByteArray = world.nav.t_special
	var rate: float = 1.0
	for i: int in es.high_water:
		if es.alive[i] == 0 or (special[es.type[i]] & StatusSystem.SP_JAMMER) == 0:
			continue
		if (world.ext.flags[i] & EnemyExtState.F_EMERGING) == 0:
			rate = minf(rate, world.content.enemies[es.type[i]].beh(&"cooldown_rate", 1.0))
	return rate


## The lowest `turret_rate_mult` of the living jammers whose `aura_radius` reaches (x, z), 1.0 when none does.
static func jam_turret_rate(world: SimWorld, x: float, z: float) -> float:
	var es: EnemyStore = world.enemies
	var special: PackedByteArray = world.nav.t_special
	var mult: float = 1.0
	for i: int in es.high_water:
		if es.alive[i] == 0 or (special[es.type[i]] & StatusSystem.SP_JAMMER) == 0:
			continue
		if (world.ext.flags[i] & EnemyExtState.F_EMERGING) != 0:
			continue
		var def: EnemyDef = world.content.enemies[es.type[i]]
		var radius: float = def.beh(&"aura_radius")
		var dx: float = es.x[i] - x
		var dz: float = es.z[i] - z
		if dx * dx + dz * dz <= radius * radius:
			mult = minf(mult, def.beh(&"turret_rate_mult", 1.0))
	return mult
