extends Camera2D

export(bool) var free_camera = false
export(bool) var zoomed = true

const SMALL_WINDOW = Vector2(960, 540)
const MAX_WINDOW_SIZE = Vector2(1920 - 160, 1080)

onready var hud = get_node('HUD')

var init_pos = Vector2(0, 0)
var holding_cam = false
var _window_size = OS.window_size
var _offset = Vector2(10, 20)

func _ready():
	self.z_index = 2
	if not zoomed:
		self.offset = _offset
		self.zoom = Vector2(2, 2)
		get_node('HUD').rect_scale = Vector2(2, 2)
		OS.window_resizable = false

func _input(event):
	if event.is_action_pressed('ui_camera'):
		init_pos = get_viewport().get_mouse_position() + self.offset
		holding_cam = true
		hud.hide_popup()
	elif event.is_action_released('ui_camera'):
		holding_cam = false
	elif event.is_action_pressed('ui_zoom_in'):
		if OS.window_size.x <= MAX_WINDOW_SIZE.x:
			OS.window_size = _window_size
		OS.window_resizable = true
		if self.zoom != Vector2(1, 1):
			self.zoom = Vector2(1, 1)
			get_node('HUD').rect_scale = Vector2(1, 1)
			self.offset = get_viewport().get_mouse_position() + _offset
			get_tree().call_group('tower', 'update_circle_texture')
			get_tree().call_group('dummy_tower', 'update_circle_texture')
	elif event.is_action_pressed('ui_zoom_out') and OS.window_size <= SMALL_WINDOW:
		self.offset = _offset
		self.zoom = Vector2(2, 2)
		get_viewport().warp_mouse(get_viewport().get_mouse_position())
		get_node('HUD').rect_scale = Vector2(2, 2)
		OS.window_resizable = false
		get_tree().call_group('tower', 'update_circle_texture')
		get_tree().call_group('dummy_tower', 'update_circle_texture')

func _physics_process(delta):
	if holding_cam and self.zoom == Vector2(1, 1):
		change_camera_offset()
	if not free_camera:
		self.offset = Vector2(min(self.offset.x, MAX_WINDOW_SIZE.x - OS.window_size.x + 2 * _offset.x), \
		                      min(self.offset.y, MAX_WINDOW_SIZE.y - OS.window_size.y + 2 * _offset.y))
		_window_size = Vector2(min(OS.window_size.x, MAX_WINDOW_SIZE.x), \
		                       min(OS.window_size.y, MAX_WINDOW_SIZE.y))
		if OS.window_size != _window_size:
			OS.window_resizable = false
			if self.zoom == Vector2(2, 2):
				OS.window_size = _window_size
			self.offset.x = 0

func change_camera_offset():
	var cur_pos = get_viewport().get_mouse_position()
	var cur_offset = init_pos - cur_pos
	if not free_camera:
		var diff = MAX_WINDOW_SIZE - OS.window_size + 2 * _offset
		if cur_offset.x < 0 or cur_offset.x > diff.x:
			init_pos = Vector2(cur_pos.x + self.offset.x, init_pos.y)
		if cur_offset.y < 0 or cur_offset.y > diff.y:
			init_pos = Vector2(init_pos.x, cur_pos.y + self.offset.y)
		cur_offset.x = min(max(0, cur_offset.x), diff.x)
		cur_offset.y = min(max(0, cur_offset.y), diff.y)
	self.offset = cur_offset
