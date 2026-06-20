extends Node

# Runtime side of the editor plugin. This autoload is intentionally small.
# It lets the editor change the running game's logical preview size without
# restarting, and captures only the game viewport for screenshots/recordings.
#
# Important: pure GDScript cannot encode MP4/H.264. Recording therefore saves
# a reliable PNG frame sequence from the same viewport path used by screenshots.
# This avoids the earlier invalid/black custom AVI writer and keeps the plugin
# dependency-free. MP4 should be added later with a native/GDExtension encoder.

const CONFIG_PATH := "user://game_preview_presets_runtime.cfg"
const CAPTURE_STATUS_CONFIG := "user://game_preview_presets_capture_status.cfg"
const DEFAULT_CAPTURE_DIR := "res://Captures"
const POLL_INTERVAL := 0.15

var _poll_time: float = 0.0
var _last_signature: String = ""
var _initial_size: Vector2i
var _initial_aspect: int
var _initial_mode: int
var _has_initial_state: bool = false

var _last_screenshot_id: int = 0
var _last_recording_id: int = 0
var _recording_state: String = "idle"
var _recording_paused: bool = false
var _recording_fps: int = 30
var _recording_interval: float = 1.0 / 30.0
var _recording_accum: float = 0.0
var _recording_dir: String = ""
var _recording_frames: int = 0
var _status_id: int = 0

func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		return
	var root: Window = get_tree().root
	_initial_size = root.content_scale_size
	_initial_aspect = root.content_scale_aspect
	_initial_mode = root.content_scale_mode
	_has_initial_state = true
	_apply_from_config()

func _exit_tree() -> void:
	if _recording_state != "idle":
		_finish_recording("Recording auto-saved on game exit")

func _process(delta: float) -> void:
	_poll_time += delta
	if _poll_time >= POLL_INTERVAL:
		_poll_time = 0.0
		_apply_from_config()
	_process_recording(delta)

func _apply_from_config() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(CONFIG_PATH)
	if err != OK:
		return
	_apply_preview_section(cfg)
	_handle_capture_section(cfg)

func _apply_preview_section(cfg: ConfigFile) -> void:
	var enabled: bool = bool(cfg.get_value("preview", "enabled", false))
	var width: int = int(cfg.get_value("preview", "width", 0))
	var height: int = int(cfg.get_value("preview", "height", 0))
	var mode: String = str(cfg.get_value("preview", "mode", "keep_aspect"))
	var force_scale_mode: bool = bool(cfg.get_value("preview", "force_scale_mode", false))
	var scale: float = float(cfg.get_value("preview", "scale", 1.0))
	var revision: int = int(cfg.get_value("preview", "revision", 0))
	var signature := "%s|%d|%d|%s|%s|%.3f|%d" % [str(enabled), width, height, mode, str(force_scale_mode), scale, revision]
	if signature == _last_signature:
		return
	_last_signature = signature

	var root: Window = get_tree().root
	if not enabled or width <= 0 or height <= 0 or mode == "free":
		_restore_initial(root)
		return

	var target := Vector2i(width, height)
	if mode == "fixed":
		target = Vector2i(max(1, int(round(float(width) * scale))), max(1, int(round(float(height) * scale))))

	if force_scale_mode:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

	root.content_scale_size = target
	match mode:
		"stretch":
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		"fixed", "keep_aspect":
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		_:
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	_write_status("Preview size applied: %d x %d (%s)" % [target.x, target.y, mode], _recording_state, "")

func _handle_capture_section(cfg: ConfigFile) -> void:
	var capture_dir: String = str(cfg.get_value("capture", "capture_dir", DEFAULT_CAPTURE_DIR))
	var screenshot_id: int = int(cfg.get_value("capture", "screenshot_id", 0))
	if screenshot_id > 0 and screenshot_id != _last_screenshot_id:
		_last_screenshot_id = screenshot_id
		_save_screenshot(capture_dir)

	var recording_id: int = int(cfg.get_value("capture", "recording_id", 0))
	var requested_state: String = str(cfg.get_value("capture", "recording_state", "idle"))
	_recording_fps = clampi(int(cfg.get_value("capture", "fps", 30)), 1, 60)
	_recording_interval = 1.0 / float(_recording_fps)

	if recording_id > 0 and recording_id != _last_recording_id and requested_state == "recording":
		_last_recording_id = recording_id
		_start_recording(capture_dir)
		return

	if _recording_state == "idle":
		return
	match requested_state:
		"recording":
			_recording_paused = false
			_recording_state = "recording"
			_write_status("Recording viewport frames", _recording_state, _recording_dir)
		"paused":
			_recording_paused = true
			_recording_state = "paused"
			_write_status("Recording paused", _recording_state, _recording_dir)
		"stopped":
			_finish_recording("Recording frames saved")
		_:
			pass

func _restore_initial(root: Window) -> void:
	if not _has_initial_state:
		return
	root.content_scale_size = _initial_size
	root.content_scale_aspect = _initial_aspect
	root.content_scale_mode = _initial_mode

func _timestamp() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [int(dt.year), int(dt.month), int(dt.day), int(dt.hour), int(dt.minute), int(dt.second)]

func _ensure_capture_dir(capture_dir: String) -> bool:
	var abs_dir: String = ProjectSettings.globalize_path(capture_dir)
	var err: Error = DirAccess.make_dir_recursive_absolute(abs_dir)
	if err != OK:
		_write_status("Could not create %s: %s" % [capture_dir, error_string(err)], _recording_state, "")
		return false
	return true

func _ensure_dir(path: String) -> bool:
	var err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		_write_status("Could not create %s: %s" % [path, error_string(err)], _recording_state, "")
		return false
	return true

func _capture_viewport_image() -> Image:
	# Capture the game viewport, not the editor. This is the same path used by the
	# working screenshot feature, so each recording frame is a real viewport image.
	var viewport: Viewport = get_viewport()
	var tex: ViewportTexture = viewport.get_texture()
	var image: Image = tex.get_image()
	return image

func _save_screenshot(capture_dir: String) -> void:
	if not _ensure_capture_dir(capture_dir):
		return
	var image: Image = _capture_viewport_image()
	if image.is_empty():
		_write_status("Screenshot failed: viewport image was empty", _recording_state, "")
		return
	var path: String = "%s/screenshot_%s.png" % [capture_dir, _timestamp()]
	var err: Error = image.save_png(path)
	if err == OK:
		_write_status("Screenshot saved: %s" % path, _recording_state, path)
	else:
		_write_status("Screenshot failed: %s" % error_string(err), _recording_state, "")

func _start_recording(capture_dir: String) -> void:
	if _recording_state != "idle":
		_finish_recording("Previous recording frames saved")
	if not _ensure_capture_dir(capture_dir):
		return
	_recording_dir = "%s/recording_%s" % [capture_dir, _timestamp()]
	if not _ensure_dir(_recording_dir):
		_recording_state = "idle"
		return
	_recording_frames = 0
	_recording_accum = 0.0
	_recording_paused = false
	_recording_state = "recording"
	_write_status("Recording started: %s" % _recording_dir, _recording_state, _recording_dir)
	_write_video_frame(_capture_viewport_image())

func _process_recording(delta: float) -> void:
	if _recording_state != "recording" or _recording_paused:
		return
	_recording_accum += delta
	if _recording_accum < _recording_interval:
		return
	_recording_accum = 0.0
	_write_video_frame(_capture_viewport_image())

func _write_video_frame(image: Image) -> void:
	if _recording_state == "idle" or image.is_empty() or _recording_dir.is_empty():
		return
	_recording_frames += 1
	var path: String = "%s/frame_%06d.png" % [_recording_dir, _recording_frames]
	var err: Error = image.save_png(path)
	if err != OK:
		_write_status("Recording frame failed: %s" % error_string(err), _recording_state, _recording_dir)

func _finish_recording(message: String) -> void:
	if _recording_state == "idle":
		return
	var saved_path: String = _recording_dir
	var info_path: String = "%s/recording_info.txt" % _recording_dir
	var info := FileAccess.open(info_path, FileAccess.WRITE)
	if info:
		info.store_line("Godot Game Preview Preset recording")
		info.store_line("Format: PNG frame sequence")
		info.store_line("Frames: %d" % _recording_frames)
		info.store_line("FPS: %d" % _recording_fps)
		info.store_line("Note: MP4/H.264 requires a native encoder or external conversion tool; pure GDScript cannot create real MP4 video.")
		info.close()
	_recording_state = "idle"
	_recording_paused = false
	_recording_dir = ""
	_write_status("%s: %s (%d PNG frames)" % [message, saved_path, _recording_frames], _recording_state, saved_path)

func _write_status(message: String, recording_state: String, path: String) -> void:
	_status_id += 1
	var cfg := ConfigFile.new()
	cfg.set_value("status", "id", _status_id)
	cfg.set_value("status", "message", message)
	cfg.set_value("status", "recording_state", recording_state)
	cfg.set_value("status", "path", path)
	cfg.save(CAPTURE_STATUS_CONFIG)
