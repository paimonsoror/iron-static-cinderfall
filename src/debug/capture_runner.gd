class_name CaptureRunner
extends Node
## Renders one scene in a SubViewport of the requested size, saves a PNG after N frames, quits (ARCH 11).
## Prints `capture renderer=...` and `CAPTURE SAVED <path> ...`; tools/capture.ps1 turns those into CAPTURE OK.
## A blank image prints an ERROR line and quits with code 3.

var _args: DebugArgs
var _viewport: SubViewport
var _frames: int = 0
var _done: bool = false


func setup(args: DebugArgs) -> void:
	_args = args


func _ready() -> void:
	Log.info("capture", "renderer=%s adapter=%s" % [RendererInfo.current(), RendererInfo.adapter()])
	var packed: PackedScene = load(_args.capture_scene) as PackedScene
	if packed == null:
		_fail("cannot load scene %s" % _args.capture_scene, 2)
		return
	_viewport = SubViewport.new()
	_viewport.size = _args.capture_size
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_viewport.add_child(packed.instantiate())


func _process(_delta: float) -> void:
	if _done or _viewport == null:
		return
	_frames += 1
	if _frames < _args.capture_frames:
		return
	_done = true
	_save.call_deferred()


func _save() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = _viewport.get_texture().get_image()
	if img == null or img.is_empty():
		_fail("viewport texture is empty", 3)
		return
	DirAccess.make_dir_recursive_absolute(_args.capture_out.get_base_dir())
	var err: int = img.save_png(_args.capture_out)
	if err != OK:
		_fail("save_png failed (%d) for %s" % [err, _args.capture_out], 4)
		return
	var distinct: int = _distinct_colors(img)
	if distinct < 4:
		_fail("image looks blank (%d distinct colors)" % distinct, 3)
		return
	print("CAPTURE SAVED %s size=%dx%d distinct=%d" % [_args.capture_out, img.get_width(), img.get_height(), distinct])
	get_tree().quit(0)


## Distinct colors among a sparse sample of pixels, quantized to 4 bits per channel.
func _distinct_colors(img: Image) -> int:
	var seen: Dictionary = {}
	var step_x: int = maxi(1, floori(float(img.get_width()) / 64.0))
	var step_y: int = maxi(1, floori(float(img.get_height()) / 64.0))
	for y: int in range(0, img.get_height(), step_y):
		for x: int in range(0, img.get_width(), step_x):
			var c: Color = img.get_pixel(x, y)
			var key: int = (int(c.r * 15.0) << 8) | (int(c.g * 15.0) << 4) | int(c.b * 15.0)
			seen[key] = true
	return seen.size()


func _fail(msg: String, code: int) -> void:
	_done = true
	Log.error("Capture", msg)
	get_tree().quit(code)
