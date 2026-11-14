extends Node3D
const BOT_COUNT := 12
var player: CharacterBody3D
var bots: Array[CharacterBody3D] = []
var zone_radius := 42.0
var elapsed := 0.0
var kills := 0
var health := 100.0
var ammo := 30
var fire_cooldown := 0.0
var game_over := false
var hud: Label
var info: Label
var zone_mesh: MeshInstance3D
var camera: Camera3D

func _ready() -> void:
	_build_world()
	_build_player()
	_spawn_bots()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55,0.62,0.72)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	_make_box("Ground",Vector3(0,-0.6,0),Vector3(90,1,90),Color(0.20,0.34,0.20))
	for i in range(34):
		var p := Vector3(randf_range(-42,42),0,randf_range(-42,42))
		if Vector2(p.x,p.z).length() < 10: continue
		if i % 2 == 0:
			_make_box("Cover",p+Vector3(0,1,0),Vector3(3,2,3),Color(0.35,0.37,0.38))
		else:
			_make_box("Tree",p+Vector3(0,1.5,0),Vector3(0.8,3,0.8),Color(0.25,0.14,0.07))
	zone_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = zone_radius
	cyl.bottom_radius = zone_radius
	cyl.height = 0.06
	zone_mesh.mesh = cyl
	zone_mesh.position.y = 0.06
	var zm := StandardMaterial3D.new()
	zm.albedo_color = Color(0.1,0.5,1.0,0.12)
	zm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mesh.material_override = zm
	add_child(zone_mesh)

func _make_box(n: String,p: Vector3,s: Vector3,c: Color) -> void:
	var b := StaticBody3D.new()
	b.name=n
	b.position=p
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=s
	m.mesh=mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color=c
	m.material_override=mat
	b.add_child(m)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=s
	col.shape=shape
	b.add_child(col)
	add_child(b)

func _build_player() -> void:
	player=CharacterBody3D.new()
	player.name="Player"
	player.position=Vector3(0,1,0)
	var mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.height=2
	mesh.mesh=cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(0.05,0.55,1)
	mesh.material_override=mat
	player.add_child(mesh)
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.height=2
	col.shape=cs
	player.add_child(col)
	camera=Camera3D.new()
	camera.position=Vector3(0,0.65,0)
	camera.current=true
	player.add_child(camera)
	add_child(player)

func _spawn_bots() -> void:
	for i in range(BOT_COUNT):
		var bot := CharacterBody3D.new()
		bot.name="Enemy_%02d" % i
		var a := TAU*float(i)/BOT_COUNT
		bot.position=Vector3(cos(a)*randf_range(18,34),1,sin(a)*randf_range(18,34))
		var mesh := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.height=2
		mesh.mesh=cap
		var mat := StandardMaterial3D.new()
		mat.albedo_color=Color(0.85,0.16,0.12)
		mesh.material_override=mat
		bot.add_child(mesh)
		var col := CollisionShape3D.new()
		var cs := CapsuleShape3D.new()
		cs.height=2
		col.shape=cs
		bot.add_child(col)
		add_child(bot)
		bots.append(bot)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud=Label.new()
	hud.position=Vector2(20,18)
	hud.add_theme_font_size_override("font_size",22)
	hud.add_theme_color_override("font_color",Color.WHITE)
	layer.add_child(hud)
	info=Label.new()
	info.anchor_left=0.5
	info.anchor_top=1
	info.anchor_right=0.5
	info.anchor_bottom=1
	info.position=Vector2(-240,-45)
	info.text="WASD Move | Mouse Aim | Click Shoot | R Reload"
	info.add_theme_font_size_override("font_size",18)
	info.add_theme_color_override("font_color",Color.WHITE)
	layer.add_child(info)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x*0.0025)
		camera.rotate_x(-event.relative.y*0.0025)
		camera.rotation.x=clampf(camera.rotation.x,-1.2,1.2)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: _shoot()
		if event.button_index==MOUSE_BUTTON_RIGHT: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if event.keycode==KEY_R: ammo=30

func _physics_process(delta: float) -> void:
	if game_over: return
	elapsed+=delta
	fire_cooldown=maxf(0,fire_cooldown-delta)
	var input_dir:=Vector2(float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A)),float(Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_W))).normalized()
	var dir: Vector3=(player.transform.basis*Vector3(input_dir.x,0,input_dir.y)).normalized()
	player.velocity.x=dir.x*8
	player.velocity.z=dir.z*8
	if not player.is_on_floor(): player.velocity.y-=24*delta
	else: player.velocity.y=-0.5
	player.move_and_slide()
	for bot in bots.duplicate():
		if not is_instance_valid(bot): bots.erase(bot); continue
		var toward:=player.global_position-bot.global_position
		var dist:=toward.length()
		if dist>4:
			var v:=toward.normalized()
			bot.velocity.x=v.x*2.4
			bot.velocity.z=v.z*2.4
			bot.look_at(Vector3(player.global_position.x,bot.global_position.y,player.global_position.z))
		else:
			bot.velocity.x=0
			bot.velocity.z=0
			if randf()<delta*0.22: health-=5
		bot.move_and_slide()
		if Vector2(bot.position.x,bot.position.z).length()>zone_radius:
			bot.queue_free()
			bots.erase(bot)
	zone_radius=maxf(12,42-elapsed*0.22)
	var cm:=zone_mesh.mesh as CylinderMesh
	cm.top_radius=zone_radius
	cm.bottom_radius=zone_radius
	if Vector2(player.position.x,player.position.z).length()>zone_radius: health-=delta*8
	health=clampf(health,0,100)
	hud.text="ABHI FIRE ROYAL | HP %d | AMMO %d/30 | KILLS %d | ENEMIES %d | ZONE %dm" % [int(health),ammo,kills,bots.size(),int(zone_radius)]
	if health<=0:
		game_over=true
		info.text="ELIMINATED - KILLS: %d" % kills
	elif bots.is_empty():
		game_over=true
		info.text="BOOYAH! CHAMPION!"

func _shoot() -> void:
	if game_over or fire_cooldown>0 or ammo<=0: return
	ammo-=1
	fire_cooldown=0.18
	var origin:=camera.global_position
	var target:=origin-camera.global_transform.basis.z*100
	var query:=PhysicsRayQueryParameters3D.create(origin,target)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var obj: Object=hit.collider
		if obj is CharacterBody3D and obj!=player and str(obj.name).begins_with("Enemy"):
			bots.erase(obj)
			obj.queue_free()
			kills+=1
