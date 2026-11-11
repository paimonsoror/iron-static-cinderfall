class_name RunApi
extends RefCounted
## The UI's only door to gameplay (ARCH 7.2). This base class returns safe defaults; SimRunApi (W2-A) binds
## it to a RunController and FakeRunApi (src/debug) drives the HUD in tests and sandboxes.

@warning_ignore_start("unused_parameter")

var _next_command_id: int = 0


# --- commands (D8: pause/resume are application-level and never enter the replay log) ---


## Mints a fresh, unique command id (one per tap).
func next_command_id() -> int:
	_next_command_id += 1
	return _next_command_id


func purchase_upgrade(command_id: int, upgrade_id: StringName) -> void:
	pass


func activate_ability(command_id: int, ability_id: StringName) -> void:
	pass


func skip_intermission() -> void:
	pass


func pause() -> void:
	pass


func resume() -> void:
	pass


# --- queries (cheap; the HUD polls them at 10 Hz and on signals) ---


func is_paused() -> bool:
	return false


## GameState.Id.
func phase() -> int:
	return GameState.Id.PREPARING


func wave() -> int:
	return 0


func wave_count() -> int:
	return 5


func phase_ticks_left() -> int:
	return 0


func core_hp() -> float:
	return 0.0


func core_max_hp() -> float:
	return 0.0


func shield_hp() -> float:
	return 0.0


func shield_max() -> float:
	return 0.0


func scrap() -> int:
	return 0


func upgrade_level(id: StringName) -> int:
	return 0


func upgrade_max_level(id: StringName) -> int:
	return 0


## -1 at max level.
func upgrade_cost(id: StringName) -> int:
	return -1


## Reason.Id.
func purchase_block_reason(id: StringName) -> int:
	return Reason.Id.WRONG_STATE


## Reason.Id.
func ability_block_reason(id: StringName) -> int:
	return Reason.Id.WRONG_STATE


## Ticks.
func ability_cooldown_left(id: StringName) -> int:
	return 0


func ability_cooldown_total(id: StringName) -> int:
	return 0


func ability_active_left(id: StringName) -> int:
	return 0


func ability_active_total(id: StringName) -> int:
	return 0


func weapon_id() -> StringName:
	return &"pistol"


func magazine() -> int:
	return 0


func magazine_size() -> int:
	return 0


func reload_ticks_left() -> int:
	return 0


func alive_count() -> int:
	return 0


func pending_spawn_count() -> int:
	return 0


## -1.0 when no boss.
func boss_hp() -> float:
	return -1.0


func boss_max_hp() -> float:
	return 0.0
