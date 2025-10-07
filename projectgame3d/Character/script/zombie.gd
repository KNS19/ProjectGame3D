extends CharacterBody3D

# --- Constants ---
const ATTACK_RANGE = 1.5
const ATTACK_DAMAGE = 20.0
const ANIM_ATTACK = "Armature|Attack"
const ANIM_HIT_REACTION = "Armature|Hit_reaction" # ✅ แอนิเมชันโดนตี

# --- Variables ---
@export var speed: float = 3.0
var players: Array = []
var is_screaming: bool = false
var is_attacking: bool = false
@export var health: float = 120.0
var is_dead: bool = false
var is_stunned: bool = false # ✅ สถานะสตั้น

# --- Animations ---
const ANIM_WALK = "Armature|Walk2"
const ANIM_IDLE = "Armature|Idle"
const ANIM_SCREAM = "Armature|Scream"
const ANIM_DEATH = "Armature|Die"

# --- Nodes ---
@onready var detection_area: Area3D = $DetectionArea
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var head_area: Area3D = $"RootNode/Armature/Skeleton3D/BoneAttachment3D_Head/HeadArea"
@onready var body_area: Area3D = $"RootNode/Armature/Skeleton3D/BoneAttachment3D_Body/BodyArea"
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

	if is_instance_valid(head_area):
		head_area.area_entered.connect(_on_hit_area_entered.bind("Head"))
	else:
		print("❌ ERROR: HeadArea node is NULL!")

	if is_instance_valid(body_area):
		body_area.area_entered.connect(_on_hit_area_entered.bind("Body"))
	else:
		print("❌ ERROR: BodyArea node is NULL!")

	if anim.has_animation(ANIM_IDLE):
		_play_animation_safe(ANIM_IDLE)

# --------------------------------------------------------------------------------
## ระบบดาเมจและการตาย
# --------------------------------------------------------------------------------

func _on_hit_area_entered(area: Area3D, hit_part: String):
	if area.is_in_group("player_weapon"):
		var weapon_node = area.get_parent()
		if weapon_node:
			var damage_amount: float = 10.0
			if "damage" in weapon_node:
				var val = weapon_node.damage
				if typeof(val) in [TYPE_FLOAT, TYPE_INT]:
					damage_amount = float(val)
			take_damage(damage_amount, hit_part)


func take_damage(damage: float, hit_part: String):
	if is_dead:
		return

	# ✅ หากโดนโจมตี — เล่นแอนิเมชันโดนตี + สตั้น 0.5 วิ
	if anim.has_animation(ANIM_HIT_REACTION) and not is_stunned:
		_do_hit_reaction()

	if hit_part == "Head":
		health = 0.0
		print("HEADSHOT! Zombie took full damage (", damage, ") and died instantly.")
	elif hit_part == "Body":
		health -= damage
		print("Body hit. Zombie took:", damage, " damage. Health remaining:", health)
	else:
		health -= damage
		print("Generic hit. Zombie took:", damage, " damage. Health remaining:", health)

	if health <= 0 and not is_dead:
		_die()


# ✅ ฟังก์ชันเล่นแอนิเมชันโดนตี + สตั้น
func _do_hit_reaction():
	is_stunned = true
	is_attacking = false
	is_screaming = false
	velocity = Vector3.ZERO
	
	# เล่นแอนิเมชันโดนตี
	_play_animation_safe(ANIM_HIT_REACTION)
	
	# ✅ ถ้ามีแอนิเมชันนี้จริง
	if anim.has_animation(ANIM_HIT_REACTION):
		var hit_anim_length = anim.get_animation(ANIM_HIT_REACTION).length
		await get_tree().create_timer(hit_anim_length).timeout
	else:
		# ถ้าไม่มีแอนิเมชันนี้ในไฟล์ ใช้เวลาสั้น ๆ แทน
		await get_tree().create_timer(0.5).timeout
	
	is_stunned = false


# --------------------------------------------------------------------------------
## ระบบตาย
# --------------------------------------------------------------------------------
func _die():
	is_dead = true
	set_physics_process(false)
	velocity = Vector3.ZERO

	if anim.has_animation(ANIM_DEATH):
		_play_animation_safe(ANIM_DEATH)
		if is_instance_valid(anim):
			await anim.animation_finished
	queue_free()

# --------------------------------------------------------------------------------
## AI และการเคลื่อนที่
# --------------------------------------------------------------------------------
func _on_body_entered(body):
	if body.is_in_group("player"):
		if not players.has(body):
			players.append(body)
			if not is_screaming and not is_attacking and players.size() == 1 and anim.has_animation(ANIM_SCREAM):
				_do_scream()

func _on_body_exited(body):
	if players.has(body):
		players.erase(body)

func _do_scream():
	is_screaming = true
	if players.size() > 0:
		look_at(players[0].global_transform.origin, Vector3.UP, true)
	_play_animation_safe(ANIM_SCREAM)
	await anim.animation_finished
	is_screaming = false

func _do_attack():
	is_attacking = true
	_play_animation_safe(ANIM_ATTACK)
	var attack_time = 1.0
	if anim.has_animation(ANIM_ATTACK):
		attack_time = anim.get_animation(ANIM_ATTACK).length
	await get_tree().create_timer(attack_time * 0.5).timeout
	_deal_damage()
	await get_tree().create_timer(attack_time * 0.5).timeout
	is_attacking = false

func _deal_damage():
	for p in players:
		var dist = global_transform.origin.distance_to(p.global_transform.origin)
		if dist <= ATTACK_RANGE:
			if p.has_method("take_damage"):
				p.take_damage(ATTACK_DAMAGE, "zombie_attack")

func _physics_process(delta):
	if is_dead or is_stunned:
		# หยุด XZ movement แต่ gravity ยังทำงาน
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	if is_screaming or is_attacking:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	if players.size() == 0:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		_play_animation_safe(ANIM_IDLE)
		return

	var nearest = players[0]
	var nearest_dist = global_transform.origin.distance_to(nearest.global_transform.origin)

	for p in players:
		var d = global_transform.origin.distance_to(p.global_transform.origin)
		if d < nearest_dist:
			nearest = p
			nearest_dist = d

	look_at(nearest.global_transform.origin, Vector3.UP, true)

	if nearest_dist <= ATTACK_RANGE:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		if not is_attacking and anim.has_animation(ANIM_ATTACK):
			_do_attack()
	else:
		var dir = (nearest.global_transform.origin - global_transform.origin).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		_play_animation_safe(ANIM_WALK)

func _play_animation_safe(animation_name: String):
	if anim and anim.has_animation(animation_name):
		if anim.current_animation != animation_name:
			anim.play(animation_name)
