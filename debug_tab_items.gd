extends Control
class_name DebugTabItems

## DEBUG TAB — "Items". Lists every registered item (name + id) with a
## quantity field and an Add button per row, for quickly spawning items
## into your inventory for testing.
##
## This is the original DebugItemSpawner panel body, unchanged in
## behavior, just repackaged as one tab inside DebugMenu (see
## scripts/debug/debug_menu.gd) instead of owning its own top-level panel
## and F1 handling.

var search_box: LineEdit
var quantity_box: SpinBox
var list_container: VBoxContainer
var _status_label: Label
var row_nodes: Array[Dictionary] = []  # {item_id, display_name, row_control}


func _ready() -> void:
	_build_ui()
	call_deferred("_populate_list")


## Called by DebugMenu each time this tab becomes visible, so newly
## registered items (e.g. added mid-session by another debug action)
## show up without needing a restart. Cheap enough to just rebuild.
func on_tab_shown() -> void:
	if row_nodes.is_empty():
		_populate_list()


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(560, 520)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 8)
	vbox.add_child(controls_row)

	search_box = LineEdit.new()
	search_box.placeholder_text = "Search by name or id..."
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_changed.connect(_on_search_changed)
	controls_row.add_child(search_box)

	var qty_label := Label.new()
	qty_label.text = "Qty:"
	controls_row.add_child(qty_label)

	quantity_box = SpinBox.new()
	quantity_box.min_value = 1
	quantity_box.max_value = 9999
	quantity_box.value = 1
	quantity_box.custom_minimum_size = Vector2(80, 0)
	controls_row.add_child(quantity_box)

	vbox.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = "Loading item list..."
	vbox.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	vbox.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 2)
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_container)


func _populate_list() -> void:
	for entry in row_nodes:
		if is_instance_valid(entry["row"]):
			entry["row"].queue_free()
	row_nodes.clear()

	# Defensive check — if this ever prints 0, the item list is genuinely
	# empty at InventoryManager (autoload ordering / item_defs not loaded
	# yet), which is a different problem than a UI/layout bug and would
	# show up here in the Output panel rather than as a silent blank tab.
	if InventoryManager == null or InventoryManager.item_defs == null:
		_status_label.text = "ERROR: InventoryManager or item_defs unavailable — check autoload order in Project Settings."
		push_error("DebugTabItems: InventoryManager.item_defs unavailable.")
		return

	var ids: Array = InventoryManager.item_defs.keys()
	ids.sort()

	if ids.is_empty():
		_status_label.text = "InventoryManager.item_defs is empty (0 registered items) — nothing to list."
		push_warning("DebugTabItems: InventoryManager.item_defs is empty.")
		return

	for item_id in ids:
		var def: ItemData = InventoryManager.item_defs[item_id]
		if def == null:
			push_warning("DebugTabItems: item_defs['%s'] is null, skipping." % item_id)
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 36)
		list_container.add_child(row)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture = def.icon
		row.add_child(icon_rect)

		var label := Label.new()
		label.text = "%s  (%s)" % [def.display_name, item_id]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		row.add_child(label)

		var add_btn := Button.new()
		add_btn.text = "Add"
		add_btn.pressed.connect(func(): _add_item(item_id))
		row.add_child(add_btn)

		row_nodes.append({
			"item_id": item_id,
			"search_text": (def.display_name + " " + item_id).to_lower(),
			"row": row
		})

	_status_label.text = "%d items available." % row_nodes.size()
	print("DebugTabItems: listed %d items." % row_nodes.size())


func _add_item(item_id: String) -> void:
	var qty := int(quantity_box.value)
	InventoryManager.add_item(item_id, qty)
	print("Debug spawned %d x %s" % [qty, item_id])


func _on_search_changed(text: String) -> void:
	var query := text.to_lower()
	for entry in row_nodes:
		entry["row"].visible = query == "" or entry["search_text"].contains(query)
