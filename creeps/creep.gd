extends Node2D

const CREEP_INFO = preload('res://creeps/creep_info.gd')

onready var hp_bar = get_node('Z-Index/TextureProgress')
onready var tween = get_node('Tween')
onready var map = get_node('../../Map')
onready var sprite = get_node('Sprite')
onready var anim = get_node('AnimationPlayer')
onready var hud = get_node('/root/Main/Camera2D/HUD')
onready var projectiles_node = get_node('/root/Main/Projectiles')
onready var creep_info = CREEP_INFO.new()

var max_hp
var hp
var vel
var value
var weakness
var strength
var spawner
var projectiles = {}
var towers = []
var offset
var under_fx = [false, false, false]
var dying = false
var path = null
var spawn_graph
var spawn_path
var polygon = PoolVector2Array([Vector2(-16, -16), Vector2(-16, 16), \
		Vector2(16, 16), Vector2(16, -16)])

func _ready():
	max_hp = map.a_star.creep_info.get_creep_hp(self.name)
	hp = max_hp
	vel = map.a_star.creep_info.get_creep_vel(self.name)
	value = int(hp * vel / 40)
	weakness = map.a_star.creep_info.get_creep_weakness(self.name)
	strength = map.a_star.creep_info.get_creep_strength(self.name)
	hp_bar.max_value = hp
	hp_bar.get_parent().z_index = 1
	if anim.has_animation('move'):
		anim.play('move')
	spawn_graph = map.a_star.get_spawn_graph(self.name)
	spawn_path = map.a_star.get_spawn_path(map, self.name, self.position - offset)
	move(null, null)

func _physics_process(delta):
	if self.position.x > 0 and self.position.y > 0:
		self.get_node('Area2D/CollisionPolygon2D').polygon = polygon
		set_physics_process(false)

func die():
	dying = true
	tween.stop_all()
	hud.update_gold(self.value)
	for tower in towers:
		tower.nearby_creeps.erase(self)
	for proj in projectiles_node.get_children():
		if proj in projectiles.values():
			if proj.tower.nearby_creeps.size() > 0:
				proj.creep = proj.tower.nearby_creeps[0]
				proj.creep.projectiles[proj.name] = proj
			else:
				create_dummy_creep(proj)
	self.get_node('Area2D').monitoring = false
	if anim.has_animation('death'):
		anim.play('death')
		anim.playback_speed = 1
		yield(anim, 'animation_finished')
	self.queue_free()

func create_dummy_creep(proj):
	var node = Node2D.new()
	var node_area = self.get_node('Area2D').duplicate( \
			DUPLICATE_USE_INSTANCING)
	node.position = proj.creep.position
	node.add_child(node_area)
	node.add_to_group(proj.name)
	get_parent().add_child(node)
	proj.creep = node

func take_damage(dmg, gem_color = ''):
	if gem_color == weakness:
		dmg *= 2
	elif gem_color == strength:
		dmg = float(dmg)/2
	hp -= dmg
	hp_bar.value += dmg
	if not hp_bar.visible:
		hp_bar.visible = true
		if anim.has_animation('move-wounded'):
			anim.play('move-wounded')
	if hp <= 0 and not dying:
		die()

func move(object, key):
	var target = spawner.get_next_point(self.position - offset, self) + offset
	tween.interpolate_property(self, 'position', self.position, \
	      target, float(100)/vel, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	rotate_sprite(target)

func rotate_sprite(target):
	var vector = self.position - target
	sprite.rotation = vector.angle() - PI/2

func poison(dmg):
	for i in range(0, 10):
		yield(get_tree().create_timer(.1), 'timeout')
		self.take_damage(float(dmg)/10, 'Green Gem')
	under_fx[0] = false

func shock():
	yield(get_tree().create_timer(1), 'timeout')
	under_fx[1] = false
	self.tween.playback_speed = 1
	self.anim.playback_speed = 1

func slow_down():
	yield(get_tree().create_timer(3), 'timeout')
	under_fx[2] = false
	self.tween.playback_speed = 1
	self.anim.playback_speed = 1

func splash(splash_area, dmg):
	yield(get_tree(), 'physics_frame')
	yield(get_tree(), 'physics_frame')
	for creep_area in splash_area.get_overlapping_areas():
		var _creep = creep_area.get_parent()
		if _creep != self and _creep.is_in_group('creep'):
			_creep.take_damage(float(dmg)/2, 'Red Gem')
	splash_area.queue_free()

func _on_Creep_tree_exited():
	map.get_node('../WaveManager').creep_exited()
