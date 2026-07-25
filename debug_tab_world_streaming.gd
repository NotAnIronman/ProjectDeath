extends Control
class_name DebugTabWorldStreaming

## DEBUG TAB — "World Streaming". Live diagnostics + controls for
## WorldManager's cell load/unload system. Built for one purpose: making
## it possible to actually SEE and TUNE the "no loading screens, player
## never notices anything changing" behavior instead of guessing from
## printed console spam.
##
## Everything here reads/writes WorldManager directly — this tab owns no
## streaming state of its own, it's a window onto WorldManager's.

var _status_label: Label
var _load_radius_spin: SpinBox
var _unload_radius_spin: SpinBox
var _overlay_checkbox: CheckBox
var _cell_list: RichTextLabel
var _teleport_x: SpinBox
var _teleport_z: SpinBox

var _refresh_timer: float = 0.0
const REFRESH_INTERVAL := 0.25  # 4x/sec is plenty for human-readable diagnostics, no point polling every frame


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()


func on_tab_shown() -> void:
	_refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_refresh()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# --- Live status block ---
	_status_label = Label.new()
	_status_label.text = "..."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

	vbox.add_child(HSeparator.new())

	# --- Radius tuning ---
	var radius_row := HBoxContainer.new()
	radius_row.add_theme_constant_override("separation", 8)
	vbox.add_child(radius_row)

	radius_row.add_child(_label("Load radius:"))
	_load_radius_spin = SpinBox.new()
	_load_radius_spin.min_value = 0
	_load_radius_spin.max_value = 10
	_load_radius_spin.value = WorldManager.load_radius_cells
	_load_radius_spin.custom_minimum_size = Vector2(70, 0)
	_load_radius_spin.value_changed.connect(_on_load_radius_changed)
	radius_row.add_child(_load_radius_spin)

	radius_row.add_child(_label("   Unload radius:"))
	_unload_radius_spin = SpinBox.new()
	_unload_radius_spin.min_value = 0
	_unload_radius_spin.max_value = 12
	_unload_radius_spin.value = WorldManager.unload_radius_cells
	_unload_radius_spin.custom_minimum_size = Vector2(70, 0)
	_unload_radius_spin.value_changed.connect(_on_unload_radius_changed)
	radius_row.add_child(_unload_radius_spin)

	var radius_hint := Label.new()
	radius_hint.text = "Unload radius must stay >= load radius, or every cell will thrash load/unload every frame at the boundary."
	radius_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	radius_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(radius_hint)

	vbox.add_child(HSeparator.new())

	# --- Actions ---
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 8)
	vbox.add_child(actions_row)

	var reload_btn := Button.new()
	reload_btn.text = "Force Reload All Cells"
	reload_btn.tooltip_text = "Unloads every currently loaded cell — watch them stream back in without moving."
	reload_btn.pressed.connect(func(): WorldManager.force_reload_all_cells())
	actions_row.add_child(reload_btn)

	_overlay_checkbox = CheckBox.new()
	_overlay_checkbox.text = "Show cell boundaries"
	_overlay_checkbox.button_pressed = WorldManager.debug_overlay_enabled
	_overlay_checkbox.toggled.connect(func(pressed): WorldManager.debug_overlay_enabled = pressed)
	actions_row.add_child(_overlay_checkbox)

	vbox.add_child(HSeparator.new())

	# --- Teleport ---
	var teleport_row := HBoxContainer.new()
	teleport_row.add_theme_constant_override("separation", 8)
	vbox.add_child(teleport_row)

	teleport_row.add_child(_label("Jump to cell  X:"))
	_teleport_x = SpinBox.new()
	_teleport_x.min_value = -999
	_teleport_x.max_value = 999
	_teleport_x.custom_minimum_size = Vector2(70, 0)
	teleport_row.add_child(_teleport_x)

	teleport_row.add_child(_label("Z:"))
	_teleport_z = SpinBox.new()
	_teleport_z.min_value = -999
	_teleport_z.max_value = 999
	_teleport_z.custom_minimum_size = Vector2(70, 0)
	teleport_row.add_child(_teleport_z)

	var teleport_btn := Button.new()
	teleport_btn.text = "Teleport"
	teleport_btn.pressed.connect(_on_teleport_pressed)
	teleport_row.add_child(teleport_btn)

	vbox.add_child(HSeparator.new())

	# --- Loaded cell list ---
	vbox.add_child(_label("Currently loaded cells:"))
	_cell_list = RichTextLabel.new()
	_cell_list.bbcode_enabled = true
	_cell_list.fit_content = false
	_cell_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cell_list.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(_cell_list)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _on_load_radius_changed(value: float) -> void:
	WorldManager.load_radius_cells = int(value)
	# Enforce the ordering the hint text warns about, instead of just
	# warning and letting it thrash — if load radius is pushed past the
	# current unload radius, drag unload radius up to match.
	if WorldManager.load_radius_cells > WorldManager.unload_radius_cells:
		WorldManager.unload_radius_cells = WorldManager.load_radius_cells
		_unload_radius_spin.set_value_no_signal(WorldManager.unload_radius_cells)


func _on_unload_radius_changed(value: float) -> void:
	WorldManager.unload_radius_cells = int(value)
	if WorldManager.unload_radius_cells < WorldManager.load_radius_cells:
		WorldManager.load_radius_cells = WorldManager.unload_radius_cells
		_load_radius_spin.set_value_no_signal(WorldManager.load_radius_cells)


func _on_teleport_pressed() -> void:
	var player := WorldManager.get_player()
	if player == null:
		print("DebugTabWorldStreaming: no player found, can't teleport.")
		return
	var cell := Vector2i(int(_teleport_x.value), int(_teleport_z.value))
	var world_pos := Vector3(
		cell.x * WorldManager.CELL_SIZE + WorldManager.CELL_SIZE * 0.5,
		player.global_position.y,
		cell.y * WorldManager.CELL_SIZE + WorldManager.CELL_SIZE * 0.5
	)
	player.global_position = world_pos
	print("DebugTabWorldStreaming: teleported to cell %s (world pos %s)." % [cell, world_pos])


func _refresh() -> void:
	if WorldManager.debug_overlay_enabled:
		WorldManager.refresh_debug_overlay()

	var snapshot := WorldManager.get_debug_snapshot()

	_status_label.text = (
		"Current cell: %s\n" +
		"Loaded cells: %d   |   Pending (in-flight) loads: %d   |   Cached unloaded cells: %d\n" +
		"Streamed node count: %d"
	) % [
		snapshot.get("current_cell", "?"),
		snapshot.get("loaded_count", 0),
		snapshot.get("pending_load_count", 0),
		snapshot.get("cached_unloaded_count", 0),
		snapshot.get("streamed_node_count", 0),
	]

	var loaded_cells: Array = snapshot.get("loaded_cells", [])
	if loaded_cells.is_empty():
		_cell_list.text = "[i](none loaded)[/i]"
	else:
		var lines: Array = []
		for c in loaded_cells:
			lines.append(str(c))
		_cell_list.text = ", ".join(lines)
