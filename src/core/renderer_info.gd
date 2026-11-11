class_name RendererInfo
extends RefCounted
## Names the renderer that is actually running, for the boot and capture log lines (ARCH D1).
## "mobile/vulkan" means the Mobile renderer on Vulkan; "gl_compatibility/opengl3" would be the fallback.


## `<rendering method>/<rendering driver>`, e.g. "mobile/vulkan".
static func current() -> String:
	return "%s/%s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name()]


## The GPU as the driver reports it (log line only; never parsed).
static func adapter() -> String:
	return RenderingServer.get_video_adapter_name()


## True when the Mobile renderer runs on Vulkan (or the headless dummy driver, which has no renderer).
static func is_vulkan_mobile() -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_current_rendering_driver_name() == "vulkan"
