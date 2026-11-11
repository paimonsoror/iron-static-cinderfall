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


static func from_os() -> DebugArgs:
	return parse(OS.get_cmdline_user_args())


static func parse(args: PackedStringArray) -> DebugArgs:
	var a: DebugArgs = DebugArgs.new()
	for raw: String in args:
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
			"--capture-frames":
				if value.is_valid_int():
					a.capture_frames = maxi(1, value.to_int())
	return a


## True when a single scene should be rendered to a PNG instead of booting the game.
func wants_capture() -> bool:
	return capture_scene != "" and capture_out != ""
