extends Node2D

const CREEP_SPAWNER = preload('res://terrain/creep_spawner/creep_spawner.tscn')
const DUMMY_TOWER = preload('res://tower/dummy_tower.tscn')
const TOWER = preload('res://tower/tower.tscn')
const TS_DB = preload('res://terrain/tiles/tileset_db.gd')

var LEFT =       Vector2(1, 0).rotated(-PI)
var DOWN_LEFT =  Vector2(1, 0).rotated(-2*PI/3)
var DOWN_RIGHT = Vector2(1, 0).rotated(-PI/3)
var RIGHT =      Vector2(1, 0).rotated(0)
var UP_RIGHT =   Vector2(1, 0).rotated(PI/3)
var UP_LEFT =    Vector2(1, 0).rotated(2*PI/3)

onready var hud = get_node('../Camera2D/HUD')
onready var spawner_manager = get_node('../SpawnerManager')
onready var towers = get_node('../Towers')
onready var tilemap = get_node('TileMap')
onready var dummy_towers = get_node('DummyTowers')
onready var ts_db = TS_DB.new()
onready var a_star = AStar.new()

var is_dummy_towers_visible = false
var adj_cells_dict = {}
var idx_dict = {}
var grass_coord = []
var offset
var base
var base_tile

func _ready():
	offset = Vector2(tilemap.cell_size.x / 2, \
		tilemap.cell_size.y * 5/8 + tilemap.cell_quadrant_size / 2 + tilemap.position.y)
	base_tile = tilemap.map_to_world(Vector2(13, 9))
	generate_procedural_map()
#	generate_AStar_graph()

func generate_procedural_map():
	for i in range(-1, 16):
		for j in range(-1, 11):
			tilemap.set_cellv(Vector2(i, j), ts_db.GRASS)
	tilemap.set_cellv(Vector2(2, -1), ts_db.DR_UL)
	tilemap.set_cellv(Vector2(-1, 7), ts_db.L_R)
	randomize()
	var bias1 = -1#-randf()
	var bias2 = 1#randf()
	var in_tile_dir1 = UP_LEFT
	var in_tile_dir2 = LEFT
	var cell1 = Vector2(3, 0)
	var cell2 = Vector2(0, 7)
	var info
	while cell1 != null or cell2 != null:
		yield(get_tree(), 'physics_frame')
		info = generate_tile(cell1, bias1, in_tile_dir1)
		cell1 = info[0]
		in_tile_dir1 = info[1]
		yield(get_tree(), 'physics_frame')
		info = generate_tile(cell2, bias2, in_tile_dir2)
		cell2 = info[0]
		in_tile_dir2 = info[1]
#	generate_AStar_graph()
	generate_procedural_map()

func generate_tile(cell, bias, in_tile_dir):
	if cell == null:
		return [null, null, null]
	var length = (base_tile - tilemap.map_to_world(cell)).length() / 3000
	if length < 0.1:
		length = 0
#	print(length)
	var angle = (base_tile - tilemap.map_to_world(cell)).angle_to(Vector2(1, 0))
	var rand = gaussian(bias, length)
	var target_vector = Vector2(1, 0).rotated(angle).rotated(rand)
	var out_tile_dir = get_next_tile_direction(in_tile_dir, target_vector)
	if cell.y < 0 or cell.y > 8 or cell.x < 1 or cell.x > 12:
		out_tile_dir = get_next_tile_direction(in_tile_dir, Vector2(1, 0).rotated(angle))
		bias *= -1.0/2.0
	if tilemap.get_cellv(cell) == ts_db.GRASS:
		tilemap.set_cellv(cell, ts_db.get_tile_id(self, in_tile_dir, out_tile_dir))
	else:
		if tilemap.get_cellv(cell) in ts_db.BRANCHED_TILE:
			return generate_tile(cell, -bias, in_tile_dir)
		tilemap.set_cellv(cell, ts_db.branch(self, tilemap.get_cellv(cell), in_tile_dir))
		return [null, null, null]
	cell = get_cell(cell, out_tile_dir)
	if cell == Vector2(13, 9):
		return [null, null, null]
	else:
		return [cell, get_in_tile_dir(out_tile_dir), bias]

func get_in_tile_dir(out_tile_dir):
	if out_tile_dir == LEFT:
		return RIGHT
	elif out_tile_dir == DOWN_LEFT:
		return UP_RIGHT
	elif out_tile_dir == DOWN_RIGHT:
		return UP_LEFT
	elif out_tile_dir == RIGHT:
		return LEFT
	elif out_tile_dir == UP_RIGHT:
		return DOWN_LEFT
	elif out_tile_dir == UP_LEFT:
		return DOWN_RIGHT

func get_cell(cell, out_tile_dir):
	if out_tile_dir == LEFT:
		return Vector2(cell.x - 1, cell.y)
	if out_tile_dir == DOWN_LEFT:
		return Vector2(cell.x - int(abs(cell.y) + 1) % 2, cell.y + 1)
	if out_tile_dir == DOWN_RIGHT:
		return Vector2(cell.x + int(abs(cell.y)) % 2, cell.y + 1)
	if out_tile_dir == RIGHT:
		return Vector2(cell.x + 1, cell.y)
	if out_tile_dir == UP_RIGHT:
		return Vector2(cell.x + int(abs(cell.y)) % 2, cell.y - 1)
	if out_tile_dir == UP_LEFT:
		return Vector2(cell.x - int(abs(cell.y) + 1) % 2, cell.y - 1)

func get_angle_vector(in_tile_dir, target_vector):
	var angles = []
	if in_tile_dir != LEFT:
		angles.append(target_vector.angle_to(LEFT))
	if in_tile_dir != DOWN_LEFT:
		angles.append(target_vector.angle_to(DOWN_LEFT))
	if in_tile_dir != DOWN_RIGHT:
		angles.append(target_vector.angle_to(DOWN_RIGHT))
	if in_tile_dir != RIGHT:
		angles.append(target_vector.angle_to(RIGHT))
	if in_tile_dir != UP_RIGHT:
		angles.append(target_vector.angle_to(UP_RIGHT))
	if in_tile_dir != UP_LEFT:
		angles.append(target_vector.angle_to(UP_LEFT))
	return angles

func get_next_tile_direction(in_tile_dir, target_vector):
	var angles = get_angle_vector(in_tile_dir, target_vector)
	var min_angle = INF
	for angle in angles:
		if abs(angle) < min_angle:
			min_angle = abs(angle)
	if min_angle == abs(target_vector.angle_to(LEFT)):
		return LEFT
	if min_angle == abs(target_vector.angle_to(DOWN_LEFT)):
		return DOWN_LEFT
	if min_angle == abs(target_vector.angle_to(DOWN_RIGHT)):
		return DOWN_RIGHT
	if min_angle == abs(target_vector.angle_to(RIGHT)):
		return RIGHT
	if min_angle == abs(target_vector.angle_to(UP_RIGHT)):
		return UP_RIGHT
	if min_angle == abs(target_vector.angle_to(UP_LEFT)):
		return UP_LEFT

func gaussian(mean, deviation):
	var x1
	var x2
	var w
	if deviation == 0:
		return mean
	while true:
		randomize()
		x1 = rand_range(0, 2) - 1
		x2 = rand_range(0, 2) - 1
		w = x1*x1 + x2*x2
		if 0 < w and w < 1:
			break
	w = sqrt(-2 * log(w)/w)
	return mean + deviation * x1 * w

func generate_AStar_graph():
	for cell in tilemap.get_used_cells():
		var pos = tilemap.map_to_world(cell) + offset
		if tilemap.get_cellv(cell) != ts_db.GRASS:
			adj_cells_dict[pos] = get_adj_cells(cell)
			_add_point(pos)
		else:
			grass_coord.append(pos)
	for key in adj_cells_dict.keys():
		for value in adj_cells_dict[key]:
			a_star.connect_points(idx_dict[key], idx_dict[value], false)
	create_dummy_towers()

func get_adj_cells(cell):
	var adj_cells = PoolVector2Array([])
	var even = int(cell.y + 1) % 2
	var dl = Vector2(cell.x - even, cell.y + 1)
	var dr = Vector2(cell.x - even + 1, cell.y + 1)
	var l  = Vector2(cell.x - 1, cell.y)
	var r  = Vector2(cell.x + 1, cell.y)
	var ul = Vector2(cell.x - even, cell.y - 1)
	var ur = Vector2(cell.x - even + 1, cell.y - 1)
	adj_cells = add_adj_cell(cell, ts_db.DL, dl, adj_cells)
	adj_cells = add_adj_cell(cell, ts_db.DR, dr, adj_cells)
	adj_cells = add_adj_cell(cell,  ts_db.L,  l, adj_cells)
	adj_cells = add_adj_cell(cell,  ts_db.R,  r, adj_cells)
	adj_cells = add_adj_cell(cell, ts_db.UL, ul, adj_cells)
	adj_cells = add_adj_cell(cell, ts_db.UR, ur, adj_cells)
	return adj_cells

func _add_point(_pos):
	var idx = a_star.get_available_point_id()
	a_star.add_point(idx, Vector3(_pos.x, _pos.y, 0))
	idx_dict[_pos] = idx

func add_adj_cell(cur_cell, ARRAY, next_cell, adj_cells):
	var next_cell_tile = tilemap.get_cellv(next_cell)
	var pos = tilemap.map_to_world(next_cell) + offset
	if tilemap.get_cellv(cur_cell) in ARRAY:
		if next_cell_tile != ts_db.GRASS:
			if next_cell_tile != ts_db.NONE:
				adj_cells.append(pos)
			else:
				var creep_spawner = CREEP_SPAWNER.instance()
				creep_spawner.position = pos
				spawner_manager.add_child(creep_spawner)
				adj_cells_dict[pos] = PoolVector2Array([tilemap.map_to_world(cur_cell) + offset])
				_add_point(pos)
		else:
			base = pos
			adj_cells.append(pos)
			_add_point(pos)
	return adj_cells

func create_dummy_towers():
	for pos in grass_coord:
		var dummy_tower = DUMMY_TOWER.instance()
		dummy_tower.position = pos
		dummy_tower.visible = false
		dummy_towers.add_child(dummy_tower)

func _input(event):
	if event.is_action_pressed('ui_buy_tower') and hud.gold >= hud.tower_price:
		show_dummy_towers()

func show_dummy_towers():
	is_dummy_towers_visible = true
	for dummy_tower in dummy_towers.get_children():
		dummy_tower.visible = true

func hide_dummy_towers():
	is_dummy_towers_visible = false
	for dummy_tower in dummy_towers.get_children():
		dummy_tower.visible = false

func place_tower(pos):
	var tower = TOWER.instance()
	tower.position = pos
	towers.add_child(tower)
	hud.update_gold(-hud.tower_price)
	hud.tower_price += 200
	tower.draw_circle = true
	tower.update()
	hide_dummy_towers()
