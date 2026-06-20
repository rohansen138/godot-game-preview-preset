@tool
extends VBoxContainer

var preset_manager: RefCounted
var session: RefCounted
var editor_interface: EditorInterface

var preset_picker: OptionButton
var quick_ratio_picker: OptionButton
var mode_picker: OptionButton
var width_spin: SpinBox
var height_spin: SpinBox
var ratio_input: LineEdit
var scale_slider: HSlider
var scale_value_label: Label
var size_label: Label
var project_label: Label
var status_label: RichTextLabel
var embed_check: CheckBox
var floating_check: CheckBox
var focus_check: CheckBox
var mute_check: CheckBox
var debug_picker: OptionButton
var runtime_viewport_check: CheckBox
var live_update_check: CheckBox
var force_scale_check: CheckBox
var play_button: Button
var stop_button: Button
var screenshot_button: Button
var record_button: Button
var pause_record_button: Button
var stop_record_button: Button
var _updating_ui := false

func setup(p_preset_manager: RefCounted, p_session: RefCounted, p_editor_interface: EditorInterface) -> void:
	preset_manager = p_preset_manager
	session = p_session
	editor_interface = p_editor_interface
	if is_inside_tree():
		_build_ui()

func _ready() -> void:
	if preset_manager:
		_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	custom_minimum_size = Vector2(240, 120)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_updating_ui = true

	# Top toolbar: keep the high-frequency actions visible like Unity's Game view.
	var toolbar := HFlowContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_theme_constant_override("h_separation", 6)
	toolbar.add_theme_constant_override("v_separation", 6)
	play_button = Button.new()
	play_button.text = "Play"
	play_button.tooltip_text = "Run the main scene inside Godot's embedded Game tab."
	play_button.pressed.connect(_on_play_main)
	toolbar.add_child(play_button)
	stop_button = Button.new()
	stop_button.text = "Stop"
	stop_button.pressed.connect(_on_stop)
	toolbar.add_child(stop_button)
	var apply_live_btn := Button.new()
	apply_live_btn.text = "Apply Live"
	apply_live_btn.tooltip_text = "Apply the selected aspect/resolution to the running game."
	apply_live_btn.pressed.connect(_on_apply_live)
	toolbar.add_child(apply_live_btn)
	screenshot_button = Button.new()
	screenshot_button.text = "Screenshot"
	screenshot_button.tooltip_text = "Save a PNG from the game viewport to res://Captures."
	screenshot_button.pressed.connect(_on_screenshot)
	toolbar.add_child(screenshot_button)
	record_button = Button.new()
	record_button.text = "Record"
	record_button.tooltip_text = "Start viewport frame recording. Frames are saved from the game viewport to res://Captures."
	record_button.pressed.connect(_on_record_start)
	toolbar.add_child(record_button)
	pause_record_button = Button.new()
	pause_record_button.text = "Pause"
	pause_record_button.pressed.connect(_on_record_pause_resume)
	toolbar.add_child(pause_record_button)
	stop_record_button = Button.new()
	stop_record_button.text = "Stop Rec"
	stop_record_button.pressed.connect(_on_record_stop)
	toolbar.add_child(stop_record_button)
	add_child(toolbar)

	quick_ratio_picker = OptionButton.new()
	_add_quick_ratio_items()
	quick_ratio_picker.item_selected.connect(_on_quick_ratio_selected)
	add_labeled("Aspect", quick_ratio_picker)

	preset_picker = OptionButton.new()
	for p in preset_manager.presets:
		preset_picker.add_item(str(p.get("name", "Preset")))
	preset_picker.item_selected.connect(_on_preset_selected)
	add_labeled("Preset", preset_picker)

	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 6)
	width_spin = SpinBox.new()
	width_spin.min_value = 1
	width_spin.max_value = 16384
	width_spin.step = 1
	width_spin.value = preset_manager.project_width()
	width_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	width_spin.value_changed.connect(_on_custom_value_changed)
	height_spin = SpinBox.new()
	height_spin.min_value = 1
	height_spin.max_value = 16384
	height_spin.step = 1
	height_spin.value = preset_manager.project_height()
	height_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	height_spin.value_changed.connect(_on_custom_value_changed)
	custom_row.add_child(width_spin)
	custom_row.add_child(_label("x"))
	custom_row.add_child(height_spin)
	var swap_btn := Button.new()
	swap_btn.text = "Swap"
	swap_btn.tooltip_text = "Swap width and height."
	swap_btn.pressed.connect(_on_swap_orientation)
	custom_row.add_child(swap_btn)
	add_labeled("Size", custom_row)

	var ratio_row := HBoxContainer.new()
	ratio_row.add_theme_constant_override("separation", 6)
	ratio_input = LineEdit.new()
	ratio_input.placeholder_text = "9:16, 16:9, 2360x1640, 2560x1080"
	ratio_input.text_submitted.connect(func(_text: String): _on_apply_ratio())
	ratio_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratio_row.add_child(ratio_input)
	var ratio_btn := Button.new()
	ratio_btn.text = "Use"
	ratio_btn.pressed.connect(_on_apply_ratio)
	ratio_row.add_child(ratio_btn)
	add_labeled("Custom", ratio_row)

	mode_picker = OptionButton.new()
	mode_picker.add_item("Free")
	mode_picker.add_item("Fixed Size")
	mode_picker.add_item("Keep Aspect / Fit")
	mode_picker.add_item("Stretch")
	mode_picker.item_selected.connect(_on_mode_selected)
	add_labeled("Sizing", mode_picker)

	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 6)
	scale_slider = HSlider.new()
	scale_slider.min_value = 0.1
	scale_slider.max_value = 2.0
	scale_slider.step = 0.05
	scale_slider.value = session.scale
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.value_changed.connect(_on_scale_changed)
	scale_row.add_child(scale_slider)
	scale_value_label = Label.new()
	scale_value_label.custom_minimum_size.x = 48
	scale_row.add_child(scale_value_label)
	add_labeled("Scale", scale_row)

	var toggles := GridContainer.new()
	toggles.columns = 2
	toggles.add_theme_constant_override("h_separation", 12)
	toggles.add_theme_constant_override("v_separation", 4)
	toggles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	embed_check = CheckBox.new()
	embed_check.text = "Embed"
	embed_check.button_pressed = session.embed_on_play
	embed_check.toggled.connect(func(v: bool): session.embed_on_play = v)
	toggles.add_child(embed_check)
	floating_check = CheckBox.new()
	floating_check.text = "Floating"
	floating_check.tooltip_text = "Off = embedded in the main Game tab."
	floating_check.button_pressed = session.floating
	floating_check.toggled.connect(func(v: bool): session.floating = v)
	toggles.add_child(floating_check)
	focus_check = CheckBox.new()
	focus_check.text = "Focus Play"
	focus_check.button_pressed = session.focus_on_play
	focus_check.toggled.connect(func(v: bool): session.focus_on_play = v)
	toggles.add_child(focus_check)
	mute_check = CheckBox.new()
	mute_check.text = "Mute"
	mute_check.button_pressed = session.mute_audio
	mute_check.toggled.connect(func(v: bool): session.mute_audio = v)
	toggles.add_child(mute_check)
	runtime_viewport_check = CheckBox.new()
	runtime_viewport_check.text = "Use Size"
	runtime_viewport_check.tooltip_text = "Use the selected logical preview size for Play and live switching."
	runtime_viewport_check.button_pressed = session.override_runtime_viewport
	runtime_viewport_check.toggled.connect(_on_runtime_viewport_toggled)
	toggles.add_child(runtime_viewport_check)
	live_update_check = CheckBox.new()
	live_update_check.text = "Live"
	live_update_check.tooltip_text = "Allow runtime aspect/size switching while playing."
	live_update_check.button_pressed = session.live_update_while_playing
	live_update_check.toggled.connect(_on_live_update_toggled)
	toggles.add_child(live_update_check)
	force_scale_check = CheckBox.new()
	force_scale_check.text = "Responsive"
	force_scale_check.tooltip_text = "Temporarily enables viewport scaling so aspect switches are visible."
	force_scale_check.button_pressed = session.force_scale_mode_if_disabled
	force_scale_check.toggled.connect(_on_force_scale_toggled)
	toggles.add_child(force_scale_check)
	add_child(toggles)

	debug_picker = OptionButton.new()
	debug_picker.add_item("Overlay: Off")
	debug_picker.add_item("Print FPS")
	debug_picker.add_item("Collisions")
	debug_picker.add_item("Navigation")
	debug_picker.add_item("Paths")
	debug_picker.item_selected.connect(_on_debug_selected)
	add_labeled("Debug", debug_picker)

	var utility_row := HFlowContainer.new()
	utility_row.add_theme_constant_override("h_separation", 6)
	utility_row.add_theme_constant_override("v_separation", 6)
	var use_project_btn := Button.new()
	use_project_btn.text = "Project Size"
	use_project_btn.pressed.connect(_on_use_project_size)
	utility_row.add_child(use_project_btn)
	var save_btn := Button.new()
	save_btn.text = "Save Preset"
	save_btn.pressed.connect(_on_save_custom)
	utility_row.add_child(save_btn)
	var remove_btn := Button.new()
	remove_btn.text = "Remove"
	remove_btn.pressed.connect(_on_remove_custom)
	utility_row.add_child(remove_btn)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_on_refresh_presets)
	utility_row.add_child(refresh_btn)
	var fix_game_tab_btn := Button.new()
	fix_game_tab_btn.text = "Fix Game Tab"
	fix_game_tab_btn.pressed.connect(_on_fix_game_tab)
	utility_row.add_child(fix_game_tab_btn)
	var apply_btn := Button.new()
	apply_btn.text = "Apply Project"
	apply_btn.tooltip_text = "Permanent: writes the selected size to Project Settings."
	apply_btn.pressed.connect(_on_apply_to_project)
	utility_row.add_child(apply_btn)
	var defaults_btn := Button.new()
	defaults_btn.text = "Defaults"
	defaults_btn.pressed.connect(_on_restore_defaults)
	utility_row.add_child(defaults_btn)
	add_child(utility_row)

	size_label = Label.new()
	size_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(size_label)

	status_label = RichTextLabel.new()
	status_label.fit_content = true
	status_label.bbcode_enabled = true
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "[color=gray]Ready[/color]"
	add_child(status_label)

	project_label = Label.new()
	project_label.visible = false
	add_child(project_label)

	if not session.status_changed.is_connected(_on_status_changed):
		session.status_changed.connect(_on_status_changed)

	_updating_ui = false
	_select_mode("keep_aspect")
	_on_preset_selected(0)
	_update_size_label()

func add_labeled(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 78
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	add_child(row)

func set_playing(playing: bool) -> void:
	if play_button:
		play_button.disabled = playing
	if stop_button:
		stop_button.disabled = not playing
	_update_capture_buttons(playing)

func _add_quick_ratio_items() -> void:
	quick_ratio_picker.add_item("Project Current")
	quick_ratio_picker.set_item_metadata(0, {"kind": "project"})
	quick_ratio_picker.add_item("Free")
	quick_ratio_picker.set_item_metadata(1, {"kind": "free"})
	var entries := [
		["16:9 Landscape", 16, 9],
		["9:16 Portrait", 9, 16],
		["4:3", 4, 3],
		["3:2", 3, 2],
		["21:9 Ultrawide", 21, 9],
		["1:1 Square", 1, 1],
	]
	for e in entries:
		var s: Vector2i = preset_manager.make_size_for_ratio(int(e[1]), int(e[2]))
		var index := quick_ratio_picker.item_count
		quick_ratio_picker.add_item("%s  (%d x %d)" % [str(e[0]), s.x, s.y])
		quick_ratio_picker.set_item_metadata(index, {"kind": "ratio", "rw": int(e[1]), "rh": int(e[2])})

func _on_quick_ratio_selected(index: int) -> void:
	if _updating_ui:
		return
	var data: Dictionary = quick_ratio_picker.get_item_metadata(index)
	match str(data.get("kind", "project")):
		"project":
			_on_use_project_size()
		"free":
			_select_mode("free")
			session.set_active_preset(_current_preset_from_ui())
		"ratio":
			var size: Vector2i = preset_manager.make_size_for_ratio(int(data.get("rw", 16)), int(data.get("rh", 9)))
			width_spin.value = size.x
			height_spin.value = size.y
			ratio_input.text = "%d:%d" % [int(data.get("rw", 16)), int(data.get("rh", 9))]
			_select_mode("keep_aspect")
			session.set_active_preset(_current_preset_from_ui())
	_update_size_label()

func _on_preset_selected(index: int) -> void:
	if _updating_ui:
		return
	var preset: Dictionary = preset_manager.get_preset(index)
	_updating_ui = true
	width_spin.value = max(1, int(preset.get("width", preset_manager.project_width())))
	height_spin.value = max(1, int(preset.get("height", preset_manager.project_height())))
	_select_mode(str(preset.get("mode", "keep_aspect")))
	ratio_input.text = session.aspect_label(int(width_spin.value), int(height_spin.value))
	_updating_ui = false
	session.set_active_preset(_current_preset_from_ui())
	_update_size_label()

func _on_custom_value_changed(_value: float) -> void:
	if _updating_ui:
		return
	if _mode_key() == "free":
		_select_mode("keep_aspect")
	ratio_input.text = session.aspect_label(int(width_spin.value), int(height_spin.value))
	session.set_active_preset(_current_preset_from_ui())
	_update_size_label()

func _on_mode_selected(_index: int) -> void:
	session.set_active_preset(_current_preset_from_ui())
	_update_size_label()

func _on_scale_changed(value: float) -> void:
	session.scale = value
	session.publish_live_preview(true)
	_update_size_label()

func _on_apply_ratio() -> void:
	var exact := _parse_exact_size_text(ratio_input.text)
	if exact.x > 0 and exact.y > 0:
		width_spin.value = exact.x
		height_spin.value = exact.y
		_select_mode("keep_aspect")
		session.set_active_preset(_current_preset_from_ui())
		_update_size_label()
		return
	var parsed := _parse_ratio_text(ratio_input.text)
	if parsed.x <= 0 or parsed.y <= 0:
		status_label.text = "[color=orange]Enter a ratio like 9:16 or 16:9, or an exact size like 1080x1920.[/color]"
		return
	var size: Vector2i = preset_manager.make_size_for_ratio(parsed.x, parsed.y)
	width_spin.value = size.x
	height_spin.value = size.y
	_select_mode("keep_aspect")
	session.set_active_preset(_current_preset_from_ui())
	_update_size_label()

func _on_use_project_size() -> void:
	width_spin.value = preset_manager.project_width()
	height_spin.value = preset_manager.project_height()
	ratio_input.text = session.aspect_label(int(width_spin.value), int(height_spin.value))
	_select_mode("keep_aspect")
	session.set_active_preset(_current_preset_from_ui())
	_update_size_label()

func _on_apply_live() -> void:
	# SpinBox text edits are sometimes not committed until Enter/focus-loss.
	# Reading value here after the user presses Apply Live gives a clear Unity-like
	# "apply current Game view size" workflow.
	if _mode_key() == "free":
		_select_mode("keep_aspect")
	session.set_active_preset(_current_preset_from_ui())
	session.publish_live_preview(true)
	_update_size_label()
	if status_label:
		status_label.text = "[color=gray]Applied live preview: %s[/color]" % session.describe_current_preview()

func _on_swap_orientation() -> void:
	var w := int(width_spin.value)
	width_spin.value = int(height_spin.value)
	height_spin.value = w
	ratio_input.text = session.aspect_label(int(width_spin.value), int(height_spin.value))
	if _mode_key() == "free":
		_select_mode("keep_aspect")
	session.set_active_preset(_current_preset_from_ui())
	_update_size_label()

func _on_refresh_presets() -> void:
	preset_manager.refresh_builtin_presets()
	_build_ui()

func _on_save_custom() -> void:
	var w := int(width_spin.value)
	var h := int(height_spin.value)
	var name := "%d x %d (%s)" % [w, h, session.aspect_label(w, h)]
	preset_manager.add_custom_preset(name, w, h, _mode_key())
	_build_ui()
	preset_picker.select(preset_manager.presets.size() - 1)
	_on_preset_selected(preset_manager.presets.size() - 1)

func _on_remove_custom() -> void:
	preset_manager.remove_custom_preset(preset_picker.selected)
	_build_ui()

func _on_runtime_viewport_toggled(value: bool) -> void:
	session.override_runtime_viewport = value
	session.publish_live_preview()
	_update_size_label()

func _on_live_update_toggled(value: bool) -> void:
	session.live_update_while_playing = value
	session.publish_live_preview()
	_update_size_label()

func _on_force_scale_toggled(value: bool) -> void:
	session.force_scale_mode_if_disabled = value
	session.publish_live_preview()
	_update_size_label()

func _on_debug_selected(index: int) -> void:
	var modes := ["off", "fps", "collisions", "navigation", "paths"]
	session.debug_overlay = modes[index]

func _on_play_main() -> void:
	session.set_active_preset(_current_preset_from_ui())
	editor_interface.play_main_scene()

func _on_stop() -> void:
	editor_interface.stop_playing_scene()

func _on_fix_game_tab() -> void:
	session.set_active_preset(_current_preset_from_ui())
	session.apply_editor_embedding_settings()
	status_label.text = "[color=gray]Requested embedded Game tab setup. If your build still says embedding disabled, use the Game tab three-dot menu once: Embed ON, Floating OFF, Keep Aspect Ratio.[/color]"


func _on_screenshot() -> void:
	session.request_screenshot()

func _on_record_start() -> void:
	session.start_recording()
	_update_capture_buttons(true)

func _on_record_pause_resume() -> void:
	if session.is_recording_paused():
		session.resume_recording()
	else:
		session.pause_recording()
	_update_capture_buttons(true)

func _on_record_stop() -> void:
	session.stop_recording()
	_update_capture_buttons(true)

func _update_capture_buttons(playing: bool) -> void:
	var recording: bool = session != null and session.is_recording()
	var paused: bool = session != null and session.is_recording_paused()
	if screenshot_button:
		screenshot_button.disabled = not playing
	if record_button:
		record_button.disabled = not playing or recording or paused
	if pause_record_button:
		pause_record_button.disabled = not playing or (not recording and not paused)
		pause_record_button.text = "Resume" if paused else "Pause"
	if stop_record_button:
		stop_record_button.disabled = not playing or (not recording and not paused)

func _on_apply_to_project() -> void:
	session.set_active_preset(_current_preset_from_ui())
	var err: Error = session.apply_selected_to_project()
	if err != OK:
		status_label.text = "[color=orange]Could not apply preset to Project Settings. Error: %s[/color]" % error_string(err)
	_update_project_label()

func _on_restore_defaults() -> void:
	session.restore_defaults()
	_build_ui()

func _on_status_changed(message: String) -> void:
	if status_label:
		status_label.text = "[color=gray]%s[/color]" % message
	_update_size_label()
	if editor_interface:
		_update_capture_buttons(editor_interface.is_playing_scene())

func _current_preset_from_ui() -> Dictionary:
	var mode := _mode_key()
	var w := int(width_spin.value)
	var h := int(height_spin.value)
	if mode == "free":
		w = 0
		h = 0
	return {
		"name": preset_picker.get_item_text(preset_picker.selected) if preset_picker and preset_picker.selected >= 0 else "Custom",
		"width": w,
		"height": h,
		"mode": mode,
		"builtin": false,
	}

func _mode_key() -> String:
	if not mode_picker:
		return "keep_aspect"
	match mode_picker.selected:
		0:
			return "free"
		1:
			return "fixed"
		2:
			return "keep_aspect"
		3:
			return "stretch"
		_:
			return "keep_aspect"

func _select_mode(mode: String) -> void:
	if not mode_picker:
		return
	match mode:
		"free":
			mode_picker.select(0)
		"fixed":
			mode_picker.select(1)
		"keep_aspect":
			mode_picker.select(2)
		"stretch":
			mode_picker.select(3)
		_:
			mode_picker.select(2)

func _update_size_label() -> void:
	if not size_label or not session:
		return
	session.scale = float(scale_slider.value) if scale_slider else 1.0
	if scale_value_label:
		scale_value_label.text = "%d%%" % int(round(session.scale * 100.0))
	var w := int(width_spin.value) if width_spin else int(session.active_preset.get("width", 0))
	var h := int(height_spin.value) if height_spin else int(session.active_preset.get("height", 0))
	var mode := _mode_key()
	var hint := ""
	if mode == "fixed":
		hint = "\nFixed Size is pixel-perfect and may crop if larger than the Game tab. Lower Fixed scale or use Keep Aspect Ratio / Fit."
	elif mode == "keep_aspect":
		hint = "\nFit mode preserves aspect. For your portrait project, 9:16 should resolve to 1080 x 1920 when the project base is 1080 x 1920."
	elif mode == "stretch":
		hint = "\nStretch fills the Game tab and may distort aspect, like Unity's free stretched preview."
	if runtime_viewport_check and not runtime_viewport_check.button_pressed:
		hint += "\nSelected resolution is OFF, so Godot keeps the project's current runtime viewport."
	if live_update_check and live_update_check.button_pressed:
		hint += "\nLive switching is ON: changing presets while the game is running updates the game aspect without resizing the Game tab."
	size_label.text = "Active: %d x %d  (%s)\n%s%s" % [w, h, session.aspect_label(w, h), session.describe_current_preview(), hint]

func _update_project_label() -> void:
	if project_label and preset_manager:
		var w: int = preset_manager.project_width()
		var h: int = preset_manager.project_height()
		project_label.text = "Project base viewport: %d x %d  (%s)" % [w, h, session.aspect_label(w, h) if session else _aspect_label_local(w, h)]

func _parse_exact_size_text(text: String) -> Vector2i:
	var t := text.strip_edges().to_lower().replace(" ", "")
	if not t.contains("x"):
		return Vector2i.ZERO
	var parts := t.split("x", false)
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(max(1, int(parts[0])), max(1, int(parts[1])))
	return Vector2i.ZERO

func _parse_ratio_text(text: String) -> Vector2i:
	var t := text.strip_edges().to_lower()
	if t.is_empty():
		return Vector2i.ZERO
	t = t.replace(" ", "")
	var separator := ""
	if t.contains(":"):
		separator = ":"
	elif t.contains("/"):
		separator = "/"
	if separator != "":
		var parts := t.split(separator, false)
		if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
			var a := max(1, int(round(float(parts[0]))))
			var b := max(1, int(round(float(parts[1]))))
			return Vector2i(a, b)
	if t.is_valid_float():
		var r := float(t)
		if r > 0.0:
			return Vector2i(int(round(r * 1000.0)), 1000)
	return Vector2i.ZERO

func _aspect_label_local(width: int, height: int) -> String:
	if height <= 0:
		return "free"
	var a := abs(width)
	var b := abs(height)
	while b != 0:
		var tmp := b
		b = a % b
		a = tmp
	return "%d:%d" % [width / max(1, a), height / max(1, a)]

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l
