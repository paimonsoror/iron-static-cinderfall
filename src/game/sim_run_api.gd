class_name SimRunApi
extends RunApi
## RunApi bound to a RunController (ARCH 7.2): the UI's only door to gameplay. Commands go to the controller (which
## rejects them while paused and never lets them reach the sim); queries read the live SimWorld and fall back to
## the base-class defaults when no run is bound. Block reasons are the real ones from SimWorld.

var controller: RunController


func bind(run_controller: RunController) -> void:
	controller = run_controller


# --- commands ---


func purchase_upgrade(command_id: int, upgrade_id: StringName) -> void:
	if controller != null:
		controller.submit_purchase(command_id, upgrade_id)


func activate_ability(command_id: int, ability_id: StringName) -> void:
	if controller != null:
		controller.submit_ability(command_id, ability_id)


func skip_intermission() -> void:
	if controller != null:
		controller.submit_skip()


func pause() -> void:
	if controller != null:
		controller.set_paused(true)


func resume() -> void:
	if controller != null:
		controller.set_paused(false)


# --- queries ---


func is_paused() -> bool:
	return controller != null and controller.paused


func phase() -> int:
	var w: SimWorld = _world()
	return w.phase if w != null else super.phase()


func wave() -> int:
	var w: SimWorld = _world()
	return w.wave if w != null else 0


func wave_count() -> int:
	var w: SimWorld = _world()
	return w.content.waves.size() if w != null else super.wave_count()


func phase_ticks_left() -> int:
	var w: SimWorld = _world()
	return w.phase_ticks_left if w != null else 0


func core_hp() -> float:
	var w: SimWorld = _world()
	return w.core_hp if w != null else 0.0


func core_max_hp() -> float:
	var w: SimWorld = _world()
	return w.core_max_hp if w != null else 0.0


func shield_hp() -> float:
	var w: SimWorld = _world()
	return w.shield_hp if w != null else 0.0


func shield_max() -> float:
	var w: SimWorld = _world()
	return w.content.abilities[Ids.AB_SHIELD].absorb if w != null else 0.0


func scrap() -> int:
	var w: SimWorld = _world()
	return w.scrap if w != null else 0


func upgrade_level(id: StringName) -> int:
	var w: SimWorld = _world()
	var i: int = Ids.upgrade_index(id)
	if w == null or i < 0:
		return 0
	return w.upgrade_levels[i]


func upgrade_max_level(id: StringName) -> int:
	var w: SimWorld = _world()
	var i: int = Ids.upgrade_index(id)
	if w == null or i < 0:
		return 0
	return w.content.upgrades[i].max_level


func upgrade_cost(id: StringName) -> int:
	var w: SimWorld = _world()
	var i: int = Ids.upgrade_index(id)
	if w == null or i < 0:
		return -1
	return w.upgrade_cost(i)


func purchase_block_reason(id: StringName) -> int:
	var w: SimWorld = _world()
	if w == null:
		return Reason.Id.WRONG_STATE
	var i: int = Ids.upgrade_index(id)
	if i < 0:
		return Reason.Id.UNKNOWN_ID
	return w.purchase_block_reason(i)


func ability_block_reason(id: StringName) -> int:
	var w: SimWorld = _world()
	if w == null:
		return Reason.Id.WRONG_STATE
	var i: int = Ids.ability_index(id)
	if i < 0:
		return Reason.Id.UNKNOWN_ID
	return w.ability_block_reason(i)


func ability_cooldown_left(id: StringName) -> int:
	var w: SimWorld = _world()
	var i: int = Ids.ability_index(id)
	if w == null or i < 0:
		return 0
	return w.abilities.cooldown_left[i]


func ability_cooldown_total(id: StringName) -> int:
	var w: SimWorld = _world()
	var i: int = Ids.ability_index(id)
	if w == null or i < 0:
		return 0
	return w.content.abilities[i].cooldown_ticks


func ability_active_left(id: StringName) -> int:
	var w: SimWorld = _world()
	var i: int = Ids.ability_index(id)
	if w == null or i < 0:
		return 0
	return w.abilities.active_left[i]


func ability_active_total(id: StringName) -> int:
	var w: SimWorld = _world()
	var i: int = Ids.ability_index(id)
	if w == null or i < 0:
		return 0
	return w.content.abilities[i].duration_ticks


func weapon_id() -> StringName:
	var w: SimWorld = _world()
	if w == null:
		return super.weapon_id()
	return w.content.weapons[w.warden.weapon_index].id


func magazine() -> int:
	var w: SimWorld = _world()
	return w.warden.magazine if w != null else 0


func magazine_size() -> int:
	var w: SimWorld = _world()
	return w.content.weapons[w.warden.weapon_index].magazine if w != null else 0


func reload_ticks_left() -> int:
	var w: SimWorld = _world()
	return w.warden.reload_ticks_left if w != null else 0


func alive_count() -> int:
	var w: SimWorld = _world()
	return w.alive_count() if w != null else 0


func pending_spawn_count() -> int:
	var w: SimWorld = _world()
	return SpawnSystem.pending_count(w) if w != null else 0


func boss_hp() -> float:
	var w: SimWorld = _world()
	if w == null:
		return -1.0
	var i: int = w.boss_store_index()
	return w.enemies.hp[i] if i >= 0 else -1.0


func boss_max_hp() -> float:
	var w: SimWorld = _world()
	if w == null:
		return 0.0
	var i: int = w.boss_store_index()
	return w.enemies.max_hp[i] if i >= 0 else 0.0


func _world() -> SimWorld:
	return controller.sim if controller != null else null
