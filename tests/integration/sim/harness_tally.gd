class_name HarnessTally
extends RefCounted
## An independent second opinion on a whole run: it plays through the real `world.step()` and counts straight from the
## drained events, with its own code (not HarnessChecker), so a bug in one of them shows as a disagreement. Not a suite.

var world: SimWorld
var bot: PolicyBot
var cap: int = 0
var max_alive: int = 0
var problems: PackedStringArray = PackedStringArray()

var reward_sum: int = 0
var kills_by_type: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var spawned_by_type: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var spawned_by_wave: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])  ## index = wave
var scheduled_by_wave: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var cleared_waves: PackedInt32Array = PackedInt32Array()
var resolved_by_command: Dictionary[int, int] = {}  ## command id -> Reason
var purchase_ok: int = 0
var price_paid: int = 0
var level_events: int = 0
var finished: Array[SimEvent] = []
var boss_killed_tick: int = -1
var finished_tick: int = -1
var max_pending: int = 0
var _type_of: Dictionary[int, int] = {}
var _levels: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])


static func play(config: SimConfig, policy: int, max_ticks: int = SimHarness.DEFAULT_MAX_TICKS) -> HarnessTally:
	var t: HarnessTally = HarnessTally.new()
	t.world = SimWorld.new(config)
	t.bot = PolicyBot.new(policy)
	t.cap = t.world.content.mission.enemy_cap
	while not t.world.is_over() and t.world.tick < max_ticks:
		t.bot.act(t.world)
		t.world.step()
		t._tick(t.world.events.drain())
	return t


func _tick(events: Array[SimEvent]) -> void:
	var w: SimWorld = world
	var cleared_now: bool = false
	for e: SimEvent in events:
		match e.kind:
			SimEventKind.Id.WAVE_STARTED:
				scheduled_by_wave[e.a] = e.b
			SimEventKind.Id.ENEMY_SPAWNED:
				_type_of[e.a] = e.b
				spawned_by_type[e.b] += 1
				spawned_by_wave[w.wave] += 1
			SimEventKind.Id.ENEMY_KILLED:
				var type_index: int = _type_of[e.a]
				kills_by_type[type_index] += 1
				reward_sum += w.content.enemies[type_index].scrap
				if w.content.enemies[type_index].is_boss:
					boss_killed_tick = w.tick
			SimEventKind.Id.WAVE_CLEARED:
				cleared_now = true
				cleared_waves.append(e.a)
			SimEventKind.Id.PURCHASE_RESOLVED:
				resolved_by_command[e.a] = e.b
				if e.b == Reason.Id.OK:
					purchase_ok += 1
					var up: int = roundi(e.f)
					var def: UpgradeDef = w.content.upgrades[up]
					price_paid += Formulas.upgrade_cost(def.base_cost, def.growth, _levels[up])
					_levels[up] += 1
			SimEventKind.Id.UPGRADE_LEVEL_CHANGED:
				level_events += 1
			SimEventKind.Id.RUN_FINISHED:
				finished.append(e)
				finished_tick = w.tick
			_:
				pass
	var alive: int = w.alive_count()
	max_alive = maxi(max_alive, alive)
	max_pending = maxi(max_pending, SpawnSystem.pending_count(w))
	if alive > cap:
		problems.append("t%d: %d alive, cap %d" % [w.tick, alive, cap])
	var wave_over: bool = cleared_now or w.phase == GameState.Id.INTERMISSION or w.phase == GameState.Id.VICTORY
	if wave_over and (alive != 0 or SpawnSystem.pending_count(w) != 0 or not SpawnSystem.is_wave_fully_spawned(w)):
		problems.append("t%d: wave over with %d alive, %d pending" % [w.tick, alive, SpawnSystem.pending_count(w)])
	if w.phase == GameState.Id.CLEARING and not SpawnSystem.is_wave_fully_spawned(w):
		problems.append("t%d: CLEARING before the wave finished spawning" % w.tick)


func total_scheduled() -> int:
	var n: int = 0
	for wave: WaveDef in world.content.waves:
		n += wave.total_count()
	return n
