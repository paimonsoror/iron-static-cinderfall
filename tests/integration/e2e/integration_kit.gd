class_name IntegrationKit
extends RefCounted
## Test helpers (W3-A) for the end-to-end suites in tests/integration/e2e/. They drive the real Game, RunController, sim,
## view and HUD through a GameHarness (tests/integration/game), one tick per frame, and read only what a player or the
## event stream could see.

const DT: float = 1.0 / 60.0


## `GameHarness.create` content tweak: the first two waves only, so INTERMISSION exists and the run is short.
static func two_waves(c: ContentSet) -> void:
	c.waves = GameRunKit.first_waves(c, 2)


## `GameHarness.create` content tweak: combat starts 10 ticks after the deploy instead of 180.
static func short_prepare(c: ContentSet) -> void:
	c.mission.prepare_ticks = 10


## `sim_config_hook`: damage x50 and an invulnerable core, so a run with no purchases still wins.
static func boost(config: SimConfig) -> void:
	config.debug_damage_mult = 50.0
	config.debug_invulnerable_core = true


## `sim_config_hook`: the debug build of the full-run tests (WORK_PLAN card V5-A): damage x4. With `--unlock=all` and
## the balanced bot it wins the 15 waves fast and for certain, whatever the balance of the day is.
static func boost_x4(config: SimConfig) -> void:
	config.debug_damage_mult = 4.0


## `sim_config_hook`: enough Scrap to buy the whole tree at once.
static func rich(config: SimConfig) -> void:
	config.debug_start_scrap = 20000


## The SMG unlocks from wave 2 (GDD 5.2). Hold scenarios never leave wave 1, so a cadence test lowers the gate on its
## own copy of the content; the purchase itself still goes through the HUD API, the sim and the event stream.
static func smg_from_wave_one(c: ContentSet) -> void:
	c.upgrades[Ids.UP_SMG].min_wave = 1


## Steps one frame (one tick) at a time until the sim is in `phase`. Returns the frames used, or -1.
static func run_to_phase(h: GameHarness, phase: int, max_frames: int) -> int:
	var rc: RunController = h.rc()
	for i: int in max_frames:
		if rc.sim.phase == phase:
			return i
		rc.step_frame(DT)
	return max_frames if rc.sim.phase == phase else -1


## Everything a pause must leave alone, as a comparable value.
static func frozen_state(rc: RunController) -> Dictionary:
	var s: SimWorld = rc.sim
	var cooldowns: Array[int] = []
	var actives: Array[int] = []
	for a: int in Ids.ABILITIES.size():
		cooldowns.append(s.abilities.cooldown_left[a])
		actives.append(s.abilities.active_left[a])
	return {
		"hash": s.state_hash(), "tick": s.tick, "phase": s.phase, "phase_ticks_left": s.phase_ticks_left,
		"scrap": s.scrap, "core": s.core_hp, "alive": s.alive_count(), "events": s.events.total,
		"cooldowns": cooldowns, "actives": actives, "log": s.command_log.entries.size(),
	}


## `Performance` counters that must not grow with the number of retries.
static func leak_counters() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"connections": GameSignalLog.events_connection_count(),
		"memory": OS.get_static_memory_usage(),
	}


## The profile fields a relaunch must show again.
static func totals(p: Profile) -> Array:
	return [p.data, p.runs_played, p.missions_completed, p.best_core_hp, Array(p.awarded_run_ids)]


## A second, independent Save manager (a relaunch) reading the same file system.
static func relaunch(fs: SaveFs) -> Node:
	var script: GDScript = load("res://src/save/save_manager.gd") as GDScript
	var fresh: Node = script.new()
	fresh.call(&"use_fs", fs)
	fresh.call(&"load_profile")
	return fresh


static func profile_of(save_node: Node) -> Profile:
	var o: Object = save_node.get(&"profile")
	return o as Profile
