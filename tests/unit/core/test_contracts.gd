extends GdUnitTestSuite
## Enforces the signatures of ARCHITECTURE.md sections 4 to 10 (WORK_PLAN rule 2: never edit this file).
## Each row: path under res://src/ | methods | signals | variables | constants (comma separated).
## A contract is present when the script loads and lists every name. Static and instance methods both count.

const SHARED: Array[String] = [
	"shared/game_state.gd|name_of,is_run_phase,is_combat,is_terminal|||",
	"shared/game_state_machine.gd|can_transition,transition||current,previous,paused_from|",
	"shared/reason.gd|string_key|||",
	"shared/run_result.gd||||",
	"shared/damage_source.gd||||",
	"shared/ids.gd|enemy_index,weapon_index,upgrade_index,ability_index|||ENEMIES,WEAPONS,UPGRADES,ABILITIES,UP_DAMAGE,UP_FIRE_RATE,UP_ARMOR_PIERCING,UP_AUTO_TURRET,UP_SMG,AB_EMP,AB_SHIELD,AB_OVERDRIVE,EN_SKITTER,EN_HOLLOW,EN_RUSHER,EN_HULK",
]

const CONTENT: Array[String] = [
	"content/defs/mission_def.gd|||id,name_key,core_max_hp,ticks_per_second,enemy_cap,intermission_ticks,prepare_ticks,target_duration_min_s,target_duration_max_s,reward_victory_base,reward_core_hp_divisor,reward_defeat_per_wave,lock_ticks,eta_bucket_ticks,max_spawns_per_tick,stuck_ticks,stuck_min_progress_m|",
	"content/defs/enemy_def.gd||[]|id,index,name_key,hp,speed_mps,armor,core_damage,attack_period_ticks,scrap,radius,mass,separation_weight,weave_amp_m,weave_period_ticks,direct_seek,is_boss,priority_class,slot_span,visual_id,visual_height_m|",
	"content/defs/weapon_def.gd||[]|id,index,name_key,damage,sps_milli,magazine,reload_ticks,range_m|",
	"content/defs/upgrade_def.gd||[]|id,index,name_key,kind,base_cost,growth,max_level,per_level,cap,min_wave,weapon_index,turret_damage,turret_sps_milli,turret_range_m,turret_lock_ticks|",
	"content/defs/ability_def.gd||[]|id,index,name_key,cooldown_ticks,duration_ticks,cooldown_start,stun_ticks,boss_stun_ticks,boss_immunity_ticks,absorb,fire_rate_mult_milli|",
	"content/defs/spawn_group_def.gd||[]|enemy_index,count,start_tick,interval_ticks,region_id|",
	"content/defs/wave_def.gd|total_count|[]|index,peak_target,groups|",
	"content/defs/spawn_region_def.gd||[]|id,x0,z0,x1,z1|",
	"content/defs/obstacle_def.gd|contains|[]|id,shape,x,z,radius,size_x,size_z,rot_deg,visual|",
	"content/defs/arena_def.gd|region|[]|id,min_x,max_x,min_z,max_z,cell_m,margin_cells,core_x,core_z,core_radius,warden_x,warden_z,turret_pads,approach_radius,slot_positions,slot_ring,spawn_regions,obstacles,pitch_down_deg,yaw_deg,frame_margin_m,decor_yaw_deg|",
	"content/defs/visual_tokens.gd|color|[]|palette,top_hud_fraction,bottom_controls_fraction,touch_target_min_dp,text_contrast_target,down_angle_min_deg,down_angle_max_deg|",
	"content/defs/content_set.gd|enemy,weapon,upgrade,ability||mission,enemies,weapons,upgrades,abilities,waves,arena,tokens,strings|",
	"content/content_loader.gd|load_from_dir,build|||",
	"content/content_load_result.gd|||content,errors|",
	"content/content_validator.gd|validate|||",
	"content/content_db.gd|reload||db,load_errors|",
	"core/strings.gd|t,tf|||",
]

const SIM: Array[String] = [
	"sim/sim_world.gd|_init,step,submit,is_over,result,state_hash,summary,set_phase,add_scrap,spawn_enemy,kill_enemy,set_core_hp,alive_count,upgrade_cost,purchase_block_reason,ability_block_reason,boss_store_index||config,content,tick,phase,wave,waves_completed,phase_ticks_left,core_hp,core_max_hp,shield_hp,scrap,upgrade_levels,enemies,turrets,warden,abilities,nav,combat,phase_state,rng,events,stats,command_log,next_enemy_id|TICK_RATE,DT",
	"sim/sim_config.gd|create||run_seed,content,debug_invulnerable_core,debug_damage_mult,debug_start_scrap|",
	"sim/sim_command.gd|purchase,ability,skip||command_id,kind,arg,tick|",
	"sim/command_log.gd|to_dicts,from_dicts||entries|",
	"sim/sim_event.gd|||kind,tick,a,b,f,g|",
	"sim/sim_event_kind.gd||||",
	"sim/sim_events.gd|push,drain,peek||event_hash,total|",
	"sim/sim_rng.gd|_init,stream,hash_into|||",
	"sim/state_hasher.gd|put_int,put_float,put_ints,put_bytes,put_floats,finish|||",
	"sim/formulas.gd|ticks,upgrade_cost,effective_armor,hit_damage,sps_milli,data_reward|||",
	"sim/run_stats.gd|sample||kills_by_type,peak_alive_by_wave,wave_start_tick,wave_clear_tick,scrap_earned,scrap_spent,core_damage_taken,damage_absorbed,stuck_recoveries,max_pending|",
	"sim/run_summary.gd|||run_id,run_seed,result,waves_completed,core_hp,core_max_hp,duration_ticks,kills_by_type,peak_alive_by_wave,scrap_earned,scrap_spent,data_reward|",
	"sim/replay.gd|run|||",
	"sim/ai/policy_bot.gd|_init,act|||",
	"sim/stores/enemy_store.gd|_init,alloc,free_index,index_of,alive_count,hash_into||capacity,high_water,alive,id,type,x,z,prev_x,prev_z,face_x,face_z,hp,max_hp,state,slot,stun_ticks,stun_immune_ticks,attack_cd,path_dist,spawn_tick|ST_MOVING,ST_SEEK_SLOT,ST_ATTACKING",
	"sim/stores/warden_state.gd|hash_into||x,z,weapon_index,magazine,reload_ticks_left,fire_acc_milli,target_id,lock_ticks_left,aim_x,aim_z,shots_fired|",
	"sim/stores/turret_store.gd|active_count,hash_into||active,x,z,fire_acc_milli,target_id,lock_ticks_left,aim_x,aim_z|",
	"sim/stores/ability_state.gd|is_active,is_ready,hash_into||cooldown_left,active_left|",
	"sim/nav/arena_grid.gd|build,cell_of,cell_center||cols,rows,origin_x,origin_z,cell_m,blocked|",
	"sim/nav/flow_field.gd|build,sample_dir,sample_cost,unreachable_spawn_cells||grid,cost,dir_x,dir_z|",
	"sim/nav/spatial_hash.gd|rebuild,query|||",
	"sim/nav/attack_slots.gd|claim,release,occupant|||",
	"sim/nav/nav_state.gd|hash_into|||",
	"sim/nav/nav_system_hooks.gd|init_world,on_enemy_removed|||",
	"sim/systems/spawn_system.gd|begin_wave,step,is_wave_fully_spawned,pending_count|||",
	"sim/systems/movement_system.gd|step|||",
	"sim/systems/targeting.gd|pick,is_valid,compare|||",
	"sim/systems/damage_resolver.gd|hit|||",
	"sim/systems/weapon_system.gd|step,current_sps_milli|||",
	"sim/systems/turret_system.gd|step|||",
	"sim/systems/core_attack_system.gd|step|||",
	"sim/systems/combat_state.gd|hash_into|||",
	"sim/systems/command_system.gd|apply_queued|||",
	"sim/systems/economy_system.gd|purchase,block_reason,cost|||",
	"sim/systems/ability_system.gd|activate,block_reason,step|||",
	"sim/systems/phase_system.gd|init_world,pre_step,post_step,skip_intermission|||",
	"sim/systems/phase_state.gd|hash_into|||",
]

const GAME: Array[String] = [
	"core/event_bus.gd||state_changed,wave_started,enemy_spawned,enemy_damaged,enemy_killed,scrap_changed,core_changed,purchase_resolved,ability_activated,run_finished,run_started,wave_cleared,intermission_started,boss_spawned,shot_fired,enemy_died_at,core_hit,shield_changed,upgrade_level_changed,weapon_changed,turret_deployed,reload_started,reload_finished,ability_ended,ability_rejected,enemy_stunned,enemy_stuck,profile_changed,settings_changed,hint_requested||",
	"core/log.gd|info,warn,error|||",
	"core/game.gd|boot,goto_menu,goto_briefing,start_run,restart_run,pause_run,resume_run,quit_to_menu,open_settings,request_back,state||machine,run,battle_view|",
	"core/main.gd||||",
	"game/run_api.gd|next_command_id,purchase_upgrade,activate_ability,skip_intermission,pause,resume,is_paused,phase,wave,wave_count,phase_ticks_left,core_hp,core_max_hp,shield_hp,shield_max,scrap,upgrade_level,upgrade_max_level,upgrade_cost,purchase_block_reason,ability_block_reason,ability_cooldown_left,ability_cooldown_total,ability_active_left,ability_active_total,weapon_id,magazine,magazine_size,reload_ticks_left,alive_count,pending_spawn_count,boss_hp,boss_max_hp|||",
	"game/sim_run_api.gd|||controller|",
	"game/tick_driver.gd|advance,alpha||acc,dropped_ticks|MAX_TICKS_PER_FRAME",
	"game/run_controller.gd|start,set_paused,stop,_process||sim,api,run_id,paused,bot|",
	"game/mobile_shell.gd||||",
	"game/back_policy.gd|decide|||",
	"game/haptics.gd|tick|||",
	"save/save_manager.gd|use_fs,load_profile,flush,grant_run_reward,get_setting,set_setting,mark_hint_seen,has_seen_hint||profile,last_load_status|",
	"save/profile.gd|defaults||data,missions_completed,best_core_hp,runs_played,awarded_run_ids,hints_seen,settings|SCHEMA_VERSION",
	"save/profile_codec.gd|encode,decode|||",
	"save/profile_decode_result.gd|||profile,error,schema_version|",
	"save/save_fs.gd|read,write,exists,rename,remove|||",
	"save/disk_save_fs.gd|read,write,exists,rename,remove|||",
	"save/memory_save_fs.gd|read,write,exists,rename,remove|||",
	"audio/audio_director.gd|play,start_ambience,stop_ambience,set_intensity,pause_all,resume_all,apply_settings||disabled|",
]

const VIEW: Array[String] = [
	"view/battle_view.gd|setup,bind,unbind,render,fit_camera,world_to_screen,set_quality,set_reduced_flash||camera_rig,arena_view,actor_layer,vfx_layer|",
	"view/camera/camera_rig.gd|setup,fit,world_to_screen,pitch_down_deg||camera|",
	"view/camera/camera_fit.gd|solve|||",
	"view/camera/camera_fit_result.gd|||ortho_size,position,basis,px_per_meter|",
	"view/arena/arena_view.gd|setup,set_core_state,set_pad_state,set_quality|||",
	"view/actors/actor_layer.gd|setup,bind,unbind,render,set_quality,enemy_world_position|||",
	"view/vfx/vfx_layer.gd|setup,bind,unbind,render,set_quality,set_reduced_flash|||",
	"view/kit/visual_quality.gd|||",
	"view/kit/mat_lib.gd|mat,configure|||",
	"view/kit/mesh_builder.gd|box,cylinder,prism,sphere,quad,build|||",
	"view/kit/mesh_kit.gd|begin|||",
]

const UI: Array[String] = [
	"ui/kit/ui_theme.gd|build,color|||TOUCH_MIN,BTN_PRIMARY_H,FONT_SMALL,FONT_BODY,FONT_LARGE,FONT_TITLE",
	"ui/kit/ui_kit.gd|panel,button,label,icon,bar|||",
	"ui/kit/safe_area.gd|margins|||",
	"ui/kit/hud_layout.gd|top_band_px,bottom_band_px|||",
	"ui/screens/boot_screen.gd|setup|finished||",
	"ui/screens/main_menu_screen.gd|setup|start_pressed,settings_pressed,quit_pressed||",
	"ui/screens/briefing_screen.gd|setup|deploy_pressed,back_pressed||",
	"ui/screens/results_screen.gd|setup|retry_pressed,menu_pressed||",
	"ui/screens/settings_screen.gd|setup|closed||",
	"ui/combat/combat_hud.gd|setup,is_drawer_open,close_drawer,top_band_px,bottom_band_px|pause_requested||",
	"ui/combat/pause_overlay.gd|setup|resume_pressed,restart_pressed,settings_pressed,quit_pressed||",
]

const DEBUG: Array[String] = [
	"debug/debug_args.gd|parse|||",
	"debug/capture_runner.gd|||",
	"debug/sim_puppet.gd|setup|||",
	"debug/fake_run_api.gd|||calls|",
	"debug/perf_hud.gd|||",
]

const SCENES: Array[String] = [
	"res://scenes/main.tscn",
	"res://src/view/battle_view.tscn",
	"res://src/ui/screens/boot_screen.tscn",
	"res://src/ui/screens/main_menu_screen.tscn",
	"res://src/ui/screens/briefing_screen.tscn",
	"res://src/ui/screens/results_screen.tscn",
	"res://src/ui/screens/settings_screen.tscn",
	"res://src/ui/combat/combat_hud.tscn",
	"res://src/ui/combat/pause_overlay.tscn",
	"res://src/debug/view_sandbox.tscn",
	"res://src/debug/hud_sandbox.tscn",
]


## Names in the "name,name" column; "[]" and "" mean none.
func _names(column: String) -> PackedStringArray:
	if column == "" or column == "[]":
		return PackedStringArray()
	return column.split(",")


func _check_rows(rows: Array[String]) -> String:
	var problems: PackedStringArray = PackedStringArray()
	for row: String in rows:
		var cols: PackedStringArray = row.split("|")
		var path: String = "res://src/" + cols[0]
		var script: Script = load(path) as Script
		if script == null:
			problems.append("%s: script does not load" % path)
			continue
		var have_methods: Dictionary = {}
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			have_methods[mname] = true
		var have_signals: Dictionary = {}
		for s: Dictionary in script.get_script_signal_list():
			var sname: String = s["name"]
			have_signals[sname] = true
		var have_props: Dictionary = {}
		for p: Dictionary in script.get_script_property_list():
			var pname: String = p["name"]
			have_props[pname] = true
		var consts: Dictionary = script.get_script_constant_map()
		if cols.size() > 1:
			for n: String in _names(cols[1]):
				if not have_methods.has(n):
					problems.append("%s: missing method %s" % [path, n])
		if cols.size() > 2:
			for n: String in _names(cols[2]):
				if not have_signals.has(n):
					problems.append("%s: missing signal %s" % [path, n])
		if cols.size() > 3:
			for n: String in _names(cols[3]):
				if not have_props.has(n):
					problems.append("%s: missing variable %s" % [path, n])
		if cols.size() > 4:
			for n: String in _names(cols[4]):
				if not consts.has(n):
					problems.append("%s: missing constant %s" % [path, n])
	return "\n".join(problems)


func test_shared_contracts() -> void:
	assert_str(_check_rows(SHARED)).is_empty()


func test_content_contracts() -> void:
	assert_str(_check_rows(CONTENT)).is_empty()


func test_sim_contracts() -> void:
	assert_str(_check_rows(SIM)).is_empty()


func test_game_contracts() -> void:
	assert_str(_check_rows(GAME)).is_empty()


func test_view_contracts() -> void:
	assert_str(_check_rows(VIEW)).is_empty()


func test_ui_contracts() -> void:
	assert_str(_check_rows(UI)).is_empty()


func test_debug_contracts() -> void:
	assert_str(_check_rows(DEBUG)).is_empty()


func test_scenes_load_and_instantiate_their_root() -> void:
	for path: String in SCENES:
		var packed: PackedScene = load(path) as PackedScene
		assert_object(packed).is_not_null()
		var root: Node = packed.instantiate()
		assert_object(root).is_not_null()
		root.free()


func test_enum_members_exist() -> void:
	assert_int(GameState.Id.size()).is_equal(10)
	assert_int(Reason.Id.size()).is_equal(10)
	assert_int(RunResult.Id.size()).is_equal(4)
	assert_int(DamageSource.Id.size()).is_equal(3)
	assert_int(SimEventKind.Id.size()).is_equal(27)
	assert_int(SimCommand.Kind.size()).is_equal(3)
	assert_int(UpgradeDef.Kind.size()).is_equal(3)
	assert_int(AbilityDef.CooldownStart.size()).is_equal(2)
	assert_int(ObstacleDef.Shape.size()).is_equal(2)
	assert_int(PolicyBot.Policy.size()).is_equal(2)
	assert_int(BackPolicy.Action.size()).is_equal(7)
	assert_int(VisualQuality.Tier.size()).is_equal(3)
	assert_int(Save.LoadStatus.size()).is_equal(5)
	assert_int(DamageSource.Id.TURRET_1).is_equal(2)


func test_autoloads_are_registered() -> void:
	assert_object(Log).is_not_null()
	assert_object(Events).is_not_null()
	assert_object(Content).is_not_null()
	assert_object(Save).is_not_null()
	assert_object(Sfx).is_not_null()
	assert_object(Game).is_not_null()
	assert_object(Content.db).is_not_null()
	assert_int(Content.db.enemies.size()).is_equal(4)
