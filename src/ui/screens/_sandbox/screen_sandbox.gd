class_name ScreenSandbox
extends Control
## Capture sandbox of the meta screens (not part of the game). Every scene under _sandbox/ is a bare Control with
## this script; the file name picks what is shown: boot, menu, briefing, results, results_defeat or settings, and a
## trailing "_hc" turns High Contrast on (in memory only, nothing is saved). Example:
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
