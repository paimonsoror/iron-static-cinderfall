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
	return PhaseSystem.wave_count(w) if w != null else super.wave_count()


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
	return w.content.weapons[w.warden.weapon_index].id if w != null else super.weapon_id()


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
	var i: int = w.boss_store_index() if w != null else -1
	return w.enemies.hp[i] if i >= 0 else -1.0


func boss_max_hp() -> float:
	var w: SimWorld = _world()
	var i: int = w.boss_store_index() if w != null else -1
	return w.enemies.max_hp[i] if i >= 0 else 0.0


# ================================================================ variety milestone (VARIETY_SPEC 13.4)
# Commands become SimCommands through the controller (refused with `Events.command_rejected` while paused or after
# the end). Queries read the variety state; on the legacy content (and with no run) they give the base defaults.


func pick_directive(command_id: int, slot: int) -> void:
	_send(command_id, SimCommand.Kind.PICK_DIRECTIVE, slot)


func skip_draft(command_id: int) -> void:
	_send(command_id, SimCommand.Kind.SKIP_DRAFT, 0)


func reroll_draft(command_id: int) -> void:
	_send(command_id, SimCommand.Kind.REROLL, 0)


func buy_out(command_id: int, slot: int) -> void:
	_send(command_id, SimCommand.Kind.BUY_OUT, slot)


func patch_core(command_id: int) -> void:
	_send(command_id, SimCommand.Kind.PATCH_CORE, 0)


func pick_route(command_id: int, option: int) -> void:
	_send(command_id, SimCommand.Kind.PICK_ROUTE, option)


func resolve_salvage(command_id: int, choice: int, action: int) -> void:
	_send(command_id, SimCommand.Kind.SALVAGE, choice * 16 + action if choice >= 0 and action >= 0 else -1)


func swap_weapon(command_id: int, slot: int) -> void:
	_send(command_id, SimCommand.Kind.SWAP_WEAPON, slot)


func call_event(command_id: int, event_id: StringName) -> void:
	var w: SimWorld = _world()
	_send(command_id, SimCommand.Kind.CALL_EVENT, w.content.event_index(event_id) if w != null else -1)


func awaiting() -> int:
	var w: SimWorld = _world()
	return w.phase_state.awaiting if w != null else super.awaiting()


func act() -> int:
	var w: SimWorld = _world()
	return w.phase_state.act if w != null else super.act()


func act_count() -> int:
	var w: SimWorld = _variety()
	return maxi(1, w.content.run.acts.size()) if w != null else super.act_count()


func draft_offer() -> PackedInt32Array:
	var w: SimWorld = _world()
	return w.draft.offer.duplicate() if w != null and w.draft.open else super.draft_offer()


func draft_reroll_cost() -> int:
	var w: SimWorld = _variety()
	return DraftSystem.reroll_cost(w) if w != null else super.draft_reroll_cost()


func draft_buyout_cost() -> int:
	var w: SimWorld = _variety()
	return DraftSystem.buyout_cost(w) if w != null else super.draft_buyout_cost()


func patch_cost() -> int:
	var w: SimWorld = _variety()
	return DraftSystem.patch_cost(w) if w != null else super.patch_cost()


func free_rerolls() -> int:
	var w: SimWorld = _world()
	return w.draft.free_rerolls if w != null else super.free_rerolls()


func route_option_count() -> int:
	var w: SimWorld = _variety()
	return SimRunQueries.route_option_count(w) if w != null else super.route_option_count()


func route_option(i: int) -> Dictionary:
	var w: SimWorld = _variety()
	return SimRunQueries.route_option(w, i) if w != null else super.route_option(i)


func boss_brief() -> Dictionary:
	var w: SimWorld = _variety()
	return SimRunQueries.boss_brief(w) if w != null else super.boss_brief()


func salvage_offer() -> Dictionary:
	var w: SimWorld = _variety()
	return SimRunQueries.salvage_offer(w) if w != null else super.salvage_offer()


func weapon_slot_count() -> int:
	var w: SimWorld = _variety()
	return w.arsenal.slot_count if w != null else super.weapon_slot_count()


func weapon_slot(i: int) -> Dictionary:
	var w: SimWorld = _variety()
	return SimRunQueries.weapon_slot(w, i) if w != null else super.weapon_slot(i)


func active_slot() -> int:
	var w: SimWorld = _variety()
	return w.arsenal.active if w != null else super.active_slot()


func event_charges(id: StringName) -> int:
	var w: SimWorld = _world()
	return w.events_state.charges_of(w.content.event_index(id)) if w != null else super.event_charges(id)


func call_block_reason(id: StringName) -> int:
	var w: SimWorld = _world()
	if w == null:
		return super.call_block_reason(id)
	if controller.paused:
		return Reason.Id.PAUSED
	return EventSystem.block_reason(w, w.content.event_index(id))


func active_events() -> Array[Dictionary]:
	var w: SimWorld = _world()
	return SimRunQueries.active_events(w) if w != null else super.active_events()


func directive_stacks(id: StringName) -> int:
	var w: SimWorld = _world()
	return w.draft.stacks_of(w.content.directive_index(id)) if w != null else super.directive_stacks(id)


func build_tags() -> Dictionary:
	var w: SimWorld = _variety()
	return SimRunQueries.build_tags(w) if w != null else super.build_tags()


func boss_phase() -> int:
	var w: SimWorld = _world()
	return w.boss.phase if w != null and w.boss.boss_id != 0 else super.boss_phase()


func boss_phase_count() -> int:
	var w: SimWorld = _world()
	return maxi(1, w.boss.phase_count) if w != null and w.boss.boss_id != 0 else super.boss_phase_count()


func run_seed() -> int:
	var w: SimWorld = _world()
	return w.config.run_seed if w != null else super.run_seed()


func draft_buyout_used() -> bool:
	return SimRunQueries.buyout_used(_variety())


func draft_actions_locked() -> bool:
	return SimRunQueries.draft_locked(_variety())


func crate_status() -> Dictionary:
	return SimRunQueries.crate_status(_variety())


func _send(command_id: int, kind: int, arg: int) -> void:
	if controller != null:
		controller.submit_variety(command_id, kind, arg)


func _world() -> SimWorld:
	return controller.sim if controller != null else null


## The live world when it runs variety content (a run plan and the run data), else null.
func _variety() -> SimWorld:
	var w: SimWorld = _world()
	return w if w != null and w.content.run != null else null
