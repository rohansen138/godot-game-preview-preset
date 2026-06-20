@tool
extends RefCounted

const PRESET_FILE := "res://game_preview_presets.cfg"
const WINDOW_WIDTH := "display/window/size/viewport_width"
const WINDOW_HEIGHT := "display/window/size/viewport_height"

var presets: Array[Dictionary] = []

func load_presets() -> void:
	presets.clear()
	_add_builtin_presets()

	var cfg := ConfigFile.new()
	if cfg.load(PRESET_FILE) != OK:
		return

	for section in cfg.get_sections():
		if not section.begins_with("preset/"):
			continue
		var name := str(cfg.get_value(section, "name", section.trim_prefix("preset/")))
		var width := int(cfg.get_value(section, "width", project_width()))
		var height := int(cfg.get_value(section, "height", project_height()))
		var mode := str(cfg.get_value(section, "mode", "keep_aspect"))
		presets.append(_preset(name, width, height, mode, false))

func save_custom_presets() -> Error:
	var cfg := ConfigFile.new()
	var i := 0
	for p in presets:
		if bool(p.get("builtin", false)):
			continue
		var section := "preset/%02d_%s" % [i, str(p.get("name", "custom")).to_snake_case()]
		cfg.set_value(section, "name", p.get("name", "Custom"))
		cfg.set_value(section, "width", int(p.get("width", project_width())))
		cfg.set_value(section, "height", int(p.get("height", project_height())))
		cfg.set_value(section, "mode", str(p.get("mode", "keep_aspect")))
		i += 1
	return cfg.save(PRESET_FILE)

func add_custom_preset(name: String, width: int, height: int, mode: String = "keep_aspect") -> void:
	presets.append(_preset(name, width, height, mode, false))
	save_custom_presets()

func remove_custom_preset(index: int) -> void:
	if index < 0 or index >= presets.size():
		return
	if bool(presets[index].get("builtin", false)):
		return
	presets.remove_at(index)
	save_custom_presets()

func refresh_builtin_presets() -> void:
	var custom: Array[Dictionary] = []
	for p in presets:
		if not bool(p.get("builtin", false)):
			custom.append(p)
	presets.clear()
	_add_builtin_presets()
	for p in custom:
		presets.append(p)

func get_preset(index: int) -> Dictionary:
	if index < 0 or index >= presets.size():
		return _preset("Project Current", project_width(), project_height(), "keep_aspect", true)
	return presets[index].duplicate(true)

func project_width() -> int:
	return max(1, int(ProjectSettings.get_setting(WINDOW_WIDTH, 1152)))

func project_height() -> int:
	return max(1, int(ProjectSettings.get_setting(WINDOW_HEIGHT, 648)))

func project_size() -> Vector2i:
	return Vector2i(project_width(), project_height())

func make_size_for_ratio(ratio_w: int, ratio_h: int) -> Vector2i:
	# Ratios are dynamic, like Unity's Game view. The current project short side is
	# used as the reference. For a 1080x1920 project, 9:16 becomes 1080x1920 and
	# 16:9 becomes 1920x1080. No hard-coded 720x1280 fallback is used.
	ratio_w = max(1, ratio_w)
	ratio_h = max(1, ratio_h)
	var base := project_size()
	var short_side := min(base.x, base.y)
	if ratio_w >= ratio_h:
		return Vector2i(int(round(float(short_side) * float(ratio_w) / float(ratio_h))), short_side)
	return Vector2i(short_side, int(round(float(short_side) * float(ratio_h) / float(ratio_w))))

func make_size_for_ratio_with_long_side(ratio_w: int, ratio_h: int) -> Vector2i:
	# Useful when comparing ultrawide or tablet variants while preserving the
	# project's larger dimension as the largest generated dimension.
	ratio_w = max(1, ratio_w)
	ratio_h = max(1, ratio_h)
	var base := project_size()
	var long_side := max(base.x, base.y)
	if ratio_w >= ratio_h:
		return Vector2i(long_side, int(round(float(long_side) * float(ratio_h) / float(ratio_w))))
	return Vector2i(int(round(float(long_side) * float(ratio_w) / float(ratio_h))), long_side)

func _add_builtin_presets() -> void:
	var current := project_size()
	presets.append(_preset("Project Current - %d x %d" % [current.x, current.y], current.x, current.y, "keep_aspect", true))
	presets.append(_preset("Free", 0, 0, "free", true))

	_add_ratio_preset("16:9", 16, 9)
	_add_ratio_preset("9:16", 9, 16)
	_add_ratio_preset("4:3", 4, 3)
	_add_ratio_preset("3:2", 3, 2)
	_add_ratio_preset("21:9", 21, 9)
	_add_ratio_preset("1:1 Square", 1, 1)

	# Common exact device/screen test sizes. They are kept exact because artists
	# and UI engineers often want to regression-test these concrete sizes.
	presets.append(_preset("Mobile portrait - 1080 x 1920", 1080, 1920, "keep_aspect", true))
	presets.append(_preset("Mobile portrait tall - 1080 x 2340", 1080, 2340, "keep_aspect", true))
	presets.append(_preset("Mobile portrait tall - 1080 x 2400", 1080, 2400, "keep_aspect", true))
	presets.append(_preset("Mobile landscape - 1920 x 1080", 1920, 1080, "keep_aspect", true))
	presets.append(_preset("Mobile landscape tall - 2340 x 1080", 2340, 1080, "keep_aspect", true))
	presets.append(_preset("Mobile landscape tall - 2400 x 1080", 2400, 1080, "keep_aspect", true))
	presets.append(_preset("Tablet portrait - 1536 x 2048", 1536, 2048, "keep_aspect", true))
	presets.append(_preset("Tablet landscape - 2048 x 1536", 2048, 1536, "keep_aspect", true))
	presets.append(_preset("Tablet landscape - 2360 x 1640", 2360, 1640, "keep_aspect", true))
	presets.append(_preset("Desktop - 1280 x 720", 1280, 720, "keep_aspect", true))
	presets.append(_preset("Desktop - 1920 x 1080", 1920, 1080, "keep_aspect", true))
	presets.append(_preset("Ultrawide - 2560 x 1080", 2560, 1080, "keep_aspect", true))

func _add_ratio_preset(label: String, rw: int, rh: int) -> void:
	var s := make_size_for_ratio(rw, rh)
	presets.append(_preset("%s - %d x %d" % [label, s.x, s.y], s.x, s.y, "keep_aspect", true))

func _preset(name: String, width: int, height: int, mode: String, builtin: bool) -> Dictionary:
	return {
		"name": name,
		"width": width,
		"height": height,
		"mode": mode,
		"builtin": builtin,
	}
