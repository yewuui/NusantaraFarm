class_name ZoneTileBuilder
extends RefCounted
## Builds a shared Pixel Art TileSet and fills TileMapLayers deterministically for each zone.

const TILE_SIZE := Vector2i(16, 16)

# Atlas coordinates in res://assets/tilesets/terrain_atlas.png (8x4 grid)
const T_GRASS := Vector2i(0, 0)
const T_FLOWER := Vector2i(1, 0)
const T_DIRT := Vector2i(2, 0)
const T_SOIL_EMPTY := Vector2i(3, 0)
const T_TILLED_DRY := Vector2i(4, 0)
const T_TILLED_WET := Vector2i(5, 0)
const T_WATER := Vector2i(6, 0)
const T_SAND := Vector2i(7, 0)
const T_BRIDGE := Vector2i(0, 1)
const T_JOGLO_FLOOR := Vector2i(1, 1)
const T_JOGLO_WALL := Vector2i(2, 1)
const T_MINE_FLOOR := Vector2i(3, 1)
const T_CLIFF := Vector2i(4, 1)
const T_FOREST_FLOOR := Vector2i(5, 1)
const T_SAWIT_FLOOR := Vector2i(6, 1)
const T_PAVING := Vector2i(7, 1)
const T_FENCE := Vector2i(0, 2)
const T_PORTAL_MAT := Vector2i(1, 2)
const T_BLOCKED := Vector2i(2, 2)
const T_OCEAN := Vector2i(3, 2)

const SOLID_TILES := [
	T_WATER, T_JOGLO_WALL, T_CLIFF, T_FENCE, T_OCEAN,
]

static var _cached_tileset: TileSet


static func get_tileset() -> TileSet:
	if _cached_tileset != null:
		return _cached_tileset

	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	ts.add_physics_layer(0)

	var atlas := TileSetAtlasSource.new()
	var tex_path := "res://assets/tilesets/terrain_atlas.png"
	if ResourceLoader.exists(tex_path):
		atlas.texture = load(tex_path) as Texture2D
	atlas.texture_region_size = TILE_SIZE
	ts.add_source(atlas, 0)

	var poly := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	for y in range(3):
		for x in range(8):
			var c := Vector2i(x, y)
			if y == 2 and x > 3:
				continue
			atlas.create_tile(c)
			if c in SOLID_TILES:
				var td := atlas.get_tile_data(c, 0)
				if td != null:
					td.set_collision_polygons_count(0, 1)
					td.set_collision_polygon_points(0, 0, poly)

	_cached_tileset = ts
	return ts


static func build_zone(zone_id: String, ground: TileMapLayer, detail: TileMapLayer, soil: TileMapLayer) -> Rect2i:
	var ts := get_tileset()
	ground.tile_set = ts
	detail.tile_set = ts
	soil.tile_set = ts
	ground.clear()
	detail.clear()
	soil.clear()

	match zone_id:
		"kebun":
			return _build_kebun(ground, detail)
		"joglo_interior":
			return _build_joglo_interior(ground, detail)
		"desa_pasar":
			return _build_desa_pasar(ground, detail)
		"balai_desa":
			return _build_balai_desa(ground, detail)
		"hutan":
			return _build_hutan(ground, detail)
		"sawit":
			return _build_sawit(ground, detail)
		"pantai":
			return _build_pantai(ground, detail)
		"tambang":
			return _build_tambang(ground, detail)
	return Rect2i(0, 0, 30, 18)


static func _fill_rect(layer: TileMapLayer, x0: int, y0: int, w: int, h: int, coords: Vector2i) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			layer.set_cell(Vector2i(x, y), 0, coords)


static func _border_rect(layer: TileMapLayer, w: int, h: int, coords: Vector2i) -> void:
	for x in range(w):
		layer.set_cell(Vector2i(x, 0), 0, coords)
		layer.set_cell(Vector2i(x, h - 1), 0, coords)
	for y in range(h):
		layer.set_cell(Vector2i(0, y), 0, coords)
		layer.set_cell(Vector2i(w - 1, y), 0, coords)


static func _build_kebun(g: TileMapLayer, d: TileMapLayer) -> Rect2i:
	var w := 36
	var h := 24
	_fill_rect(g, 0, 0, w, h, T_GRASS)
	for i in range(0, w * h, 11):
		g.set_cell(Vector2i(i % w, (i / w) % h), 0, T_FLOWER)

	# River along eastern edge + wooden bridge to Desa Utama
	_fill_rect(g, 28, 0, 3, h, T_WATER)
	_fill_rect(g, 28, 10, 3, 3, T_BRIDGE)
	# Dirt paths
	_fill_rect(g, 2, 10, 34, 3, T_DIRT)
	_fill_rect(g, 14, 13, 3, 11, T_DIRT)
	# Farmable field rectangle (x: 6..21, y: 13..20)
	_fill_rect(g, 6, 13, 16, 8, T_SOIL_EMPTY)

	_border_rect(d, w, h, T_FENCE)
	# Open portals: East (to Desa), South (to Sawit), North Joglo door
	d.erase_cell(Vector2i(w - 1, 10))
	d.erase_cell(Vector2i(w - 1, 11))
	d.erase_cell(Vector2i(w - 1, 12))
	d.erase_cell(Vector2i(14, h - 1))
	d.erase_cell(Vector2i(15, h - 1))
	d.erase_cell(Vector2i(16, h - 1))
	g.set_cell(Vector2i(w - 1, 11), 0, T_PORTAL_MAT)
	g.set_cell(Vector2i(15, h - 1), 0, T_PORTAL_MAT)
	return Rect2i(6, 13, 16, 8)


static func _build_joglo_interior(g: TileMapLayer, d: TileMapLayer) -> Rect2i:
	var w := 20
	var h := 14
	_fill_rect(g, 0, 0, w, h, T_JOGLO_FLOOR)
	_border_rect(d, w, h, T_JOGLO_WALL)
	d.erase_cell(Vector2i(9, h - 1))
	d.erase_cell(Vector2i(10, h - 1))
	g.set_cell(Vector2i(9, h - 1), 0, T_PORTAL_MAT)
	g.set_cell(Vector2i(10, h - 1), 0, T_PORTAL_MAT)
	return Rect2i(0, 0, 0, 0)


static func _build_desa_pasar(g: TileMapLayer, d: TileMapLayer) -> Rect2i:
	var w := 38
	var h := 24
	_fill_rect(g, 0, 0, w, h, T_GRASS)
	_fill_rect(g, 0, 10, w, 3, T_DIRT)
	_fill_rect(g, 16, 0, 3, h, T_DIRT)
	_fill_rect(g, 11, 7, 15, 10, T_PAVING) # Alun-alun & Pasar

	_border_rect(d, w, h, T_FENCE)
	# West to Kebun
	for y in range(10, 13):
		d.erase_cell(Vector2i(0, y))
	g.set_cell(Vector2i(0, 11), 0, T_PORTAL_MAT)
	# North to Hutan
	for x in range(16, 19):
		d.erase_cell(Vector2i(x, 0))
	g.set_cell(Vector2i(17, 0), 0, T_PORTAL_MAT)
	# South to Pantai
	for x in range(16, 19):
		d.erase_cell(Vector2i(x, h - 1))
	g.set_cell(Vector2i(17, h - 1), 0, T_PORTAL_MAT)
	return Rect2i(0, 0, 0, 0)


static func _build_balai_desa(g: TileMapLayer, d: TileMapLayer) -> Rect2i:
	var w := 20
	var h := 14
	_fill_rect(g, 0, 0, w, h, T_JOGLO_FLOOR)
	_fill_rect(g, 4, 3, 12, 8, T_PAVING)
	_border_rect(d, w, h, T_JOGLO_WALL)
	d.erase_cell(Vector2i(9, h - 1))
	d.erase_cell(Vector2i(10, h - 1))
	g.set_cell(Vector2i(9, h - 1), 0, T_PORTAL_MAT)
	g.set_cell(Vector2i(10, h - 1), 0, T_PORTAL_MAT)
	return Rect2i(0, 0, 0, 0)


static func _build_hutan(g: TileMapLayer, d: TileMapLayer) -> Rect2i:
	var w := 36
	var h := 24
	_fill_rect(g, 0, 0, w, h, T_FOREST_FLOOR)
	_fill_rect(g, 16, 12, 3, 12, T_DIRT)
	_fill_rect(g, 16, 10, 20, 3, T_DIRT)
	_border_rect(d, w, h, T_CLIFF)
	for x in range(16, 19):
		d.erase_cell(Vector2i(x, h - 1))
	for y in range(10, 13):
		d.erase_cell(Vector2i(w - 1, y))
	g.set_cell(Vector2i(17, h - 1), 0, T_PORTAL_MAT)
	g.set_cell(Vector2i(w - 1, 11), 0, T_PORTAL_MAT)
	return Rect2i(0, 0, 0, 0)


static func _build_sawit(g: TileMapLayer, d: TileMapLayer) -> Rect2i:
	var w := 36
	var h := 24
	_fill_rect(g, 0, 0, w, h, T_SAWIT_FLOOR)
	_fill_rect(g, 14, 0, 3, 20, T_DIRT)
	_fill_rect(g, 5, 6, 26, 14, T_SOIL_EMPTY)
	_fill_rect(g, 14, 0, 3, 6, T_DIRT)
	_border_rect(d, w, h, T_FENCE)
	for x in range(14, 17):
		d.erase_cell(Vector2i(x, 0))
	g.set_cell(Vector2i(15, 0), 0, T_PORTAL_MAT)
	return Rect2i(5, 6, 26, 14)


static func _build_pantai(g: TileMapLayer, d: TileMapLayer) -> Rect2i:
	var w := 36
	var h := 24
	_fill_rect(g, 0, 0, w, 6, T_GRASS)
	_fill_rect(g, 0, 6, w, 10, T_SAND)
	_fill_rect(g, 0, 16, w, 8, T_OCEAN)
	_fill_rect(g, 16, 0, 3, 10, T_DIRT)
	_fill_rect(g, 16, 14, 3, 6, T_BRIDGE) # Dermaga memancing
	_border_rect(d, w, h, T_FENCE)
	for x in range(16, 19):
		d.erase_cell(Vector2i(x, 0))
	g.set_cell(Vector2i(17, 0), 0, T_PORTAL_MAT)
	return Rect2i(0, 0, 0, 0)


static func _build_tambang(g: TileMapLayer, d: TileMapLayer) -> Rect2i:
	var w := 36
	var h := 24
	_fill_rect(g, 0, 0, w, h, T_MINE_FLOOR)
	_fill_rect(g, 0, 10, 26, 3, T_DIRT)
	_border_rect(d, w, h, T_CLIFF)
	for y in range(10, 13):
		d.erase_cell(Vector2i(0, y))
	g.set_cell(Vector2i(0, 11), 0, T_PORTAL_MAT)
	return Rect2i(0, 0, 0, 0)
