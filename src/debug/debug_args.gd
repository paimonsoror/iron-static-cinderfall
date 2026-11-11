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


## The user arguments after `--`, plus the words of the environment variable CINDERFALL_ARGS (desktop only). The
## variable is how a wrapper that cannot forward flags (tools/capture.ps1) still selects a scenario or a quality tier:
## `CINDERFALL_ARGS="--scenario=boss --quality=2" capture.ps1 ...`.
static func from_os() -> DebugArgs:
	var all: PackedStringArray = OS.get_cmdline_user_args()
	all.append_array(OS.get_environment("CINDERFALL_ARGS").split(" ", false))
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
