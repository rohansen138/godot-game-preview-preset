@tool
extends EditorPlugin

const DockScene := preload("res://addons/game_preview_presets/game_preview_presets_dock.tscn")
const PresetManager := preload("res://addons/game_preview_presets/preset_manager.gd")
const PreviewSession := preload("res://addons/game_preview_presets/preview_session.gd")
const BRIDGE_AUTOLOAD_NAME := "GamePreviewPresetsBridge"
const BRIDGE_SETTING := "autoload/GamePreviewPresetsBridge"
const BRIDGE_PATH := "res://addons/game_preview_presets/game_preview_runtime_bridge.gd"

var _dock_scroll: ScrollContainer
var _dock_content: Control
var _preset_manager: RefCounted
var _session: RefCounted
var _was_playing: bool = false

func _enable_plugin() -> void:
	_ensure_runtime_bridge_autoload()

func _disable_plugin() -> void:
	_remove_runtime_bridge_autoload()

func _enter_tree() -> void:
	_ensure_runtime_bridge_autoload()
	_ensure_capture_folder()
	_preset_manager = PresetManager.new()
	_preset_manager.load_presets()

	_session = PreviewSession.new()
	_session.setup(get_editor_interface(), _preset_manager)

	# IMPORTANT: This is intentionally a normal Godot dock, not a bottom panel.
	# Bottom panels steal vertical space from the embedded Game tab and cannot be
	# freely dragged to the Inspector/FileSystem dock areas. A dock is movable and
	# can be collapsed, stacked, or dragged just like Godot's native docks.
	_dock_scroll = _make_scrollable_panel("Godot Game Preview Preset")
	_dock_content = DockScene.instantiate()
	_dock_content.name = "Godot Game Preview Preset"
	_dock_content.setup(_preset_manager, _session, get_editor_interface())
	_dock_scroll.add_child(_dock_content)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock_scroll)

	_was_playing = get_editor_interface().is_playing_scene()
	set_process(true)

func _exit_tree() -> void:
	set_process(false)
	if _session:
		_session.restore_after_play()
	if _dock_scroll:
		remove_control_from_docks(_dock_scroll)
		_dock_scroll.queue_free()

func _process(_delta: float) -> void:
	var playing: bool = get_editor_interface().is_playing_scene()
	if _was_playing and not playing:
		_session.restore_after_play()
	if _session:
		_session.poll_capture_status()
	if _dock_content and _dock_content.has_method("set_playing"):
		_dock_content.set_playing(playing)
	_was_playing = playing

func _run_scene(scene: String, args: PackedStringArray) -> PackedStringArray:
	return _session.prepare_run_args(scene, args)

func _make_scrollable_panel(panel_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = panel_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(260, 160)
	return scroll

func _ensure_runtime_bridge_autoload() -> void:
	# Some earlier development builds could leave an invalid autoload value such as
	# "." or an empty path in project.godot. Godot then tries to load res:// on
	# game start and prints: "Failed to instantiate an autoload, can't load from
	# path: .". Sanitize the entry before adding the correct bridge.
	if ProjectSettings.has_setting(BRIDGE_SETTING):
		var current_value: Variant = ProjectSettings.get_setting(BRIDGE_SETTING)
		var current_path: String = _autoload_value_to_path(current_value)
		if current_path != BRIDGE_PATH:
			_remove_runtime_bridge_autoload()

	if not ProjectSettings.has_setting(BRIDGE_SETTING):
		add_autoload_singleton(BRIDGE_AUTOLOAD_NAME, BRIDGE_PATH)

func _remove_runtime_bridge_autoload() -> void:
	if not ProjectSettings.has_setting(BRIDGE_SETTING):
		return
	# Prefer the EditorPlugin helper because it updates both ProjectSettings and
	# the editor autoload registry. If the entry is malformed, also clear the raw
	# project setting as a fallback.
	remove_autoload_singleton(BRIDGE_AUTOLOAD_NAME)
	if ProjectSettings.has_setting(BRIDGE_SETTING):
		ProjectSettings.clear(BRIDGE_SETTING)
		ProjectSettings.save()

func _autoload_value_to_path(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		var text: String = str(value).strip_edges()
		if text.begins_with("*"):
			text = text.substr(1)
		return text
	if typeof(value) == TYPE_DICTIONARY:
		var data: Dictionary = value
		if data.has("path"):
			return str(data["path"]).strip_edges()
	return ""

func _ensure_capture_folder() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Captures"))
