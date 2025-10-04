extends CharacterBody3D

# --- New Constants and Variables ---
const ATTACK_RANGE = 1.5
const ANIM_ATTACK = "Armature|Attack" 

@export var speed: float = 5.0
var players: Array = []
var is_screaming: bool = false
var is_attacking: bool = false

# --- Animations ---
const ANIM_WALK = "Armature|Walk2"
const ANIM_IDLE = "Armature|Idle"
const ANIM_SCREAM = "Armature|Scream" 

# --- Nodes ---
@onready var detection_area: Area3D = $DetectionArea
@onready var anim: AnimationPlayer = $AnimationPlayer 

func _ready():
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	if anim.has_animation(ANIM_IDLE):
		_play_animation_safe(ANIM_IDLE)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if not players.has(body):
			players.append(body)
			print("Zombie detected player:", body.name)
			
			if not is_screaming and not is_attacking and players.size() == 1 and anim.has_animation(ANIM_SCREAM):
				_do_scream()

func _on_body_exited(body):
	if players.has(body):
		players.erase(body)
		print("Player left detection:", body.name)

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
	
	# กำหนดเวลาจบ Animation โจมตี
	var attack_time = 1.0 # ค่าเริ่มต้น 1 วินาที
	if anim.has_animation(ANIM_ATTACK):
		attack_time = anim.get_animation(ANIM_ATTACK).length
		
	await get_tree().create_timer(attack_time).timeout
	
	is_attacking = false

func _physics_process(delta):
	# หยุดทุกอย่างถ้ากำลัง Scream หรือ Attack
	if is_screaming or is_attacking:
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
	# 1. ไม่มีผู้เล่น -> Idle
	if players.size() == 0:
		velocity = Vector3.ZERO
		move_and_slide()
		_play_animation_safe(ANIM_IDLE)
		return

	# 2. มีผู้เล่น -> ไล่/โจมตี
	var nearest = players[0]
	var nearest_dist = global_transform.origin.distance_to(nearest.global_transform.origin)

	for p in players:
		var d = global_transform.origin.distance_to(p.global_transform.origin)
		if d < nearest_dist:
			nearest = p
			nearest_dist = d
			
	# หมุนตัวซอมบี้ให้หันไปทางเป้าหมาย
	look_at(nearest.global_transform.origin, Vector3.UP, true)

	# ตรวจสอบระยะโจมตี
	if nearest_dist <= ATTACK_RANGE:
		# ถึงระยะโจมตีแล้ว: หยุดเดินและโจมตี
		velocity = Vector3.ZERO
		move_and_slide()

		if not is_attacking and anim.has_animation(ANIM_ATTACK):
			_do_attack()
			
	else:
		# ยังไม่ถึงระยะโจมตี: เดินไล่
		var dir = (nearest.global_transform.origin - global_transform.origin).normalized()
		velocity = dir * speed
		move_and_slide()

		# เล่น Animation เดิน
		_play_animation_safe(ANIM_WALK)

# ฟังก์ชันที่ป้องกันการบัคจากการเล่นซ้ำซ้อน
func _play_animation_safe(animation_name: String):
	if anim and anim.has_animation(animation_name):
		if anim.current_animation != animation_name:
			anim.play(animation_name)
