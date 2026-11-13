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


# ================================================================ variety milestone (VARIETY_SPEC 13.4; append only)

## awaiting(): the intermission sub-step that waits for a choice. Mirrors PhaseState.Await (the UI may not name sim classes).
const AWAIT_NONE: int = 0
const AWAIT_SALVAGE: int = 1
const AWAIT_DRAFT: int = 2
const AWAIT_ROUTE: int = 3
const AWAIT_BOSS_BRIEF: int = 4
## weapon_slot()["state"]. Mirrors ArsenalSystem.ST_*.
const SLOT_READY: int = 0
const SLOT_RELOADING: int = 1
const SLOT_VENTING: int = 2
const SLOT_SWAPPING: int = 3
const SLOT_CHARGING: int = 4
const SLOT_EMPTY: int = 5
## resolve_salvage() actions. Mirror SalvageSystem.ACTION_*: 0..2 = take the weapon in that slot.
const SALVAGE_LEVEL_UP: int = 8
const SALVAGE_SCRAP: int = 9


# --- commands (each takes a fresh next_command_id(); a refusal arrives as Events.command_rejected) ---


func pick_directive(command_id: int, slot: int) -> void:
	pass


func skip_draft(command_id: int) -> void:
	pass


func reroll_draft(command_id: int) -> void:
	pass


## Before picking: also keep the directive in `slot` for Scrap (once per draft).
func buy_out(command_id: int, slot: int) -> void:
	pass


func patch_core(command_id: int) -> void:
	pass


func pick_route(command_id: int, option: int) -> void:
	pass


## `choice` = which weapon of the crate (0 unless a boss crate); `action` = 0..2 slot, SALVAGE_LEVEL_UP or SALVAGE_SCRAP.
func resolve_salvage(command_id: int, choice: int, action: int) -> void:
	pass


func swap_weapon(command_id: int, slot: int) -> void:
	pass


## A HUD call button: an EventDef id (&"deadfall_strike", &"core_vent", &"freight_call").
func call_event(command_id: int, event_id: StringName) -> void:
	pass


## The CONTINUE button of the boss briefing (and the breather skip): same as skip_intermission.
func continue_run() -> void:
	skip_intermission()


# --- queries ---


## AWAIT_*.
func awaiting() -> int:
	return AWAIT_NONE


## 1-based act of the current wave.
func act() -> int:
	return 1


func act_count() -> int:
	return 1


## Directive index per slot of the open draft (ContentSet.directives); -1 = slot already taken. Empty = no draft.
func draft_offer() -> PackedInt32Array:
	return PackedInt32Array()


## Scrap for the next reroll; 0 while a free reroll is left.
func draft_reroll_cost() -> int:
	return 0


func draft_buyout_cost() -> int:
	return 0


func patch_cost() -> int:
	return 0


func free_rerolls() -> int:
	return 0


func route_option_count() -> int:
	return 0


## { "pack": StringName, "name_key": String, "counts": { enemy id: int }, "total": int, "modifier": StringName (&"" =
## none), "modifier_key": String, "elites": int, "hot": bool, "reward": StringName, "reward_key": String,
## "reward_amount": int }. Empty for an unknown option.
func route_option(i: int) -> Dictionary:
	return {}


## { "id": StringName, "name_key": String, "banner_key": String, "variant": StringName (&"" = none),
## "attack_key": String, "answer_key": String }. Empty when the next wave is not a boss wave.
func boss_brief() -> Dictionary:
	return {}


## { "weapons": [StringName], "tiers": [int], "level_up_slot": [int] (the carried slot a duplicate would level up, or
## -1), "boss": bool, "scrap_value": int }. Empty when no crate is being resolved.
func salvage_offer() -> Dictionary:
	return {}


func weapon_slot_count() -> int:
	return 1


## { "id": StringName, "level": int, "magazine": int, "size": int, "heat": int, "heat_cap": int (0 = a magazine weapon),
## "state": SLOT_*, "ticks_left": int (of the reload, vent, swap or charge) }. The default describes the one legacy weapon.
func weapon_slot(i: int) -> Dictionary:
	if i != 0:
		return {}
	var reloading: int = reload_ticks_left()
	return {
		"id": weapon_id(), "level": 1, "magazine": magazine(), "size": magazine_size(), "heat": 0, "heat_cap": 0,
		"state": SLOT_RELOADING if reloading > 0 else SLOT_READY, "ticks_left": reloading,
	}


func active_slot() -> int:
	return 0


## Charges of a player-triggered event (an EventDef id).
func event_charges(id: StringName) -> int:
	return 0


## Reason.Id: OK when the event can be called right now.
func call_block_reason(id: StringName) -> int:
	return Reason.Id.WRONG_STATE


## The events that are warning or running, oldest first: { "id": StringName, "phase": 0 warning | 1 running,
## "ticks_left": int, "ticks_total": int, "harmful": bool, "x": float, "z": float }.
func active_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


## Stacks held of a directive (a DirectiveDef id).
func directive_stacks(id: StringName) -> int:
	return 0


## { tag (StringName): stacks held with that tag }.
func build_tags() -> Dictionary:
	return {}


## 0-based phase of the living boss; 0 without one.
func boss_phase() -> int:
	return 0


func boss_phase_count() -> int:
	return 1


func run_seed() -> int:
	return 0


# --- slice integration (V3-I; append only) ---


## True once the open draft's one buy-out was used (the KEEP ALSO buttons go away).
func draft_buyout_used() -> bool:
	return false


## True when the open draft allows neither a reroll nor a patch (the wave before it carried NO BREATHER).
func draft_actions_locked() -> bool:
	return false


## The crate on the field: { "contested": bool, "ticks_left": int (uncontested ticks until it is secured), "ticks_total":
## int, "life_left": int (ticks until it is lost; -1 = never), "x": float, "z": float }. Empty when no crate is out.
func crate_status() -> Dictionary:
	return {}


## The route option that spawns in the current wave, in the shape of route_option(). Empty before the first wave and
## on the legacy content; a boss wave has no pack ("name_key" is empty).
func wave_route() -> Dictionary:
	return {}


# --- 15-wave integration (V5-A; append only) ---


## True when the run counts the Archive unlock `id` (the unlocks the run started with; every one in a Daily Run). The
## field options read it: `u_f_boss_intel` (show act_boss() at the act start), `u_f_preview` (show route_preview()).
func has_unlock(id: StringName) -> bool:
	return false


## The boss of the act the player is in (between waves: of the next wave's act), in the shape of boss_brief(). Empty
## when the act has no boss and on the legacy content.
func act_boss() -> Dictionary:
	return {}


## Option `i` of the wave after next, in the shape of route_option(). Empty when that wave is a boss wave, does not
## exist or has no such option.
func route_preview(i: int) -> Dictionary:
	return {}
