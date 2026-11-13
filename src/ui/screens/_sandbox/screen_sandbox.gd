class_name ScreenSandbox
extends Control
## Capture sandbox of the meta screens (not part of the game). Every scene under _sandbox/ is a bare Control with
## this script; the file name picks what is shown: boot, menu, briefing, results, results_defeat or settings, and a
## trailing "_hc" turns High Contrast on (in memory only, nothing is saved). V4-U: archive, archive_directives, archive_kits,
## archive_pending (the UNDO window), briefing_kits (the kit selector), menu_daily and results_run / results_run_won (the
## recap of a generated run). Example:
##   capture.ps1 -Scene res://src/ui/screens/_sandbox/menu_sandbox.tscn -Out build/shots/w2b_menu.png -Size 1080x2400

const SCREEN_DIR: String = "res://src/ui/screens/"

var _hc_forced: bool = false


func _ready() -> void:
	var which: String = scene_file_path.get_file().get_basename().trim_suffix("_sandbox")
	_hc_forced = which.ends_with("_hc")
	which = which.trim_suffix("_hc")
	if _hc_forced:
		Save.profile.settings[&"high_contrast"] = true
	UiKit.fill(self)
	match which:
		"boot":
			_boot()
		"briefing":
			_briefing()
		"results":
			_results(true)
		"results_defeat":
			_results(false)
		"settings":
			_settings()
		"archive", "archive_directives", "archive_kits", "archive_pending", "archive_poor":
			_archive(which)
		"briefing_kits":
			_briefing_kits()
		"menu_daily":
			_menu_daily()
		"results_run":
			_results_run(false)
		"results_run_won":
			_results_run(true)
		_:
			_menu()


func _exit_tree() -> void:
	if _hc_forced:
		Save.profile.settings[&"high_contrast"] = false


func _scene(file: String) -> Control:
	var packed: PackedScene = load(SCREEN_DIR + file) as PackedScene
	var node: Control = packed.instantiate() as Control
	add_child(node)
	return node


func _boot() -> void:
	var s: BootScreen = _scene("boot_screen.tscn") as BootScreen
	s.setup(str(ProjectSettings.get_setting("application/config/version")))


func _menu() -> void:
	var s: MainMenuScreen = _scene("main_menu_screen.tscn") as MainMenuScreen
	var profile: Profile = Profile.defaults()
	profile.data = 1250
	profile.best_core_hp = 620
	profile.missions_completed = 3
	s.setup(profile)


func _briefing() -> void:
	var s: BriefingScreen = _scene("briefing_screen.tscn") as BriefingScreen
	s.setup(Content.db)


func _settings() -> void:
	var s: SettingsScreen = _scene("settings_screen.tscn") as SettingsScreen
	s.setup()


func _results(won: bool) -> void:
	var s: ResultsScreen = _scene("results_screen.tscn") as ResultsScreen
	var summary: RunSummary = RunSummary.new()
	summary.run_id = "sandbox"
	summary.result = RunResult.Id.VICTORY if won else RunResult.Id.DEFEAT
	summary.waves_completed = 5 if won else 3
	summary.core_max_hp = 1000
	summary.core_hp = 620 if won else 0
	summary.duration_ticks = 16320 if won else 8400
	summary.kills_by_type = PackedInt32Array([88, 10, 18, 1] if won else [60, 6, 0, 0])
	summary.data_reward = 131 if won else 30
	var profile: Profile = Profile.defaults()
	profile.data = 1250
	s.setup(summary, Content.db, profile, true)
	s.finish_count_up()


## The Archive over a profile with 412 Data and three unlocks; the tab and the selection follow the scene name.
func _archive(which: String) -> void:
	SandboxArchiveContent.extend(Content.db)
	var profile: Profile = Profile.defaults()
	profile.data = 412
	profile.unlocks.append("u_w_hornet")
	profile.unlocks.append("u_p_blast")
	profile.unlocks.append("u_f_reroll")
	if which == "archive_poor":  # the profile of a first-time player: every row says how much Data it still needs
		profile.data = 40
		profile.unlocks = PackedStringArray()
	var s: ArchiveScreen = _scene("archive_screen.tscn") as ArchiveScreen
	s.setup(Content.db, ArchiveBank.new(profile, Content.db))
	match which:
		"archive_directives":
			s.select_branch(UnlockDef.Branch.DIRECTIVES)
		"archive_kits":
			s.select_branch(UnlockDef.Branch.KITS)
		"archive_pending":
			s.select(Content.db.unlock(&"u_w_mortar"))
			s.unlock_button.pressed.emit()  # the UNDO window is open


## The briefing of a generated run with the whole kit row (BREACHER owned and chosen).
func _briefing_kits() -> void:
	SandboxArchiveContent.extend(Content.db)
	Save.profile.unlocks.append("k_breacher")
	Save.profile.unlocks.append("k_signal")
	Save.profile.kit = &"k_breacher"
	var s: BriefingScreen = _scene("briefing_screen.tscn") as BriefingScreen
	s.setup(Content.db)


## The menu of a profile that has killed an act I boss: DAILY RUN and BEST WAVE show.
func _menu_daily() -> void:
	var s: MainMenuScreen = _scene("main_menu_screen.tscn") as MainMenuScreen
	var profile: Profile = Profile.defaults()
	profile.data = 412
	profile.best_core_hp = 620
	profile.missions_completed = 1
	s.setup(profile)
	s.set_resume_wave(3)
	s.daily_button.visible = true  # the boss kill is a v2 profile field: shown directly here
	s.daily_label.text = Strings.tf("menu.daily.best", [6])
	s.daily_label.visible = true


## The results of a generated run: the recap panels, a milestone, the Archive hook, the seed.
func _results_run(won: bool) -> void:
	SandboxArchiveContent.extend(Content.db)
	var cs: ContentSet = Content.db
	var s: ResultsScreen = _scene("results_screen.tscn") as ResultsScreen
	var summary: RunSummary = RunSummary.new()
	summary.run_id = "sandbox"
	summary.run_seed = 48211
	summary.result = RunResult.Id.VICTORY if won else RunResult.Id.DEFEAT
	summary.waves_completed = 5 if won else 3
	summary.act_reached = 1
	summary.core_max_hp = 1000
	summary.core_hp = 620 if won else 0
	summary.duration_ticks = 34920 if won else 17400
	summary.kills_by_type.resize(cs.enemies.size())
	summary.kills_by_type[Ids.EN_SKITTER] = 88
	summary.kills_by_type[Ids.EN_MOTE] = 140
	summary.kills_by_type[Ids.EN_HOLLOW] = 10
	summary.core_damage_by_type.resize(cs.enemies.size())
	if not won:
		summary.core_damage_by_type[Ids.EN_SKITTER] = 412.0
		summary.core_damage_by_type[Ids.EN_HOLLOW] = 260.0
		summary.core_damage_by_type[Ids.EN_BURSTER] = 90.0
	summary.events_seen.resize(cs.events.size())
	summary.directives.resize(cs.directives.size())
	for id: StringName in [&"hot_loads", &"cyclic_tuning", &"penetrator_cores", &"incendiary_tips"]:
		var index: int = cs.directive_index(id)
		if index >= 0:
			summary.directives[index] = 2 if id == &"hot_loads" else 1
	summary.weapons = PackedInt32Array([Ids.WEAPONS.find(&"arc_projector"), Ids.WEAPONS.find(&"pistol"), -1])
	summary.data_reward = 131 if won else 30
	var profile: Profile = Profile.defaults()
	profile.data = 242 if won else 130
	s.setup(summary, cs, profile, true)
	s.show_milestones([{"id": &"ms_first_boss_siege_hulk", "data": 50}] if won else [])
	s.finish_count_up()
