class_name VarietyDKit
extends RefCounted
## Test helper (V2-D): runs that are killed and resumed. A "kill" throws the RunController away and keeps only what
## the Save autoload holds (an in-memory file system here); a resume builds a new controller from `Save.load_run()`.
##
## `play` is a player whose decisions depend on the sim state only (never on frame counts or on what it did before),
## so a run that is killed and resumed makes the same decisions as an uninterrupted one from the same state on.

const DT: float = 1.0 / 60.0
const UPGRADE_ORDER: Array[StringName] = [&"damage", &"fire_rate", &"auto_turret", &"armor_piercing", &"smg_unlock"]


## A boosted config (damage x50, invulnerable core), so a run without skill still clears its waves quickly.
## `wave_count` > 0 keeps only that many waves of the content.
static func config(content: ContentSet, run_seed: int, wave_count: int = 0) -> SimConfig:
	if wave_count > 0:
		content.waves = GameRunKit.first_waves(content, wave_count)
	var c: SimConfig = SimConfig.create(content, run_seed)
	c.debug_damage_mult = 50.0
	c.debug_invulnerable_core = true
	return c


## A controller that continues the run file of the Save autoload (not driven by the engine).
static func resumed(suite: GdUnitTestSuite, content: ContentSet) -> RunController:
	var rc: RunController = RunController.new()
	suite.auto_free(rc)
	suite.add_child(rc)
	rc.start_resumed(Save.load_run(), null, content)
	rc.set_process(false)
	return rc


## Drops the controller as a process kill would: nothing is written, nothing is paid.
static func kill(rc: RunController) -> void:
	rc.stop()
	if rc.get_parent() != null:
		rc.get_parent().remove_child(rc)


## One decision of the state-driven player, then one 60 FPS frame (one tick, or none while the sim waits).
static func play_frame(rc: RunController) -> void:
	decide(rc)
	rc.step_frame(DT)


## `n` frames of `play_frame`, stopping when the run is over. Returns the frames used.
static func play(rc: RunController, n: int) -> int:
	for i: int in n:
		if rc.sim == null or rc.sim.is_over():
			return i
		play_frame(rc)
	return n


## Plays until the run is over. Returns the frames used, or -1 when `max_frames` were not enough.
static func play_to_end(rc: RunController, max_frames: int) -> int:
	var used: int = play(rc, max_frames)
	return used if rc.sim.is_over() else -1


## Plays until `waves` waves are cleared (or the run is over). Returns the frames used, or -1.
static func play_until_cleared(rc: RunController, waves: int, max_frames: int) -> int:
	for i: int in max_frames:
		if rc.sim.is_over() or rc.sim.waves_completed >= waves:
			return i
		play_frame(rc)
	return -1


## In the intermission: buy one affordable upgrade per frame for the first frames, then CONTINUE. In combat: the EMP
## every 600 ticks and the shield every 900 when they are ready. A generated run (the variety content) has choices
## instead of the shop: `decide_choice` answers them, from the state alone.
static func decide(rc: RunController) -> void:
	var w: SimWorld = rc.sim
	var api: SimRunApi = rc.api
	if w.plan != null and w.phase == GameState.Id.INTERMISSION:
		decide_choice(rc)
	elif w.phase == GameState.Id.INTERMISSION:
		var spent: int = w.content.mission.intermission_ticks - w.phase_ticks_left
		if spent < 4:
			for id: StringName in UPGRADE_ORDER:
				if api.purchase_block_reason(id) == Reason.Id.OK:
					api.purchase_upgrade(api.next_command_id(), id)
					return
		elif spent >= 6:
			api.skip_intermission()
	elif GameState.is_combat(w.phase):
		if w.tick % 600 == 0 and api.ability_block_reason(&"emp") == Reason.Id.OK:
			api.activate_ability(api.next_command_id(), &"emp")
		elif w.tick % 900 == 450 and api.ability_block_reason(&"shield") == Reason.Id.OK:
			api.activate_ability(api.next_command_id(), &"shield")


## One answer to what a generated run waits for, at most one command per frame and none while one is queued: the crate
## goes into the second slot when that is empty (else it is scrapped), the draft takes its first open slot, the route
## alternates with the wave number, the boss briefing and the breather are continued.
static func decide_choice(rc: RunController) -> void:
	var w: SimWorld = rc.sim
	var api: SimRunApi = rc.api
	if not w.command_queue.is_empty():
		return
	match api.awaiting():
		RunApi.AWAIT_SALVAGE:
			var empty_slot: bool = api.weapon_slot_count() > 1 and api.weapon_slot(1).get("id", &"") == &""
			api.resolve_salvage(api.next_command_id(), 0, 1 if empty_slot else RunApi.SALVAGE_SCRAP)
		RunApi.AWAIT_DRAFT:
			var offer: PackedInt32Array = api.draft_offer()
			var slot: int = -1
			for k: int in offer.size():
				if offer[k] >= 0 and slot < 0:
					slot = k
			if slot >= 0:
				api.pick_directive(api.next_command_id(), slot)
			else:
				api.skip_draft(api.next_command_id())
		RunApi.AWAIT_ROUTE:
			api.pick_route(api.next_command_id(), w.wave % maxi(1, api.route_option_count()))
		_:
			api.continue_run()


## The run file as the Save autoload holds it right now ({} when there is none).
static func doc() -> Dictionary:
	return Save.load_run()


## A world restored from the JSON text of a snapshot of `world` (the round trip the run file makes).
static func through_json(world: SimWorld) -> SimWorld:
	var text: String = RunStore.encode({"schema_version": 1, "run_id": "x", "state": WorldSnapshot.capture(world)})
	var back: Dictionary = RunStore.decode(text)
	var fresh: SimWorld = SimWorld.new(world.config)
	var state: Dictionary = back["state"]
	if not WorldSnapshot.restore(fresh, state):
		return null
	return fresh


## Steps a bare world (no controller) until `waves` waves are cleared, pressing CONTINUE in every intermission (and, in
## a generated run, scrapping the crate, skipping the draft and taking route A).
static func step_until_cleared(world: SimWorld, waves: int, max_ticks: int) -> bool:
	var next_id: int = 100000 + world.tick
	for i: int in max_ticks:
		if world.is_over() or world.waves_completed >= waves:
			return true
		if world.phase == GameState.Id.INTERMISSION:
			next_id += 1
			match world.phase_state.awaiting:
				PhaseState.Await.SALVAGE:
					world.submit(SimCommand.salvage(next_id, 0, SalvageSystem.ACTION_SCRAP))
				PhaseState.Await.DRAFT:
					world.submit(SimCommand.skip_draft(next_id))
				PhaseState.Await.ROUTE:
					world.submit(SimCommand.pick_route(next_id, 0))
				_:
					world.submit(SimCommand.skip(next_id))
		world.step()
		world.events.drain()
	return world.is_over() or world.waves_completed >= waves
