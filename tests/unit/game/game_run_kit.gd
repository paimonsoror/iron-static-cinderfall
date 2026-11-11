class_name GameRunKit
extends RefCounted
## Test helper (W2-A): a RunController on the frozen baseline content with an in-memory save, driven by hand.

const DT: float = 1.0 / 60.0


## A fresh in-memory profile (nothing on disk). Returns the fs so a test can make writes fail.
static func fresh_save() -> MemorySaveFs:
	var fs: MemorySaveFs = MemorySaveFs.new()
	Save.use_fs(fs)
	Save.load_profile()
	GameRewards.flush_pending = false
	return fs


## Gives the Save autoload a clean in-memory profile again (after_test).
static func reset_save() -> void:
	fresh_save()


## Baseline config. `boost` = debug_damage_mult 50 and an invulnerable core, so a run with no purchases still wins.
## `wave_count` > 0 keeps only that many waves (a shorter run; the content object is private to this config).
static func config(run_seed: int = 1, boost: bool = false, wave_count: int = 0) -> SimConfig:
	var c: SimConfig = SimConfig.create(TestContent.baseline(), run_seed)
	if wave_count > 0:
		c.content.waves = GameRunKit.first_waves(c.content, wave_count)
	if boost:
		c.debug_damage_mult = 50.0
		c.debug_invulnerable_core = true
	return c


## The first `count` waves of `content` (the run ends in VICTORY after the last of them).
static func first_waves(content: ContentSet, count: int) -> Array[WaveDef]:
	var kept: Array[WaveDef] = []
	for i: int in mini(count, content.waves.size()):
		kept.append(content.waves[i])
	return kept


## A started controller inside the suite's tree, not driven by the engine (tests call step_frame themselves).
static func controller(suite: GdUnitTestSuite, cfg: SimConfig, view: BattleView = null, id: String = "run-a") -> RunController:
	var rc: RunController = RunController.new()
	suite.auto_free(rc)
	suite.add_child(rc)
	rc.start(cfg, id, view)
	rc.set_process(false)
	return rc


## n frames of `delta` seconds. Returns the ticks run.
static func frames(rc: RunController, n: int, delta: float = DT) -> int:
	var ticks: int = 0
	for i: int in n:
		ticks += rc.step_frame(delta)
	return ticks


## Frames at 60 FPS until the run is over or `max_frames` passed. Returns the frames used, or -1 when it never ended.
static func run_to_end(rc: RunController, max_frames: int) -> int:
	for i: int in max_frames:
		if rc.sim.is_over():
			return i
		rc.step_frame(DT)
	return max_frames if rc.sim.is_over() else -1
