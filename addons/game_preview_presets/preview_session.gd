@tool
extends RefCounted

signal status_changed(message: String)

const WINDOW_WIDTH := "display/window/size/viewport_width"
const WINDOW_HEIGHT := "display/window/size/viewport_height"
const WIDTH_OVERRIDE := "display/window/size/window_width_override"
const HEIGHT_OVERRIDE := "display/window/size/window_height_override"
const WINDOW_MODE := "display/window/size/mode"

# Godot's embedded Game toolbar is official UX, but these EditorSettings names
# have changed across 4.x builds and are not yet a stable public plugin API.
# The plugin tries all known names and only writes keys that already exist.
const EMBED_SETTING_CANDIDATES := [
	"run/window_placement/embed_on_play",
	"run/window_placement/embed_game_on_next_play",
	"run/game_embed/embed_on_play",
	"run/game_embed/embed_game_on_next_play",
	"run/game_embed/embed_game_on_next_play_enabled",
]
const FLOAT_SETTING_CANDIDATES := [
	"run/window_placement/make_window_floating_on_play",
	"run/window_placement/make_game_window_floating_on_next_play",
	"run/game_embed/make_window_floating_on_next_play",
	"run/game_embed/floating_window",
	"run/game_embed/make_game_workspace_floating_on_next_play",
]
const SIZING_SETTING_CANDIDATES := [
	"run/window_placement/embedded_window_size_mode",
	"run/game_embed/embedded_window_size_mode",
	"run/game_embed/window_sizing_mode",
	"run/game_embed/game_window_size_mode",
]

var editor_interface: EditorInterface
var preset_manager: RefCounted
var active_preset: Dictionary = {"name": "Project Current", "width": 0, "height": 0, "mode": "keep_aspect"}
var scale := 1.0
var embed_on_play := true
var floating := false
var focus_on_play := true
var mute_audio := false
var debug_overlay := "off"
var temporary_windowed_fallback := true
var live_update_while_playing := true
var force_scale_mode_if_disabled := true
const RUNTIME_CONFIG := "user://game_preview_presets_runtime.cfg"
const CAPTURE_STATUS_CONFIG := "user://game_preview_presets_capture_status.cfg"
const CAPTURE_DIR := "res://Captures"

# Unity-style behavior: the selected size is passed to the run process for the
# next play only. It is not saved to project.godot. Turn it off to only use the
# editor Game tab's visual fit with the project's existing base viewport.
var override_runtime_viewport := true

var _editor_setting_backup: Dictionary = {}
var _project_setting_backup: Dictionary = {}
var _prepared := false
var _capture_command_id: int = 0
var _recording_id: int = 0
var _recording_state: String = "idle"
var _last_capture_status_id: int = -1
var _live_revision: int = 0

func setup(p_editor_interface: EditorInterface, p_preset_manager: RefCounted) -> void:
	editor_interface = p_editor_interface
	preset_manager = p_preset_manager
	if int(active_preset.get("width", 0)) == 0 and preset_manager and preset_manager.has_method("project_width"):
		active_preset["width"] = preset_manager.project_width()
		active_preset["height"] = preset_manager.project_height()

func set_active_preset(preset: Dictionary) -> void:
	active_preset = preset.duplicate(true)
	publish_live_preview()
	emit_signal("status_changed", describe_current_preview())

func describe_current_preview() -> String:
	var w := int(active_preset.get("width", 0))
	var h := int(active_preset.get("height", 0))
	var mode := str(active_preset.get("mode", "keep_aspect"))
	if w <= 0 or h <= 0 or mode == "free":
		return "Free size - embedded surface follows the Game tab/window"
	var suffix := ""
	if override_runtime_viewport:
		suffix = " - next play uses this resolution"
	else:
		suffix = " - visual fit only, runtime keeps Project Settings"
	if mode == "fixed":
		return "%d x %d  (%s)  Fixed Size @ %.0f%%%s" % [w, h, aspect_label(w, h), scale * 100.0, suffix]
	if mode == "keep_aspect":
		return "%d x %d  (%s)  Keep Aspect Ratio / Fit%s" % [w, h, aspect_label(w, h), suffix]
	if mode == "stretch":
		return "%d x %d  (%s)  Stretch to Fit%s" % [w, h, aspect_label(w, h), suffix]
	return "%d x %d  (%s)%s" % [w, h, aspect_label(w, h), suffix]

func aspect_label(width: int, height: int) -> String:
	if height <= 0:
		return "free"
	var g := _gcd(width, height)
	return "%d:%d" % [width / g, height / g]

func prepare_run_args(_scene: String, args: PackedStringArray) -> PackedStringArray:
	_project_setting_backup.clear()
	_editor_setting_backup.clear()
	_prepared = true

	apply_editor_embedding_settings()
	publish_live_preview()
	var out := PackedStringArray(args)

	var w := int(active_preset.get("width", 0))
	var h := int(active_preset.get("height", 0))
	var mode := str(active_preset.get("mode", "keep_aspect"))

	if embed_on_play and _is_fullscreen_project() and temporary_windowed_fallback:
		_append_unique(out, "--windowed")
		emit_signal("status_changed", "Fullscreen projects are run windowed for embedded preview. Use normal Play for fullscreen validation.")

	if w > 0 and h > 0 and mode != "free":
		# This is the important Unity-style split:
		# - Keep Aspect / Stretch: change the requested runtime resolution only,
		#   then let Godot's built-in Game tab fit it visually.
		# - Fixed Size: intentionally request a scaled pixel size, useful for
		#   pixel-perfect checks when the editor panel is smaller than the device.
		# We do not permanently save anything. ProjectSettings changes here are
		# only in-memory for the launched process and are restored after play stops.
		if override_runtime_viewport:
			match mode:
				"fixed":
					var scaled_w := max(1, int(round(float(w) * scale)))
					var scaled_h := max(1, int(round(float(h) * scale)))
					_temp_project_set(WINDOW_WIDTH, scaled_w)
					_temp_project_set(WINDOW_HEIGHT, scaled_h)
					_temp_project_set(WIDTH_OVERRIDE, scaled_w)
					_temp_project_set(HEIGHT_OVERRIDE, scaled_h)
					_append_pair(out, "--resolution", "%dx%d" % [scaled_w, scaled_h])
				"keep_aspect", "stretch":
					_temp_project_set(WINDOW_WIDTH, w)
					_temp_project_set(WINDOW_HEIGHT, h)
					# Clear window overrides so the embedded Game tab can fit instead of crop.
					_temp_project_set(WIDTH_OVERRIDE, 0)
					_temp_project_set(HEIGHT_OVERRIDE, 0)
					_append_pair(out, "--resolution", "%dx%d" % [w, h])
				_:
					pass

	if mute_audio:
		_append_pair(out, "--audio-driver", "Dummy")

	match debug_overlay:
		"fps":
			_append_unique(out, "--print-fps")
		"collisions":
			_append_unique(out, "--debug-collisions")
		"navigation":
			_append_unique(out, "--debug-navigation")
		"paths":
			_append_unique(out, "--debug-paths")

	if focus_on_play and editor_interface:
		editor_interface.set_main_screen_editor("Game")

	emit_signal("status_changed", "Running preview: " + describe_current_preview())
	return out

func restore_after_play() -> void:
	if not _prepared:
		return
	for k in _project_setting_backup.keys():
		ProjectSettings.set_setting(k, _project_setting_backup[k])
	if editor_interface:
		var settings := editor_interface.get_editor_settings()
		for k in _editor_setting_backup.keys():
			if settings.has_setting(k):
				settings.set_setting(k, _editor_setting_backup[k])
	_project_setting_backup.clear()
	_editor_setting_backup.clear()
	_prepared = false
	_disable_live_preview()
	_recording_state = "idle"
	emit_signal("status_changed", "Preview stopped. Temporary settings restored.")

func apply_selected_to_project() -> Error:
	var w := int(active_preset.get("width", 0))
	var h := int(active_preset.get("height", 0))
	if w <= 0 or h <= 0:
		emit_signal("status_changed", "Free preset has no fixed project size to apply.")
		return ERR_INVALID_DATA
	ProjectSettings.set_setting(WINDOW_WIDTH, w)
	ProjectSettings.set_setting(WINDOW_HEIGHT, h)
	ProjectSettings.set_setting(WIDTH_OVERRIDE, 0)
	ProjectSettings.set_setting(HEIGHT_OVERRIDE, 0)
	var err := ProjectSettings.save()
	if err == OK:
		emit_signal("status_changed", "Applied %d x %d to Project Settings." % [w, h])
	return err

func publish_live_preview(force: bool = false) -> void:
	if not live_update_while_playing and not force:
		return
	_live_revision += 1
	var cfg := ConfigFile.new()
	var mode := str(active_preset.get("mode", "keep_aspect"))
	var w := int(active_preset.get("width", 0))
	var h := int(active_preset.get("height", 0))
	var enabled := bool(override_runtime_viewport and w > 0 and h > 0 and mode != "free")
	cfg.set_value("preview", "enabled", enabled)
	cfg.set_value("preview", "width", w)
	cfg.set_value("preview", "height", h)
	cfg.set_value("preview", "mode", mode)
	cfg.set_value("preview", "force_scale_mode", force_scale_mode_if_disabled)
	cfg.set_value("preview", "scale", scale)
	cfg.set_value("preview", "revision", _live_revision)
	cfg.set_value("preview", "note", "Written by the Godot Game Preview Preset editor plugin for live Unity-style Game view switching.")
	var err: Error = cfg.save(RUNTIME_CONFIG)
	if err != OK:
		emit_signal("status_changed", "Could not write live preview config: %s" % error_string(err))

func _disable_live_preview() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("preview", "enabled", false)
	cfg.set_value("preview", "width", 0)
	cfg.set_value("preview", "height", 0)
	cfg.set_value("preview", "mode", "free")
	cfg.set_value("preview", "force_scale_mode", false)
	cfg.set_value("preview", "scale", 1.0)
	cfg.save(RUNTIME_CONFIG)

func request_screenshot() -> void:
	_capture_command_id += 1
	_write_capture_command("screenshot")
	emit_signal("status_changed", "Screenshot requested. It will save to res://Captures from the running game viewport.")

func start_recording() -> void:
	_recording_id += 1
	_recording_state = "recording"
	_write_capture_command("recording")
	emit_signal("status_changed", "Recording started. Capturing viewport frames to res://Captures.")

func pause_recording() -> void:
	if _recording_state != "recording":
		return
	_recording_state = "paused"
	_write_capture_command("recording")
	emit_signal("status_changed", "Recording paused.")

func resume_recording() -> void:
	if _recording_state != "paused":
		return
	_recording_state = "recording"
	_write_capture_command("recording")
	emit_signal("status_changed", "Recording resumed.")

func stop_recording() -> void:
	if _recording_state == "idle":
		return
	_recording_state = "stopped"
	_write_capture_command("recording")
	emit_signal("status_changed", "Recording stop requested. The file will auto-save in res://Captures.")

func is_recording() -> bool:
	return _recording_state == "recording"

func is_recording_paused() -> bool:
	return _recording_state == "paused"

func poll_capture_status() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(CAPTURE_STATUS_CONFIG)
	if err != OK:
		return
	var status_id: int = int(cfg.get_value("status", "id", -1))
	if status_id == _last_capture_status_id:
		return
	_last_capture_status_id = status_id
	var message: String = str(cfg.get_value("status", "message", ""))
	var state: String = str(cfg.get_value("status", "recording_state", _recording_state))
	if state == "idle" and _recording_state == "stopped":
		_recording_state = "idle"
	elif state == "recording" or state == "paused":
		_recording_state = state
	if not message.is_empty():
		emit_signal("status_changed", message)

func _write_capture_command(kind: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(RUNTIME_CONFIG)
	cfg.set_value("capture", "command_kind", kind)
	cfg.set_value("capture", "screenshot_id", _capture_command_id)
	cfg.set_value("capture", "recording_id", _recording_id)
	cfg.set_value("capture", "recording_state", _recording_state)
	cfg.set_value("capture", "capture_dir", CAPTURE_DIR)
	cfg.set_value("capture", "fps", 30)
	var err: Error = cfg.save(RUNTIME_CONFIG)
	if err != OK:
		emit_signal("status_changed", "Could not write capture command: %s" % error_string(err))

func restore_defaults() -> void:
	if preset_manager and preset_manager.has_method("project_width"):
		active_preset = {"name": "Project Current", "width": preset_manager.project_width(), "height": preset_manager.project_height(), "mode": "keep_aspect", "builtin": true}
	else:
		active_preset = {"name": "Project Current", "width": 0, "height": 0, "mode": "keep_aspect", "builtin": true}
	scale = 1.0
	embed_on_play = true
	floating = false
	focus_on_play = true
	mute_audio = false
	debug_overlay = "off"
	override_runtime_viewport = true
	apply_editor_embedding_settings()
	emit_signal("status_changed", "Restored Godot Game Preview Preset defaults.")

func apply_editor_embedding_settings() -> void:
	if not editor_interface:
		return
	var settings := editor_interface.get_editor_settings()
	_set_existing_editor_setting(settings, EMBED_SETTING_CANDIDATES, embed_on_play)
	_set_existing_editor_setting(settings, FLOAT_SETTING_CANDIDATES, floating)
	_set_existing_editor_setting(settings, SIZING_SETTING_CANDIDATES, _sizing_value_for_mode(str(active_preset.get("mode", "keep_aspect"))))

func _sizing_value_for_mode(mode: String) -> Variant:
	match mode:
		"fixed":
			return 0
		"keep_aspect":
			return 1
		"stretch":
			return 2
		_:
			return 1

func _set_existing_editor_setting(settings: EditorSettings, names: Array, value: Variant) -> void:
	for name in names:
		if settings.has_setting(name):
			if not _editor_setting_backup.has(name):
				_editor_setting_backup[name] = settings.get_setting(name)
			settings.set_setting(name, value)
			return

func _temp_project_set(name: String, value: Variant) -> void:
	if not _project_setting_backup.has(name):
		_project_setting_backup[name] = ProjectSettings.get_setting(name)
	ProjectSettings.set_setting(name, value)

func _is_fullscreen_project() -> bool:
	if not ProjectSettings.has_setting(WINDOW_MODE):
		return false
	var mode := ProjectSettings.get_setting(WINDOW_MODE)
	return int(mode) != 0

func _append_unique(args: PackedStringArray, flag: String) -> void:
	if not args.has(flag):
		args.append(flag)

func _append_pair(args: PackedStringArray, flag: String, value: String) -> void:
	var idx := args.find(flag)
	if idx >= 0 and idx + 1 < args.size():
		args[idx + 1] = value
		return
	args.append(flag)
	args.append(value)

func _gcd(a: int, b: int) -> int:
	a = abs(a)
	b = abs(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return max(a, 1)
