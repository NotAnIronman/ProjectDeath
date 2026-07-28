@tool
extends EditorScript

## ONE-OFF EDITOR TOOL — imports a procedurally generated heightmap (built
## from your top-down island layout image) into Terrain3D as real height
## data, replacing hand-sculpted terrain with smooth, natural slopes.
##
## The height data was generated OUTSIDE Godot (Python: distance-field
## from your island mask -> beach ramp -> inland rise -> plateau ->
## fractal hill noise, and a matching smooth continental-shelf drop-off
## for the ocean floor). This script's only job is getting that data into
## Terrain3D correctly — it does not do any of the shaping itself.
##
## FILE FORMAT: height.raw is raw float32, little-endian, row-major,
## width x height pixels, one float per vertex = height in METERS
## directly (sea level = 0.0). No offset/scale math needed on your end;
## see height_meta.json for the exact width/height/vertex_spacing this
## was generated at.
##
## HOW TO USE:
##   1. Copy height.raw and height_meta.json into your project, e.g.
##      res://data/generated_heightmap/ (update RAW_PATH below if you put
##      it somewhere else).
##   2. Select your Terrain3D node in the scene (or leave nothing
##      selected — this searches the edited scene for one).
##   3. This is a FULL REPLACEMENT of existing regions on that terrain.
##      DELETE_EXISTING_REGIONS defaults to true — set it to false only
##      if you've already manually cleared regions and just want a plain
##      import.
##   4. File > Run (Ctrl+Shift+X).
##   5. Save the scene. Terrain3D's dynamic collision will pick up the
##      new heights automatically; regenerate baked collision if you use
##      static collision instead.
##
## After this, re-run paint_terrain_by_rules.gd — the new height range
## printed below will be different from your old sculpted terrain's, so
## re-tune PLATEAU_HEIGHT / WATER_LEVEL in that script's dry run before
## painting for real.

# --- CONFIG ---
const RAW_PATH: String = "res://data/generated_heightmap/height.raw"
const WIDTH: int = 2048
const HEIGHT: int = 2048
const VERTEX_SPACING_M: float = 2.0
# v3: padded to a multiple of 256/512/1024 (Terrain3D's common region
# sizes) specifically to eliminate the region-boundary seam artifact seen
# with v2's un-aligned 1542x1200 canvas. The extra border beyond the
# original 1542x1200 content is smoothly-blended deep ocean, not new
# usable land.

## Where the top-left corner of the imported map lands in world space.
## Default centers the whole generated map on the world origin — change
## this if you want it placed elsewhere relative to existing content.
const CENTER_ON_ORIGIN: bool = true

const DELETE_EXISTING_REGIONS: bool = true


func _run() -> void:
	var terrain := _find_terrain3d()
	if terrain == null:
		push_error("ImportGeneratedHeightmap: no Terrain3D node found. Select one, or make sure it's in the open scene.")
		return

	var file := FileAccess.open(RAW_PATH, FileAccess.READ)
	if file == null:
		push_error("ImportGeneratedHeightmap: couldn't open %s — copy height.raw into the project first." % RAW_PATH)
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	var expected_bytes: int = WIDTH * HEIGHT * 4
	if bytes.size() != expected_bytes:
		push_error("ImportGeneratedHeightmap: byte size mismatch. Got %d, expected %d (WIDTH*HEIGHT*4). Check WIDTH/HEIGHT match height_meta.json." % [bytes.size(), expected_bytes])
		return

	var height_image := Image.create_from_data(WIDTH, HEIGHT, false, Image.FORMAT_RF, bytes)
	if height_image == null:
		push_error("ImportGeneratedHeightmap: Image.create_from_data failed.")
		return

	terrain.vertex_spacing = VERTEX_SPACING_M

	if DELETE_EXISTING_REGIONS:
		var existing: Array = terrain.data.region_locations.duplicate()
		for loc in existing:
			terrain.data.remove_regionl(loc, false)
		print("ImportGeneratedHeightmap: removed %d existing region(s)." % existing.size())

	var global_position := Vector3.ZERO
	if CENTER_ON_ORIGIN:
		global_position = Vector3(
			-WIDTH * VERTEX_SPACING_M * 0.5,
			0.0,
			-HEIGHT * VERTEX_SPACING_M * 0.5
		)

	# images array is [Height, Control, Color] per Terrain3DData.import_images —
	# we only supply Height, Control/Color stay null (blank/default).
	terrain.data.import_images([height_image, null, null], global_position, 0.0, 1.0)
	terrain.data.update_maps()

	var height_range: Vector2 = terrain.data.get_height_range()
	print("ImportGeneratedHeightmap: done. World size %.0fm x %.0fm at origin offset %s." % [WIDTH * VERTEX_SPACING_M, HEIGHT * VERTEX_SPACING_M, global_position])
	print("ImportGeneratedHeightmap: imported height range = %s. Update PLATEAU_HEIGHT/WATER_LEVEL in paint_terrain_by_rules.gd to match before repainting." % height_range)
	print("ImportGeneratedHeightmap: remember to SAVE the scene now.")


func _find_terrain3d() -> Terrain3D:
	var editor_selection := get_editor_interface().get_selection().get_selected_nodes()
	for node in editor_selection:
		if node is Terrain3D:
			return node

	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return null
	var found := root.find_children("*", "Terrain3D")
	if found.is_empty():
		return null
	return found.front()
