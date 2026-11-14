extends GdUnitTestSuite
## Enforces the signatures of ARCHITECTURE.md sections 4 to 10 (WORK_PLAN rule 2: never edit this file).
## Extended once by V1-S (VARIETY_SPEC 13.8: append only) with the contracts of the variety milestone: the VARIETY_*
## tables below, the appended enum values and the new autoload expectations.
## Extended by V5-A (the 15-wave integration, which owned the frozen contracts for that wave): the V5A table (what was
## appended to the event bus, the relay, the RunApi, the sim config and the stores) and the removal of the upgrade
## drawer from the CombatHud row.
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
	"save/save_manager.gd|use_fs,load_profile,flush,profile_dirty,grant_run_reward,get_setting,set_setting,mark_hint_seen,has_seen_hint||profile,last_load_status|",
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
	"ui/combat/combat_hud.gd|setup,top_band_px,bottom_band_px|pause_requested||",
	"ui/combat/pause_overlay.gd|setup|resume_pressed,restart_pressed,settings_pressed,quit_pressed||",
]

const DEBUG: Array[String] = [
	"debug/debug_args.gd|parse|||",
	"debug/capture_runner.gd|||",
	"debug/sim_puppet.gd|setup|||",
	"debug/fake_run_api.gd|||calls|",
	"debug/perf_hud.gd|||",
]

## --- variety milestone (VARIETY_SPEC 13.1 to 13.4), same row format ---
const VARIETY_SHARED_CONTENT: Array[String] = [
	"shared/ids.gd||||EN_MOTE,EN_SHARD,EN_BURSTER,EN_SPITTER,EN_SPLITTER,EN_SHIELDBEARER,EN_RECLAIMER,EN_JAMMER,EN_BORER,EN_WARD_PYLON,EN_BROOD_CARRIER,EN_LANCE_PLATFORM,EN_AEGIS_ARRAY,EN_TREMOR_RIG,WP_PISTOL,WP_SMG,WP_SCATTERGUN,WP_ASSAULT_RIFLE,WP_HORNET_RACK,WP_LMG,WP_SLAG_MORTAR,WP_CUTTING_TORCH,WP_ARC_PROJECTOR,WP_RAIL_LANCE,LEGACY_ENEMY_COUNT,LEGACY_WEAPON_COUNT",
	"shared/reason.gd||||KEYS,LEGACY_COUNT",
	"shared/damage_source.gd||||COUNT",
	"content/defs/enemy_def.gd|beh,is_mini||enemy_class,cost,min_act,alive_cap,standoff_m,behaviour|CLASS_NAMES",
	"content/defs/weapon_def.gd|is_heat||tier,kind,min_range_m,spread_deg,pierce,pierce_falloff,area_m,edge_frac,pellets,salvo,splash_damage,flight_ticks,chains,chain_range_m,chain_falloff,charge_ticks,heat_per_shot,cool_per_s,heat_cap,vent_ticks,armor_ignore,ward_mult,stunned_mult,spin_up_ticks,sps_min_milli,stray_chance,armor_shred,ramp_per_hit,ramp_cap,pool_ticks,pool_dps,pool_slow,pool_radius_m,knockback_m,level_mult,level3|KIND_NAMES",
	"content/defs/mission_def.gd|||swarm_cap,breather_ticks,shop_enabled|",
	"content/defs/arena_def.gd|||standoff_points,standoff_ring,standoff_radii,breach_points,drop_points,drum_points,rail_z,rail_half_width|",
	"content/defs/content_set.gd|is_variety,directive,directive_index,event_def,event_index,affix_index,boss,unlock,kit,kit_index||run,directives,events,unlocks,affixes,bosses,kits,turret_types|",
	"content/defs/run_def.gd|act,wave_slot,pack_index,modifier_index,reward_index,tier_weight||acts,waves,packs,modifiers,route_rewards,draft_offer_size,draft_skip_scrap,reroll_base,reroll_step,buyout_base,buyout_step,patch_frac,patch_base,patch_step,tag_lean,weapon_lean,repeat_penalty,rare_pity,salvage_secure_ticks,salvage_contest_radius_m,salvage_lifetime_ticks,salvage_bank_max,salvage_scrap_by_act,salvage_tier_weights,salvage_dupe_bias,swarm_cap,max_elites_alive,max_blasts_per_tick,reward_per_wave,reward_boss_by_act,reward_victory_base,reward_victory_core_bonus,swap_ticks,holster_reload_mult,elite_hp_mult,elite_scale,elite_scrap_mult,forbid_a,forbid_b,forbid_until_act,forbid_enemy,affix_two_chance,hulk_variants,event_window_min,event_window_max,mercy_core_frac,hazards,tier_gates,milestones|",
	"content/defs/act_def.gd|||id,index,name_key,hp_mult,core_dmg_mult,rarity_weights,corrupted_chance,elites_min,elites_max,affixes_min,affixes_max|",
	"content/defs/wave_slot_def.gd|||index,act,kind,budget,window_ticks,peak_bodied,peak_minis,event_slots,fixed_pack,fixed_pack_index|KIND_NAMES",
	"content/defs/pack_def.gd|group_count||id,index,name_key,min_act,budget_mult,extra_elites,group_enemy,group_share,group_region,group_start,group_tempo|",
	"content/defs/modifier_def.gd|||id,index,name_key,list,ops|LIST_NAMES",
	"content/defs/reward_def.gd|||id,index,name_key,weight_standard,weight_hot,ops|",
	"content/defs/directive_def.gd|||id,index,name_key,desc_key,category,rarity,max_stacks,tags,requires,ops,hook,pool|CATEGORY_NAMES,RARITY_NAMES,REQUIRE_KEYS",
	"content/defs/op_def.gd|amount,to_dict||kind,target,value,per_act,arg|STATS,FLAGS,GRANTS,AFFIX_STATS,AFFIX_FLAGS",
	"content/defs/event_def.gd|param||id,index,who,name_key,warn_ticks,duration_ticks,weights,boss_safe,harmful,params|WHO_NAMES",
	"content/defs/affix_def.gd|||id,index,name_key,ops|",
	"content/defs/boss_def.gd|beh||id,enemy_index,name_key,banner_key,pool_act,hp,behaviour,escort_enemy,escort_share,escort_pack|",
	"content/defs/unlock_def.gd|||id,index,name_key,branch,tier,cost,grants|BRANCH_NAMES",
	"content/defs/kit_def.gd|||id,index,name_key,cost,ops|",
	"content/defs/turret_type_def.gd|||id,index,name_key,damage,sps_milli,range_m,min_range_m,params|",
	"content/content_loader.gd|load_from_dir,build|||FILES,STRING_FILES,VARIETY_STRING_FILES,SCHEMA_ARENA_VARIETY",
	"content/variety_loader.gd|apply|||FILES,SCHEMA",
	"content/variety_run_loader.gd|run|||",
	"content/variety_units_loader.gd|weapons,enemies,elites_and_bosses|||",
	"content/variety_meta_loader.gd|directives,events,unlocks|||",
	"content/op_reader.gd|ops,rows,points,num_dict|||",
	"content/arena_builder.gd|build,point_is_free|||",
	"content/variety_validator.gd|validate,check_ops|||",
	"content/variety_arena_validator.gd|validate|||",
]

const VARIETY_SIM: Array[String] = [
	"sim/sim_world.gd|spawn_enemy,kill_enemy,set_core_max||plan,mods,arsenal,draft,salvage,ext,hazards,events_state,boss|",
	"sim/sim_config.gd|create,has_unlock||kit_index,unlocked,daily|",
	"sim/sim_command.gd|pick_directive,skip_draft,reroll,buy_out,patch_core,pick_route,salvage,swap_weapon,call_event|||",
	"sim/run_stats.gd|setup,sample||act_reached,combat_ticks,directives,weapons,route_choices,core_damage_by_type,damage_by_source,events_seen,crates_secured,boss_ids|",
	"sim/run_summary.gd|||act_reached,combat_ticks,directives,weapons,route_choices,core_damage_by_type,damage_by_source,events_seen,crates_secured,boss_ids|",
	"sim/snap_util.gd|hash_fields,to_dict,from_dict,num,ints,floats|||",
	"sim/world_snapshot.gd|capture,restore|||VERSION",
	"sim/plan/run_plan.gd|wave_count,wave,option,from_legacy,hash_into,to_dict,from_dict||boss_ids,boss_variant,waves,chosen,drum_points|",
	"sim/plan/planned_wave.gd|hash_into,to_dict,from_dict||index,act,is_boss,options,events|",
	"sim/plan/route_option.gd|total_count,hash_into,to_dict,from_dict||pack_index,modifier_index,reward_index,hot,groups,elites|",
	"sim/plan/planned_event.gd|hash_into,to_dict,from_dict||event_index,start_offset|",
	"sim/plan/planned_elite.gd|hash_into,to_dict,from_dict||group,ordinal,affix_mask|",
	"sim/stores/mod_state.gd|reset,stat,has_flag,set_flag,hash_into,to_dict,from_dict||flags,wave_modifier|",
	"sim/stores/draft_state.gd|stacks_of,hash_into,to_dict,from_dict||stacks,offer,last_offer,offer_ordinal,open,picks_left,rerolls_paid,free_rerolls,buyouts,bought_out,patches,offers_without_rare,turret_offered,next_rare,next_double,reroll_locked|FIELDS",
	"sim/stores/arsenal_state.gd|hash_into,to_dict,from_dict||slot_count,slot_weapon,slot_level,slot_magazine,slot_reload_left,slot_heat,slot_vent_left,active,swap_left,charge_left,spin_ticks,idle_ticks,beam_target,beam_hits,shots_since_proc,offhand_acc_milli|FIELDS,MAX_SLOTS",
	"sim/stores/salvage_state.gd|hash_into,to_dict,from_dict||crate_active,crate_boss,crate_x,crate_z,crate_point,crate_progress,crate_life_left,crate_ordinal,banked,crates_secured,offer,offer_boss,elite_kills|FIELDS",
	"sim/stores/enemy_ext_state.gd|reset,has_flag,is_elite,hash_into,to_dict,from_dict||capacity,flags,affix_mask,ward_milli,ward_regen_cd,slow_ticks,slow_milli,burn_ticks,burn_milli,shred_milli,fuse_ticks,aux_cd,anchor_point,hp_scale_milli|FIELDS,F_ELITE,F_MINI,F_ARMED,F_FIRED,F_EMERGING",
	"sim/stores/hazard_state.gd|queued,pool_count,hash_into,to_dict,from_dict||next_seq,q_due,q_seq,q_kind,q_source,q_flags,q_x,q_z,q_radius,q_damage,q_edge,next_pool_id,p_id,p_ticks_left,p_x,p_z,p_radius,p_dps,p_slow,m_x,m_z,m_owner,d_point,d_alive,d_damage_milli|FIELDS,K_BLAST,K_STRIKE,K_SHELL,K_MISSILE,K_BOLT,K_DRUM,K_MINE,K_VENT,K_FREIGHT",
	"sim/stores/event_state.gd|charges_of,active_count,hash_into,to_dict,from_dict||charges,used_this_wave,a_event,a_phase,a_ticks_left,a_x,a_z,plan_cursor,ability_lock_ticks,turret_offline_ticks,turret_rate_milli,turret_rate_ticks,scrap_mult_milli,scrap_mult_ticks,cancelled,last_world_event|FIELDS,PH_WARN,PH_ACTIVE",
	"sim/stores/boss_state.gd|hash_into,to_dict,from_dict||boss_id,boss_type,variant,phase,phase_count,timers,telegraph_attack,telegraph_left,flags,exposed_left,parts_alive|FIELDS",
	"sim/systems/phase_state.gd|hash_into||awaiting,act,breather|",
	"sim/systems/phase_system.gd|pick_route|||",
	"sim/systems/combat_state.gd|hash_into||shots_by_source,damage_by_source,kills_by_source,core_hits|SOURCES",
	"sim/systems/targeting.gd|pick_cluster,pick_many|||",
	"sim/systems/damage_resolver.gd|hit,hit_ex,heal|||F_IGNORE_ARMOR,F_HALF_ARMOR,F_AREA,F_NO_WARD,F_BURN",
	"sim/systems/run_plan_system.gd|build,patch|||",
	"sim/systems/wave_builder.gd|build|||",
	"sim/systems/draft_system.gd|open,generate_offer,pick,skip,reroll,buy_out,patch_core,reroll_cost,buyout_cost,patch_cost,build_tags|||",
	"sim/systems/mod_system.gd|init_world,recompute,apply_ops,grant,set_wave_modifier|||",
	"sim/systems/arsenal_system.gd|init_world,step,swap,give_weapon,level_up,weapon_of,slot_state|||ST_READY,ST_RELOADING,ST_VENTING,ST_SWAPPING,ST_CHARGING,ST_EMPTY",
	"sim/systems/fire/fire_hitscan.gd|fire|||",
	"sim/systems/fire/fire_cone.gd|fire|||",
	"sim/systems/fire/fire_arc.gd|fire|||",
	"sim/systems/fire/fire_line.gd|fire|||",
	"sim/systems/fire/fire_shell.gd|fire|||",
	"sim/systems/fire/fire_missiles.gd|fire|||",
	"sim/systems/fire/fire_beam.gd|fire|||",
	"sim/systems/area_damage.gd|blast|||",
	"sim/systems/hazard_system.gd|step,queue_hit,add_pool,clear|||",
	"sim/systems/status_system.gd|step,apply_slow,apply_burn|||",
	"sim/systems/death_hooks.gd|scrap_for,on_killed|||",
	"sim/systems/core_hooks.gd|on_core_hit,on_core_changed,allow_defeat,on_wave_cleared,on_ability,on_emp,on_shield_end|||",
	"sim/systems/shot_hooks.gd|on_warden_shot,on_warden_hit,on_warden_kill,on_turret_shot,on_turret_hit|||",
	"sim/systems/elite_system.gd|spawn_hp,apply,alive_elites|||",
	"sim/systems/event_system.gd|init_world,step,begin_wave,call_event,block_reason,dispatch|||",
	"sim/systems/events/event_deadfall_strike.gd|run|||",
	"sim/systems/events/event_core_vent.gd|run|||",
	"sim/systems/events/event_freight_call.gd|run|||",
	"sim/systems/events/event_accord_window.gd|run|||",
	"sim/systems/events/event_supply_drop.gd|run|||",
	"sim/systems/events/event_power_surge.gd|run|||",
	"sim/systems/events/event_runaway_freight.gd|run|||",
	"sim/systems/events/event_static_front.gd|run|||",
	"sim/systems/events/event_floor_breach.gd|run|||",
	"sim/systems/events/event_recount.gd|run|||",
	"sim/systems/boss_system.gd|step,on_spawned,phase_count|||",
	"sim/systems/bosses/boss_brood_carrier.gd|phase_count,begin,step|||",
	"sim/systems/bosses/boss_lance_platform.gd|phase_count,begin,step|||",
	"sim/systems/bosses/boss_aegis_array.gd|phase_count,begin,step|||",
	"sim/systems/bosses/boss_tremor_rig.gd|phase_count,begin,step|||",
	"sim/systems/bosses/boss_siege_hulk.gd|phase_count,begin,step|||",
	"sim/systems/salvage_system.gd|step,drop_crate,open_next,resolve,scrap_value|||ACTION_SLOT_0,ACTION_SLOT_1,ACTION_SLOT_2,ACTION_LEVEL_UP,ACTION_SCRAP",
	"sim/ai/policy_greedy.gd|act|||",
	"sim/ai/policy_random.gd|act|||",
	"sim/ai/policy_balanced.gd|act|||",
	"sim/ai/policy_hoarder.gd|act|||",
	"sim/ai/policy_spammer.gd|act|||",
	"sim/ai/policy_turret_rush.gd|act|||",
	"sim/ai/policy_risk.gd|act|||",
	"sim/ai/build_signature.gd|of|||",
	"sim/ai/scorecard.gd|evaluate|||",
]

const VARIETY_GAME: Array[String] = [
	"core/event_bus.gd||act_started,await_changed,draft_offered,directive_picked,route_offered,route_picked,crate_dropped,crate_secured,crate_lost,salvage_offered,weapon_swapped,weapon_vented,area_blast,chain_arc,delayed_hit,pool_changed,elite_spawned,ward_changed,event_warned,event_started,event_ended,boss_telegraph,boss_phase,charges_changed,command_rejected,unlock_purchased||",
	"core/game.gd|start_run,resume_run_from_disk,open_archive|||",
	"game/run_api.gd|pick_directive,skip_draft,reroll_draft,buy_out,patch_core,pick_route,resolve_salvage,swap_weapon,call_event,continue_run,awaiting,act,act_count,draft_offer,draft_reroll_cost,draft_buyout_cost,patch_cost,free_rerolls,route_option_count,route_option,boss_brief,salvage_offer,weapon_slot_count,weapon_slot,active_slot,event_charges,call_block_reason,active_events,directive_stacks,build_tags,boss_phase,boss_phase_count,run_seed|||AWAIT_NONE,AWAIT_SALVAGE,AWAIT_DRAFT,AWAIT_ROUTE,AWAIT_BOSS_BRIEF,SLOT_READY,SLOT_RELOADING,SLOT_VENTING,SLOT_SWAPPING,SLOT_CHARGING,SLOT_EMPTY,SALVAGE_LEVEL_UP,SALVAGE_SCRAP",
	"game/game_event_relay.gd|relay,tracked_count||world|NO_SIGNAL",
	"game/game_run_flow.gd|set_launch,apply_launch,resume_from_disk,open_archive|||",
	"ui/run/draft_overlay.gd|setup|||",
	"ui/run/route_overlay.gd|setup|||",
	"ui/run/boss_brief_overlay.gd|setup|||",
	"ui/run/salvage_overlay.gd|setup|||",
	"debug/fake_variety_api.gd|pick_directive,skip_draft,reroll_draft,buy_out,patch_core,pick_route,resolve_salvage,swap_weapon,call_event,continue_run||fake_awaiting,fake_act,fake_act_count,fake_draft_offer,fake_draft_ids,fake_draft_reroll_cost,fake_draft_buyout_cost,fake_patch_cost,fake_free_rerolls,fake_route_options,fake_boss_brief,fake_salvage_offer,fake_weapon_slots,fake_active_slot,fake_event_charges,fake_call_block,fake_active_events,fake_directive_stacks,fake_build_tags,fake_boss_phase,fake_boss_phase_count,fake_run_seed|",
	"debug/fake_run_presets.gd|apply,draft,route,boss_brief,salvage,combat2|||STATES",
	"debug/puppet_chaos.gd|setup,active,minis_alive,tick||minis,chain,boss,real_bodies,blasts,arcs|",
	"debug/sim_puppet.gd|setup,parse,advance,step_once||chaos|",
	"debug/hud_sandbox.gd|show_state,overlay,apply_step|||OVERLAY_SCENES",
	"debug/view_sandbox.gd|view_draws_variety|||",
	"debug/debug_args.gd|parse||hud_state,kit,unlock,daily|",
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
	"res://src/ui/run/draft_overlay.tscn",
	"res://src/ui/run/route_overlay.tscn",
	"res://src/ui/run/boss_brief_overlay.tscn",
	"res://src/ui/run/salvage_overlay.tscn",
]


## Names in the "name,name" column; "[]" and "" mean none.
## V5-A, appended to the frozen contracts (ARCH 6.3, 6.4, 7.1, 7.2, 7.4).
const V5A: Array[String] = [
	"core/event_bus.gd||weapon_charging,turret_removed||",
	"game/run_api.gd|has_unlock,act_boss,route_preview|||",
	"game/sim_run_api.gd|has_unlock,act_boss,route_preview|||",
	"game/sim_run_queries.gd|act_boss,boss_of_act,route_preview|||",
	"game/back_policy.gd|decide|||",
	"game/game_run_flow.gd|start_daily,start_same_seed,setup_results,close_screen_overlay|||",
	"game/game_launch.gd|start_wave_of,boss_of|||SCENARIO_WAVE,SCENARIO_BOSS",
	"game/run_file.gd|closing_reward,closing_cap|||",
	"sim/sim_config.gd|has_unlock,is_debug||debug_start_wave,debug_boss|",
	"sim/sim_world.gd|data_reward|||",
	"sim/run_stats.gd|add_data||data|",
	"sim/stores/arsenal_state.gd|||kill_chain_stacks,kill_chain_ticks|",
	"sim/systems/debug_start.gd|apply,force_boss|||BUILD",
	"sim/systems/events/turret_types.gd|id_of,special_of,fire_arc,step_mortar|||GUN,ARC,MORTAR",
	"sim/systems/run_plan_system.gd|set_boss|||",
	"sim/systems/arsenal_system.gd|open_slots|||",
	"sim/systems/arsenal_fire.gd|free_ammo,surge,dump_magazine|||",
	"sim/plan/phase_awaits.gd|bank_wave_data|||",
]


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


func test_variety_shared_and_content_contracts() -> void:
	assert_str(_check_rows(VARIETY_SHARED_CONTENT)).is_empty()


func test_variety_sim_contracts() -> void:
	assert_str(_check_rows(VARIETY_SIM)).is_empty()


func test_variety_game_ui_and_debug_contracts() -> void:
	assert_str(_check_rows(VARIETY_GAME)).is_empty()


func test_v5a_contracts() -> void:
	assert_str(_check_rows(V5A)).is_empty()
	# appended at the end of the event kinds: every older kind keeps its index
	assert_int(SimEventKind.Id.COMMAND_REJECTED).is_equal(59)
	assert_int(SimEventKind.Id.WEAPON_CHARGING).is_equal(60)
	assert_int(SimEventKind.Id.TURRET_REMOVED).is_equal(61)
	# the drawer is gone: the HUD has no drawer members and the back policy no drawer action
	var hud: Script = load("res://src/ui/combat/combat_hud.gd") as Script
	for m: Dictionary in hud.get_script_method_list():
		assert_bool(str(m["name"]).contains("drawer")).override_failure_message("CombatHud still has %s" % str(m["name"])).is_false()
	assert_bool(BackPolicy.Action.keys().has("CLOSE_DRAWER")).is_false()
	assert_bool(ResourceLoader.exists("res://src/ui/combat/hud_upgrade_drawer.gd")).is_false()
	assert_bool(ResourceLoader.exists("res://src/ui/combat/hud_upgrade_card.gd")).is_false()


## Append-only enums: every value keeps its index forever (VARIETY_SPEC 13.2).
func test_variety_enum_values_are_appended() -> void:
	assert_int(Reason.Id.PAUSED).is_equal(9)
	assert_int(Reason.Id.NOT_AWAITING).is_equal(10)
	assert_int(Reason.Id.INVALID_CHOICE).is_equal(11)
	assert_int(Reason.Id.NO_CHARGES).is_equal(12)
	assert_int(Reason.Id.LOCKED_BY_EVENT).is_equal(13)
	assert_int(Reason.Id.SHOP_CLOSED).is_equal(14)
	assert_int(DamageSource.Id.WARDEN_OFFHAND).is_equal(3)
	assert_int(DamageSource.Id.CORE).is_equal(4)
	assert_int(DamageSource.Id.STRIKE).is_equal(5)
	assert_int(DamageSource.Id.HAZARD).is_equal(6)
	assert_int(DamageSource.COUNT).is_equal(DamageSource.Id.size())
	assert_int(CombatState.SOURCES).is_equal(DamageSource.COUNT)
	assert_int(SimCommand.Kind.SKIP_INTERMISSION).is_equal(2)
	assert_int(SimCommand.Kind.PICK_DIRECTIVE).is_equal(3)
	assert_int(SimCommand.Kind.SKIP_DRAFT).is_equal(4)
	assert_int(SimCommand.Kind.REROLL).is_equal(5)
	assert_int(SimCommand.Kind.BUY_OUT).is_equal(6)
	assert_int(SimCommand.Kind.PATCH_CORE).is_equal(7)
	assert_int(SimCommand.Kind.PICK_ROUTE).is_equal(8)
	assert_int(SimCommand.Kind.SALVAGE).is_equal(9)
	assert_int(SimCommand.Kind.SWAP_WEAPON).is_equal(10)
	assert_int(SimCommand.Kind.CALL_EVENT).is_equal(11)
	assert_int(SimEventKind.Id.RUN_FINISHED).is_equal(26)
	assert_int(SimEventKind.Id.ACT_STARTED).is_equal(27)
	assert_int(SimEventKind.Id.AWAIT_CHANGED).is_equal(34)
	assert_int(SimEventKind.Id.AREA_BLAST).is_equal(41)
	assert_int(SimEventKind.Id.EVENT_WARNED).is_equal(51)
	assert_int(SimEventKind.Id.COMMAND_REJECTED).is_equal(59)
	assert_int(PhaseState.Await.NONE).is_equal(0)
	assert_int(PhaseState.Await.BOSS_BRIEF).is_equal(4)
	assert_int(PolicyBot.Policy.GREEDY).is_equal(1)
	assert_int(PolicyBot.Policy.RISK).is_equal(7)
	# RunApi mirrors the sim enums for the UI, which may not name sim classes.
	assert_int(RunApi.AWAIT_SALVAGE).is_equal(PhaseState.Await.SALVAGE)
	assert_int(RunApi.AWAIT_DRAFT).is_equal(PhaseState.Await.DRAFT)
	assert_int(RunApi.AWAIT_ROUTE).is_equal(PhaseState.Await.ROUTE)
	assert_int(RunApi.AWAIT_BOSS_BRIEF).is_equal(PhaseState.Await.BOSS_BRIEF)
	assert_int(RunApi.SLOT_READY).is_equal(ArsenalSystem.ST_READY)
	assert_int(RunApi.SLOT_EMPTY).is_equal(ArsenalSystem.ST_EMPTY)
	assert_int(RunApi.SALVAGE_LEVEL_UP).is_equal(SalvageSystem.ACTION_LEVEL_UP)
	assert_int(RunApi.SALVAGE_SCRAP).is_equal(SalvageSystem.ACTION_SCRAP)


## Every op name of the data grammar is a real ModState member (VARIETY_SPEC 13.1 "ops name real stats").
func test_every_op_stat_is_a_mod_state_field() -> void:
	var have: Dictionary = {}
	for p: Dictionary in (load("res://src/sim/stores/mod_state.gd") as Script).get_script_property_list():
		have[p["name"]] = true
	for stat_name: String in OpDef.STATS:
		assert_bool(have.has(stat_name)).override_failure_message("ModState has no field '%s'" % stat_name).is_true()
	assert_int(ModState.new().flags.size()).is_equal(OpDef.FLAGS.size())


func test_scenes_load_and_instantiate_their_root() -> void:
	for path: String in SCENES:
		var packed: PackedScene = load(path) as PackedScene
		assert_object(packed).is_not_null()
		var root: Node = packed.instantiate()
		assert_object(root).is_not_null()
		root.free()


func test_enum_members_exist() -> void:
	assert_int(GameState.Id.size()).is_equal(10)
	assert_int(Reason.Id.size()).is_equal(15)  # 10 + 5 (variety, append only)
	assert_int(RunResult.Id.size()).is_equal(4)
	assert_int(DamageSource.Id.size()).is_equal(7)  # 3 + 4
	assert_int(SimEventKind.Id.size()).is_equal(62)  # 27 + 33 + the 2 of V5-A
	assert_int(SimCommand.Kind.size()).is_equal(12)  # 3 + 9
	assert_int(UpgradeDef.Kind.size()).is_equal(3)
	assert_int(AbilityDef.CooldownStart.size()).is_equal(2)
	assert_int(ObstacleDef.Shape.size()).is_equal(2)
	assert_int(PolicyBot.Policy.size()).is_equal(8)  # 2 + 6
	assert_int(BackPolicy.Action.size()).is_equal(6)  # V5-A removed CLOSE_DRAWER with the drawer
	assert_int(VisualQuality.Tier.size()).is_equal(3)
	assert_int(Save.LoadStatus.size()).is_greater_equal(5)  # V2-D / V4-M append MIGRATED_FROM_V1
	assert_int(PhaseState.Await.size()).is_equal(5)
	assert_int(WeaponDef.Kind.size()).is_equal(7)
	assert_int(EnemyDef.BodyClass.size()).is_equal(3)
	assert_int(OpDef.Kind.size()).is_equal(4)
	assert_int(DirectiveDef.Category.size()).is_equal(6)
	assert_int(DirectiveDef.Rarity.size()).is_equal(4)
	assert_int(WaveSlotDef.Kind.size()).is_equal(3)
	assert_int(EventDef.Who.size()).is_equal(2)
	assert_int(UnlockDef.Branch.size()).is_equal(4)
	assert_int(EventSystem.Stage.size()).is_equal(4)
	assert_int(DamageSource.Id.TURRET_1).is_equal(2)


func test_autoloads_are_registered() -> void:
	assert_object(Log).is_not_null()
	assert_object(Events).is_not_null()
	assert_object(Content).is_not_null()
	assert_object(Save).is_not_null()
	assert_object(Sfx).is_not_null()
	assert_object(Game).is_not_null()
	assert_object(Content.db).is_not_null()
	assert_int(Content.db.enemies.size()).is_equal(Ids.ENEMIES.size())  # the shipped data is variety content
	assert_int(Content.db.weapons.size()).is_equal(Ids.WEAPONS.size())
	assert_object(Content.db.run).is_not_null()
