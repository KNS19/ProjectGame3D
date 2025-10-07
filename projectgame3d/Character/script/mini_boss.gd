extends CharacterBody3D

# --- Animation Constants ---
const ANIM_DUBLE_ATTACK = "CharacterArmature|Idle_Attack"
const ANIM_ATTACK = "CharacterArmature|Punch"
const ANIM_HIT_REACTION = "CharacterArmature|HitReact"
const ANIM_WALK = "CharacterArmature|Walk"
const ANIM_IDLE = "CharacterArmature|Idle"
const ANIM_SCREAM = "CharacterArmature|No"
const ANIM_DEATH = "CharacterArmature|Death"
const ANIM_RUN = "CharacterArmature|Run_Arms"

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var movement_speed_phase1: float = 2.0
@export var movement_speed_phase2: float = 5.0

# --- Nodes ---
@onready var detection_area: Area3D = $DetectionArea
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var attack_Left_area: Area3D = $"RootNode/CharacterArmature/Skeleton3D/Hand_Left/Left_Area"
@onready var attack_Right_area: Area3D = $"RootNode/CharacterArmature/Skeleton3D/Hand_Right/Right_Area"
# 🔴 NOTE: ไม่ใช้ BodyArea ในการรับดาเมจอีกแล้ว แต่ยังคงไว้ถ้าจำเป็นสำหรับโมเดล
@onready var body_area: Area3D = $"RootNode/CharacterArmature/Skeleton3D/BoneAttachment3D_Body/BodyArea"

# --- Boss State Machine ---
enum State {
	IDLE,
	CHASE,
	ATTACK,
	HIT_STUN,
	PHASE_TRANSITION,
	DEAD
}
var current_state: State = State.IDLE

# --- Boss Stats & Logic ---
var max_health_phase1: float = 300.0
var max_health_phase2: float = 100.0
var health: float = max_health_phase1
var current_phase: int = 1

# Phase 1 Stats
var attack_damage_phase1: int = 30
var attack_cooldown_phase1: float = 2.0
# Phase 2 Stats
var attack_damage_phase2: int = 40
var attack_cooldown_phase2: float = 3.0

# State Timers
var attack_timer: float = 0.0
var stun_timer: float = 0.0
const STUN_DURATION: float = 2.0

var player_target: CharacterBody3D = null # เก็บ reference ของผู้เล่น

# ==============================================================================
# INITIALIZATION AND SETUP
# ==============================================================================

func _ready():
	# 1. เชื่อมต่อสัญญาณของ DetectionArea (ใช้ตรวจจับ Player)
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# 🔴 ลบ: ไม่เชื่อมต่อ body_area.area_entered สำหรับรับดาเมจแล้ว
	# 🔴 ลบ: ไม่ต้องตั้งค่า body_area.monitorable อีกแล้ว
	
	# 2. เตรียมพื้นที่โจมตีและสัญญาณ (Boss Attack)
	attack_Left_area.monitoring = false
	attack_Right_area.monitoring = false
	
	attack_Left_area.body_entered.connect(_on_left_area_body_entered)
	attack_Right_area.body_entered.connect(_on_right_area_body_entered)
	
	# 3. เชื่อมต่อสัญญาณ animation finished
	anim.animation_finished.connect(_on_animation_finished)
	
	# 4. ตั้งค่าเริ่มต้น
	set_state(State.IDLE)
	add_to_group("mons")


# ==============================================================================
# PHYSICS PROCESS (MOVEMENT AND CORE LOGIC)
# ==============================================================================

func _physics_process(delta: float):
	if health <= 0 and current_state != State.DEAD:
		set_state(State.DEAD)
	
	if current_state != State.DEAD:
		# ใช้ Gravity เสมอ
		if not is_on_floor():
			velocity.y -= gravity * delta

	# State Machine Logic
	match current_state:
		State.IDLE:
			do_idle(delta)
		State.CHASE:
			do_chase(delta)
		State.ATTACK:
			do_attack(delta)
		State.HIT_STUN:
			do_hit_stun(delta)
		State.PHASE_TRANSITION:
			do_phase_transition(delta)
	
	move_and_slide()
	
	# อัปเดต Timer
	if attack_timer > 0:
		attack_timer -= delta
	
# ==============================================================================
# STATE FUNCTIONS
# ==============================================================================

func do_idle(delta: float):
	anim.play(ANIM_IDLE)
	velocity = Vector3.ZERO
	if player_target:
		set_state(State.CHASE)

func do_chase(delta: float):
	if !player_target:
		set_state(State.IDLE)
		return

	var direction: Vector3 = (player_target.global_position - global_position).normalized()
	direction.y = 0
	look_at(player_target.global_position, Vector3.UP, true)
	
	var current_speed: float = movement_speed_phase1 if current_phase == 1 else movement_speed_phase2
	var current_walk_anim: String = ANIM_WALK if current_phase == 1 else ANIM_RUN

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	
	anim.play(current_walk_anim)

	if global_position.distance_to(player_target.global_position) < 1.5 and attack_timer <= 0:
		set_state(State.ATTACK)

func do_attack(delta: float):
	velocity = Vector3.ZERO
	
	var current_attack_anim: String
	var current_attack_cooldown: float
	
	if current_phase == 1:
		current_attack_anim = ANIM_ATTACK
		current_attack_cooldown = attack_cooldown_phase1
		attack_Right_area.monitoring = true
		attack_Left_area.monitoring = false
	else: # Phase 2
		current_attack_anim = ANIM_DUBLE_ATTACK
		current_attack_cooldown = attack_cooldown_phase2
		attack_Right_area.monitoring = false
		attack_Left_area.monitoring = true

	anim.play(current_attack_anim)
	attack_timer = current_attack_cooldown

func do_hit_stun(delta: float):
	anim.play(ANIM_HIT_REACTION)
	velocity = Vector3.ZERO
	stun_timer -= delta
	
	if stun_timer <= 0:
		set_state(State.CHASE if player_target else State.IDLE)

func do_phase_transition(delta: float):
	velocity = Vector3.ZERO
	anim.play(ANIM_IDLE)
	
func do_dead(delta: float):
	anim.play(ANIM_DEATH)
	velocity = Vector3.ZERO
	# ✅ แก้ไขชื่อฟังก์ชันสำหรับ Godot 4
	set_physics_process(false)
	
# ==============================================================================
# STATE CHANGE FUNCTION
# ==============================================================================

func set_state(new_state: State):
	current_state = new_state
	#print("Boss State: ", State.keys()[current_state])

# ==============================================================================
# 🟢 PUBLIC METHOD: รับดาเมจโดยตรงจาก Player
# ==============================================================================

func take_damage(damage_amount: float, source: Variant = null):
	if health <= 0 or current_state == State.DEAD:
		return

	health -= damage_amount
	print("💥 BOSS HIT (Direct)! Damage: ", damage_amount, " | New HP: ", health)

	# ถ้าบอสยังไม่ตาย ให้เข้าสู่สถานะชะงัก
	if health > 0:
		set_state(State.HIT_STUN)
		stun_timer = STUN_DURATION
		
		# ตรวจสอบการเปลี่ยนเฟส
		if current_phase == 1 and health <= max_health_phase2:
			set_state(State.PHASE_TRANSITION)
			
	elif health <= 0:
		set_state(State.DEAD)

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================

# --- Detection Area (ตรวจจับผู้เล่น) ---
func _on_detection_area_body_entered(body: Node3D):
	# ตรวจสอบผู้เล่นเพื่อเริ่ม CHASE
	if body.is_in_group("player"):
		player_target = body as CharacterBody3D
		if current_state == State.IDLE:
			set_state(State.CHASE)

func _on_detection_area_body_exited(body: Node3D):
	if body == player_target:
		player_target = null
		if current_state == State.CHASE:
			set_state(State.IDLE)

# 🔴 ลบฟังก์ชัน _on_body_area_area_entered เดิมออก

# --- Attack Areas (ปล่อยดาเมจใส่ผู้เล่น) ---

func _on_left_area_body_entered(body: Node3D):
	if body.is_in_group("player"):
		if attack_Left_area.monitoring == true:
			if anim.current_animation == ANIM_DUBLE_ATTACK and current_phase == 2:
				deal_damage(body, attack_damage_phase2)

func _on_right_area_body_entered(body: Node3D):
	if body.is_in_group("player"):
		if attack_Right_area.monitoring == true:
			if anim.current_animation == ANIM_ATTACK and current_phase == 1:
				deal_damage(body, attack_damage_phase1)

# --- Animation Player (ควบคุมการเปลี่ยนสถานะหลังโจมตี/เปลี่ยนเฟส) ---
func _on_animation_finished(anim_name: StringName):
	if current_state == State.ATTACK:
		# ปิด Area โจมตีหลังจากแอนิเมชันจบ
		attack_Right_area.monitoring = false
		attack_Left_area.monitoring = false
		
		set_state(State.CHASE if player_target else State.IDLE)
		
	elif current_state == State.PHASE_TRANSITION and anim_name == ANIM_IDLE:
		# Logic การเปลี่ยนเฟส 1 -> 2
		current_phase = 2
		health = max_health_phase2
		
		anim.play(ANIM_IDLE)
		await anim.animation_finished
		set_state(State.CHASE if player_target else State.IDLE)


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# ฟังก์ชันสำหรับส่งดาเมจไปยังเป้าหมาย (ใช้สำหรับโจมตี Player)
func deal_damage(target: Node3D, amount: int):
	if target.has_method("take_damage"):
		target.take_damage(float(amount), self)
