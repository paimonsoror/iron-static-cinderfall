class_name SimHarness
extends RefCounted
## Plays one whole run headless: the bot acts, the real `world.step()` runs, the drained events go to a
## HarnessChecker, and the totals end up in a HarnessReport. Used by tools/sim_run.gd, tools/balance_run.gd and the
## integration, determinism and stress tests, so they all measure the same thing.

## No run of the shipped waves lasts this long (WORK_PLAN seed sweep: every run ends before tick 60,000).
const DEFAULT_MAX_TICKS: int = 60000


## One run with `policy` (a PolicyBot.Policy). Stops at VICTORY or DEFEAT, or at `max_ticks` (timed_out).
static func run(config: SimConfig, policy: int, max_ticks: int = DEFAULT_MAX_TICKS) -> HarnessReport:
	var world: SimWorld = SimWorld.new(config)
	var bot: PolicyBot = PolicyBot.new(policy)
	var checker: HarnessChecker = HarnessChecker.new(world)
	while not world.is_over() and world.tick < max_ticks:
		bot.act(world)
		world.step()
		checker.after_step(world, world.events.drain())
	checker.finish(world, bot.commands_submitted)
	return report_of(world, policy, checker)


## The numbers of a finished (or stopped) world.
static func report_of(world: SimWorld, policy: int, checker: HarnessChecker) -> HarnessReport:
	var r: HarnessReport = HarnessReport.new()
	r.run_seed = world.config.run_seed
	r.policy = policy
	r.result = world.result()
	r.timed_out = not world.is_over()
	r.ticks = world.tick
	r.waves_completed = world.waves_completed
	r.wave_reached = world.wave
	r.core_hp = world.core_hp
	r.core_max_hp = world.core_max_hp
	for w: int in 5:
		r.peak_alive[w] = world.stats.peak_alive_by_wave[w + 1]
		r.wave_start_ticks[w] = world.stats.wave_start_tick[w + 1]
		r.wave_clear_ticks[w] = world.stats.wave_clear_tick[w + 1]
		r.core_lost[w] = checker.core_lost_by_wave[w + 1]
		r.scrap_by_wave[w] = checker.scrap_by_wave[w + 1]
	r.buy_ticks = checker.buy_ticks.duplicate()
	r.buy_waves = checker.buy_waves.duplicate()
	r.buy_upgrades = checker.buy_upgrades.duplicate()
	r.scrap_earned = world.stats.scrap_earned
	r.scrap_spent = world.stats.scrap_spent
	r.commands = world.command_log.entries.size()
	r.purchases = checker.purchases_ok
	r.purchases_by_upgrade = checker.purchases_by_upgrade.duplicate()
	r.abilities_used = checker.abilities_used.duplicate()
	r.kills_by_type = world.stats.kills_by_type.duplicate()
	r.spawned = checker.spawned
	r.max_pending = world.stats.max_pending
	r.stuck_recoveries = world.stats.stuck_recoveries
	r.boss_spawn_tick = checker.boss_spawn_tick
	r.boss_kill_tick = checker.boss_kill_tick
	r.core_hits = world.combat.core_hits
	r.state_hash = world.state_hash()
	r.event_hash = world.events.event_hash
	r.violations = checker.violations.duplicate()
	r.log = world.command_log
	r.world = world
	return r


## A config on `content_set` for a seed, with the named debug levers (all off by default).
static func config_for(content_set: ContentSet, run_seed: int, damage_mult: float = 1.0, start_scrap: int = 0) -> SimConfig:
	var c: SimConfig = SimConfig.create(content_set, run_seed)
	c.debug_damage_mult = damage_mult
	c.debug_start_scrap = start_scrap
	return c
