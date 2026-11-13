class_name DebugArgs
extends RefCounted
## Parses the user arguments after `--` (ARCH 11).

var has_seed: bool = false
var run_seed: int = 0
var autoplay: String = ""  ## "", "none" or "greedy"
var scenario: String = ""  ## e.g. "hold50"
var scenario_n: int = 0
var debug_perf: bool = false
var mute: bool = false
var quality: int = -1  ## -1 = not forced
var quit_after_run: bool = false
var capture_run: String = ""
var capture_scene: String = ""
var capture_out: String = ""
var capture_size: Vector2i = Vector2i(1080, 1920)
var capture_frames: int = 90
var debug_overlay: String = ""  ## "", "all" or a comma list of flow, slots, stuck, spawns (sandbox and Game debug root)
var high_contrast: bool = false
var reduced_flash: bool = false
var hud_step: int = -1  ## --hud-step=<n>: pin the HUD sandbox to one state instead of cycling
var hud: bool = false  ## --hud: the view sandbox draws the real CombatHud over the puppet's world (V5-B captures)
var second_weapon: String = ""  ## --weapon2=<id>: the puppet's Warden also carries this weapon (the HUD's weapon bar shows two)
## Variety milestone (VARIETY_SPEC 13.8). --state=draft|route|boss_brief|salvage|combat2 pins the HUD sandbox to a
## FakeRunPresets state; --kit=<id>, --unlock=all|none|<id,id>, --daily are parsed here and wired into the launch by V2-D.
var hud_state: String = ""
var kit: String = ""
var unlock: String = ""
var daily: bool = false
## Look-dev sandbox (W3-C): --look=current|stylised|stylised_plus (-1 = not forced), --zoom=<factor> (a top-down close-up of
## the Warden), --view=game|top|front|side (camera), --solo (hide the enemies), --reload-pose (hold the reload pose),
## --measure=<seconds> (quit after that long; the perf line is logged every 5 s with --debug-perf).
var look: int = -1
var zoom: float = 1.0
var view: String = ""
var solo: bool = false
var reload_pose: bool = false
var hide_warden: bool = false  ## --hide-warden: draw the scene without the Warden (the background half of a legibility pair)
var measure_s: float = 0.0
var render_size: Vector2i = Vector2i.ZERO  ## --render-size=1080x1920: render the sandbox in a SubViewport of that size (live runs)
var msaa: int = -1  ## --msaa=0|2|4: force the 3D viewport's MSAA (-1 = by look and tier, see LookDevStyle.msaa_samples)
var fxaa: int = -1  ## --fxaa=0|1: force FXAA off or on
var glow: int = -1  ## --glow=0|1: force bloom off or on for the cost measurement (-1 = by look and tier)
var tune: String = ""  ## --tune=name:value,name:value  shader parameter overrides of the stylised materials (look-dev; `e_<name>` = enemies only)
var rollout: int = -1  ## --rollout=0|1 (W3-D): 0 keeps the turret and the enemies in CURRENT while the Warden is styled (cost measurement)
var small_baked: int = -1  ## --small-baked=0|1 (W3-D): 0 = the shader on every enemy kind on MID and HIGH (cost measurement)
var focus: String = ""  ## --focus=warden|skitter|hollow_warden|rusher|siege_hulk|turret (W3-D): close-up and solo cameras follow that actor
var env: String = ""  ## --env=off|only:a,b|no:a,b  switches single effects of the styled yard (EnvStyle) for the cost measurement
var env_tune: String = ""  ## --env-tune=name:value,...  floor shader parameter overrides (EnvGround.overrides)
var cam_pitch: float = 0.0  ## --cam-pitch=<degrees>  sandbox-only camera pitch experiment (0 = the game camera)
var cam_persp: float = 0.0  ## --cam-persp=<fov degrees>  sandbox-only perspective camera for the camera study (0 = orthographic)
var cam_report: bool = false  ## --cam-report: log one line of camera numbers shortly before the capture frame
## Sound switches for bisecting an audio problem on a device (GameAudioDebug): --sfx=0|1 and --music=0|1 override the saved
## settings (-1 = not forced), --loop-trim=<frames> pulls the beds' loop end back, --loop-off plays the beds once,
## --audio-trace logs every started sound.
var sfx: int = -1
var music: int = -1
var loop_trim: int = 0
var loop_off: bool = false
var audio_trace: bool = false
## --shots=<dir>: the screenshot run of the real game (src/debug/game_shots.tscn, V3-I) saves its PNGs there.
var shots: String = ""

## Extra arguments for a DEBUG build on a device (one line, blank separated), read when the file exists: the way to change
## the flags of an exported APK without rebuilding it (`adb shell run-as <package> ...` writes it into the app's files).
const ARGS_FILE: String = "user://cinderfall_args.txt"


## The user arguments after `--`, plus the words of the environment variable CINDERFALL_ARGS (desktop only). The
## variable is how a wrapper that cannot forward flags (tools/capture.ps1) still selects a scenario or a quality tier:
## `CINDERFALL_ARGS="--scenario=boss --quality=2" capture.ps1 ...`.
static func from_os() -> DebugArgs:
	var all: PackedStringArray = OS.get_cmdline_user_args()
	all.append_array(OS.get_environment("CINDERFALL_ARGS").split(" ", false))
	if OS.is_debug_build() and FileAccess.file_exists(ARGS_FILE):
		all.append_array(FileAccess.get_file_as_string(ARGS_FILE).replace("\n", " ").replace("\r", " ").split(" ", false))
	return parse(all)


## A single argument that carries several flags (`--capture-scene=res://x.tscn --scenario=boss`, which is what a
## `-Scene "<path> <flags>"` of capture.ps1 delivers) is split at its whitespace.
static func expand(args: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for raw: String in args:
		if raw.begins_with("--") and raw.contains(" --"):
			out.append_array(raw.split(" ", false))
		else:
			out.append(raw)
	return out


static func parse(args: PackedStringArray) -> DebugArgs:
	var a: DebugArgs = DebugArgs.new()
	for raw: String in expand(args):
		var key: String = raw
		var value: String = ""
		var eq: int = raw.find("=")
		if eq >= 0:
			key = raw.substr(0, eq)
			value = raw.substr(eq + 1)
		match key:
			"--seed":
				if value.is_valid_int():
					a.has_seed = true
					a.run_seed = value.to_int()
			"--autoplay":
				a.autoplay = "greedy" if value == "" else value
			"--scenario":
				a.scenario = value
				if value.begins_with("hold") and value.substr(4).is_valid_int():
					a.scenario_n = value.substr(4).to_int()
			"--debug-perf":
				a.debug_perf = true
			"--mute":
				a.mute = true
			"--sfx":
				if value == "0" or value == "1":
					a.sfx = value.to_int()
			"--music":
				if value == "0" or value == "1":
					a.music = value.to_int()
			"--loop-trim":
				if value.is_valid_int():
					a.loop_trim = maxi(0, value.to_int())
			"--loop-off":
				a.loop_off = true
			"--audio-trace":
				a.audio_trace = true
			"--shots":
				a.shots = value
			"--quality":
				if value.is_valid_int():
					a.quality = clampi(value.to_int(), 0, 2)
			"--quit-after-run":
				a.quit_after_run = true
			"--capture-run":
				a.capture_run = value
			"--capture-scene":
				a.capture_scene = value
			"--capture-out":
				a.capture_out = value
			"--capture-size":
				var parts: PackedStringArray = value.split("x")
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
					a.capture_size = Vector2i(parts[0].to_int(), parts[1].to_int())
			"--debug-overlay":
				a.debug_overlay = "all" if value == "" else value
			"--high-contrast":
				a.high_contrast = true
			"--reduced-flash":
				a.reduced_flash = true
			"--look":
				var picked: int = LookDevStyle.from_name(value)
				if picked >= 0:
					a.look = picked
			"--zoom":
				if value.is_valid_float():
					a.zoom = clampf(value.to_float(), 0.25, 12.0)
			"--view":
				a.view = value.to_lower()
			"--render-size":
				var rs: PackedStringArray = value.split("x")
				if rs.size() == 2 and rs[0].is_valid_int() and rs[1].is_valid_int():
					a.render_size = Vector2i(rs[0].to_int(), rs[1].to_int())
			"--glow":
				if value == "0" or value == "1":
					a.glow = value.to_int()
			"--msaa":
				if value == "0" or value == "2" or value == "4":
					a.msaa = value.to_int()
			"--fxaa":
				if value == "0" or value == "1":
					a.fxaa = value.to_int()
			"--tune":
				a.tune = value
			"--rollout":
				if value == "0" or value == "1":
					a.rollout = value.to_int()
			"--small-baked":
				if value == "0" or value == "1":
					a.small_baked = value.to_int()
			"--focus":
				a.focus = value.to_lower()
			"--env":
				a.env = value
			"--env-tune":
				a.env_tune = value
			"--cam-pitch":
				if value.is_valid_float():
					a.cam_pitch = clampf(value.to_float(), 20.0, 89.0)
			"--cam-report":
				a.cam_report = true
			"--cam-persp":
				if value.is_valid_float():
					a.cam_persp = clampf(value.to_float(), 0.0, 90.0)
			"--solo":
				a.solo = true
			"--hide-warden":
				a.hide_warden = true
			"--reload-pose":
				a.reload_pose = true
			"--measure":
				if value.is_valid_float():
					a.measure_s = maxf(value.to_float(), 0.0)
			"--state":
				a.hud_state = value.to_lower()
			"--kit":
				a.kit = value
			"--unlock":
				a.unlock = value
			"--daily":
				a.daily = true
			"--hud":
				a.hud = true
			"--weapon2":
				a.second_weapon = value
			"--hud-step":
				if value.is_valid_int():
					a.hud_step = maxi(0, value.to_int())
			"--capture-frames":
				if value.is_valid_int():
					a.capture_frames = maxi(1, value.to_int())
	return a


## True when a single scene should be rendered to a PNG instead of booting the game.
func wants_capture() -> bool:
	return capture_scene != "" and capture_out != ""
