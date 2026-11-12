class_name HarnessReport
extends RefCounted
## What one whole headless run produced (SimHarness fills it). Plain numbers for tools, tests and the balance report.

var run_seed: int = 0
var policy: int = PolicyBot.Policy.NONE
var result: int = RunResult.Id.NONE  ## NONE when the run hit the tick limit
var timed_out: bool = false
var ticks: int = 0
var waves_completed: int = 0
var wave_reached: int = 0  ## world.wave when the run stopped (the wave a defeat happened in)
var core_hp: float = 0.0
var core_max_hp: float = 0.0
var peak_alive: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])  ## index 0 = wave 1
var wave_start_ticks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var wave_clear_ticks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])  ## 0 = never cleared
var scrap_earned: int = 0
var scrap_spent: int = 0
var commands: int = 0  ## commands the sim applied (the CommandLog)
var purchases: int = 0  ## purchases that succeeded
var purchases_by_upgrade: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var abilities_used: PackedInt32Array = PackedInt32Array([0, 0, 0])
var kills_by_type: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var spawned: int = 0
var max_pending: int = 0
var stuck_recoveries: int = 0
var boss_spawn_tick: int = -1
var boss_kill_tick: int = -1
var core_hits: int = 0
## Per wave 1..5 (index 0 = wave 1): core integrity lost and Scrap earned by kills during it.
var core_lost: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
var scrap_by_wave: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
## Successful purchases in order (tick, wave, upgrade index).
var buy_ticks: PackedInt32Array = PackedInt32Array()
var buy_waves: PackedInt32Array = PackedInt32Array()
var buy_upgrades: PackedInt32Array = PackedInt32Array()
var state_hash: String = ""
var event_hash: int = 0
var violations: PackedStringArray = PackedStringArray()  ## broken invariants (HarnessChecker); empty = clean
var log: CommandLog = null
var world: SimWorld = null
# --- variety milestone (sim_run prints these; the scorecard reads them) ---
var death_wave: int = 0  ## world.wave when the core fell; 0 for a victory or an unfinished run
var signature: String = ""  ## BuildSignature: primary weapon by damage dealt plus the two tags with most stacks
var damage_by_weapon: PackedFloat64Array = PackedFloat64Array()  ## enemy hp removed per ContentSet.weapons index
var stalled: bool = false  ## the run waited for a choice the bot did not (or could not) answer; see SimHarness
var stalled_on: int = 0  ## the PhaseState.Await it was stuck on


func seconds() -> float:
	return float(ticks) / float(SimWorld.TICK_RATE)


## Core integrity left, 0..1.
func core_fraction() -> float:
	return core_hp / maxf(core_max_hp, 1.0)


func is_victory() -> bool:
	return result == RunResult.Id.VICTORY


func result_name() -> String:
	match result:
		RunResult.Id.VICTORY:
			return "VICTORY"
		RunResult.Id.DEFEAT:
			return "DEFEAT"
		_:
			return "UNFINISHED"


## Seconds the boss lived (spawn to kill), or -1 when it did not both spawn and die.
func boss_seconds() -> float:
	if boss_spawn_tick < 0 or boss_kill_tick < 0:
		return -1.0
	return float(boss_kill_tick - boss_spawn_tick) / float(SimWorld.TICK_RATE)


## Seconds from the start of wave `n` (1..5) to its clear, or -1 when it was never started or cleared.
func wave_seconds(n: int) -> float:
	if n < 1 or n > 5 or wave_start_ticks[n - 1] == 0 or wave_clear_ticks[n - 1] == 0:
		return -1.0
	return float(wave_clear_ticks[n - 1] - wave_start_ticks[n - 1]) / float(SimWorld.TICK_RATE)
