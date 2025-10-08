extends CharacterBody3D

# --- Constants ---
const ATTACK_RANGE = 1.5
const ATTACK_DAMAGE = 10.0
const ANIM_ATTACK = "Punch"
const ANIM_HIT_REACTION = "HitReact"

# --- Variables ---
@export var speed: float = 5.0
var players: Array = []
var is_screaming: bool = false
var is_attacking: bool = false
@export var health: float = 75.0
var is_dead: bool = false
var is_stunned: bool = false

var score_value: int = 100  # ปรับค่าได้ตามประเภทซอมบี้
# --- Attack cooldown ---
@export var attack_cooldown: float = 1.0
var last_attack_time: float = -10.0

# --- Stun duration ---
@export var stun_duration: float = 0.75
# --- Gravity ---
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Animations ---
const ANIM_WALK = "Walk"
const ANIM_IDLE = "Idle"
const ANIM_SCREAM = "Idle_Attack"
const ANIM_DEATH = "Death"

# --- Nodes ---
# ❌ ตัด DetectionArea ออก — ไม่ใช้แล้ว
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var head_area: Area3D = $"RootNode/CharacterArmature/Skeleton3D/BoneAttachment3D_Head/HeadArea"
@onready var body_area: Area3D = $"RootNode/CharacterArmature/Skeleton3D/BoneAttachment3D_Body/BodyArea"
@onready var loop_sfx: AudioStreamPlayer3D = $LoopSfx
@onready var footstep_sfx: AudioStreamPlayer3D = $WalkSfx

func _ready():
	# ✅ ดึงผู้เล่นทั้งหมดจาก group "player" ตั้งแต่เริ่มเกม
	players = get_tree().get_nodes_in_group("player")

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

	# 🔊 เริ่มเล่นเสียงวน
	if loop_sfx and loop_sfx.stream:
		loop_sfx.stream.set_loop(true)
		loop_sfx.play()

# --------------------------------------------------------------------------------
## ระบบดาเมจและการตาย (ไม่เปลี่ยน)
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

func take_damage(damage: float, hit_part: String = "Body"):
	if is_dead:
		return

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

func _do_hit_reaction():
	is_stunned = true
	is_attacking = false
	is_screaming = false
	velocity = Vector3.ZERO
	
	_play_animation_safe(ANIM_HIT_REACTION)
	
	if anim.has_animation(ANIM_HIT_REACTION):
		var hit_anim_length = anim.get_animation(ANIM_HIT_REACTION).length
		await get_tree().create_timer(max(hit_anim_length, stun_duration)).timeout
	else:
		await get_tree().create_timer(stun_duration).timeout
	
	is_stunned = false

# --------------------------------------------------------------------------------
## ระบบตาย
# --------------------------------------------------------------------------------
func _die():
	is_dead = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	
	if loop_sfx:
		loop_sfx.stop()

	if anim.has_animation(ANIM_DEATH):
		_play_animation_safe(ANIM_DEATH)
		if is_instance_valid(anim):
			await anim.animation_finished
			
		var game_ui = get_tree().get_root().find_child("UI", true, false) # สมมติตามชื่อ
		# 2. เรียกฟังก์ชันเพิ่มสกอร์
		if game_ui:
			game_ui.add_kill_score(100) # เพิ่ม 1 คะแนน
	queue_free()

# --------------------------------------------------------------------------------
## AI และการเคลื่อนที่ (แก้เฉพาะส่วน player detection)
# --------------------------------------------------------------------------------
func _physics_process(delta):
	# ✅ อัปเดตรายชื่อผู้เล่นทุกเฟรม (เผื่อมี spawn/loss ระหว่างเกม)
	players = get_tree().get_nodes_in_group("player")

	if is_dead or is_stunned:
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
		if not is_instance_valid(p):
			continue
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
		# --- เล่นเสียงเดิน ---
		if footstep_sfx and not footstep_sfx.playing:
			footstep_sfx.play()

# --------------------------------------------------------------------------------
## ระบบโจมตี (เหมือนเดิม)
# --------------------------------------------------------------------------------
func _do_attack():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time < attack_cooldown:
		return

	last_attack_time = current_time

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
		if not is_instance_valid(p):
			continue
		var dist = global_transform.origin.distance_to(p.global_transform.origin)
		if dist <= ATTACK_RANGE:
			if p.has_method("take_damage"):
				p.take_damage(ATTACK_DAMAGE, "zombie_attack")

func _play_animation_safe(animation_name: String):
	if anim and anim.has_animation(animation_name):
		if anim.current_animation != animation_name:
			anim.play(animation_name)
