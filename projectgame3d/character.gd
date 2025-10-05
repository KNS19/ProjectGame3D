extends CharacterBody3D

# --- Constants ---
const SPEED = 4.0
const RUN_SPEED = 6.0
const JUMP_VELOCITY = 4.5
const FRICTION = 25
const HORIZONTAL_ACCELERATION = 30
const ROLL_SPEED = 7.0
const ROLL_DURATION = 1.333

# --- Stamina ---
var max_stamina = 150.0
var stamina = max_stamina
var stamina_recovery = 15.0
var run_cost = 20.0
var roll_cost = 25.0
var attack_cost = 5.0

# --- Attack Combo ---
var attack_index = 0
var last_attack_time = 0.0
var attack_cooldown = 1.0
var combo_window = 2.0
var is_attacking = false

# --- State ---
var is_rolling = false
var roll_timer = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Gun states ---
var has_gun = false
var is_aiming = false
var is_shooting = false
var default_fov = 70.0
@export var aim_fov = 55.0
@export var shoot_recover_time: float = 0.4

#--- Sword states ---
var has_sword = false
var is_swing = false
@export var lock_move_during_sword: bool = true
var move_locked: bool = false

# --- Nodes ---
@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $CSGMesh3D/AnimationPlayer
@onready var stamina_bar: ProgressBar = get_node("/root/World/UI/StaminaBar")
@onready var weapon_slot = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot
@onready var pistol = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot/Pistol
@onready var sword = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot/Katana

# --- Animations ---
@export var ANIM_IDLE = "CharacterArmature|Idle"
@export var ANIM_WALK = "CharacterArmature|Walk"
@export var ANIM_RUN  = "CharacterArmature|Run"
@export var ANIM_ROLL = "CharacterArmature|Roll"
@export var ANIM_HIT  = "CharacterArmature|HitRecieve"

@export var ANIM_IDLE_GUN   = "CharacterArmature|Idle_Gun"
@export var ANIM_AIM_GUN    = "CharacterArmature|Idle_Gun_Pointing"
@export var ANIM_SHOOT_GUN  = "CharacterArmature|Idle_Gun_Shoot"
@export var ANIM_RUN_SHOOT  = "CharacterArmature|Run_Shoot"
@export var ANIM_SHOOT_ALT  = "CharacterArmature|Gun_Shoot"

@export var ANIM_IDLE_SWORD  = "CharacterArmature|Idle_Sword"
@export var ANIM_SLASH_SWORD  = "CharacterArmature|Sword_Slash"

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina

	has_gun = false
	if camera: default_fov = camera.fov

	_hide_all_weapons_in_slot()
	# ซ่อนปืนไว้ก่อน
	if is_instance_valid(pistol):
		pistol.visible = false
	
	# ซ่อนดาบไว้ก่อน
	if is_instance_valid(sword):
		sword.visible = false


	if anim_player and anim_player.has_animation(ANIM_IDLE):
		anim_player.play(ANIM_IDLE)

# จับเมาส์กลับเสมอเมื่อคลิก
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _hide_all_weapons_in_slot() -> void:
	if is_instance_valid(weapon_slot):
		for c in weapon_slot.get_children():
			if c is Node3D:
				c.visible = false

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.005)
		if is_instance_valid(camera):
			camera.rotate_x(-event.relative.y * 0.005)
			camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _unhandled_key_input(_event):
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
	
	# Toggle ดาบด้วยเลข 1
	if Input.is_action_just_pressed("equip_1"):
		_toggle_sword()
		anim_player.play("CharacterArmature|Idle_Sword")

	# Toggle ปืนด้วยเลข 2
	if Input.is_action_just_pressed("equip_2"):
		_toggle_gun()
		anim_player.play("CharacterArmature|Idle_Gun")

func _physics_process(_delta):
	var current_time = Time.get_ticks_msec() / 1000.0

	# Stamina
	if not Input.is_action_pressed("run") and not is_rolling and not is_attacking:
		stamina = min(max_stamina, stamina + stamina_recovery * _delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * _delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = JUMP_VELOCITY

	# Movement
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cur_speed = SPEED
	# 🔒 ถ้าล็อกการเดิน (ช่วงฟันดาบ) บังคับหยุดเคลื่อนที่
	if move_locked:
		input_vec = Vector2.ZERO
		cur_speed = 0.0
		
	# Run
	if Input.is_action_pressed("run") and stamina > 0.0 and input_vec.length() > 0.1 and not is_attacking:
		cur_speed = RUN_SPEED
		stamina = max(0, stamina - run_cost * _delta)

	# Roll
	if Input.is_action_just_pressed("roll") and not is_rolling and not is_attacking and stamina >= roll_cost and input_vec.length() > 0.1:
		is_rolling = true
		roll_timer = ROLL_DURATION
		stamina -= roll_cost
		anim_player.play(ANIM_ROLL)

	var direction = (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()

	if is_rolling:
		roll_timer -= _delta
		velocity.x = direction.x * ROLL_SPEED
		velocity.z = direction.z * ROLL_SPEED
		if roll_timer <= 0.0:
			is_rolling = false
	else:
		velocity.x = move_toward(velocity.x, direction.x * cur_speed, HORIZONTAL_ACCELERATION * _delta)
		velocity.z = move_toward(velocity.z, direction.z * cur_speed, HORIZONTAL_ACCELERATION * _delta)

	# Sword controls
	if has_sword and not has_gun:
		if Input.is_action_just_pressed("fire") and not is_attacking and not is_rolling:
			if stamina >= attack_cost:
				print("[DEBUG] sword slash")
				stamina -= attack_cost
				is_attacking = true
				_slash_sword()  # เล่นแอนิเมชันดาบ
				if is_instance_valid(sword) and sword.has_method("swing"):
					sword.swing()  # เปิด hitbox ฟันจริง
				await get_tree().create_timer(attack_cooldown).timeout
				is_attacking = false
				
	## Sword controls
	#if has_sword and not has_gun:
		#if Input.is_action_just_pressed("fire") and not is_attacking and not is_rolling:
			#if stamina >= attack_cost:
				#stamina -= attack_cost
				#is_attacking = true
				#await _slash_sword()   # <- ให้ _slash_sword() เป็น async (ตามด้านบน)
				#is_attacking = false

	# Gun controls
	elif has_gun:
		is_aiming = Input.is_action_pressed("aim")
		if camera:
			camera.fov = lerp(camera.fov, aim_fov if is_aiming else default_fov, 10.0 * _delta)
		if Input.is_action_just_pressed("fire") and not is_attacking and not is_rolling:
			print("[DEBUG] fire pressed")
			_shoot_gun()
			
	# Attack (มือเปล่า)
	#if not has_gun and Input.is_action_just_pressed("attack") and not is_rolling:
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling:
		if stamina >= attack_cost and (current_time - last_attack_time >= attack_cooldown):
			print("[DEBUG] punch attack")
			_do_attack(current_time)
			
	move_and_slide()
	force_update_transform()
	_update_animation(input_vec)
	stamina_bar.value = stamina

func _do_attack(current_time):
	is_attacking = true
	stamina -= attack_cost

	if current_time - last_attack_time > combo_window:
		attack_index = 0

	var attack_anims = [
		"CharacterArmature|Punch_Left",
		"CharacterArmature|Punch_Right",
		"CharacterArmature|Kick_Left",
		"CharacterArmature|Kick_Right"
	]
	anim_player.play(attack_anims[attack_index])
	attack_index = (attack_index + 1) % attack_anims.size()
	last_attack_time = current_time
	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false

# ------ Helper (ย้ายออกมานอกฟังก์ชัน) ------
func _play_shoot_stand() -> void:
	if not anim_player:
		return
	if anim_player.has_animation(ANIM_SHOOT_GUN):
		anim_player.play(ANIM_SHOOT_GUN)
	elif anim_player.has_animation(ANIM_SHOOT_ALT):
		anim_player.play(ANIM_SHOOT_ALT)
	else:
		push_warning("No shoot animation found (Idle_Gun_Shoot / Gun_Shoot)")

# --- Sword helpers ---
func _toggle_sword():
	has_sword = not has_sword
	if has_sword:
		has_gun = false # ปิดปืนเมื่อถือดาบ
	# ซ่อนอาวุธทุกชิ้นใน WeaponSlot ก่อน
	_hide_all_weapons_in_slot()
	# ถ้า toggle เป็น true → โชว์ pistol
	if has_sword and is_instance_valid(sword):
		sword.visible = true

# --- Gun helpers ---
func _toggle_gun():
	has_gun = not has_gun
	if has_gun:
		has_sword = false   # ปิดดาบเมื่อถือปืน
	# ซ่อนอาวุธทุกชิ้นใน WeaponSlot ก่อน
	_hide_all_weapons_in_slot()
	# ถ้า toggle เป็น true → โชว์ pistol
	if has_gun and is_instance_valid(pistol):
		pistol.visible = true
	else:
		# toggle เป็น false → reset fov กลับมา
		if camera:
			camera.fov = default_fov

func _slash_sword():
	if not has_sword or is_swing:
		return
	is_swing = true

	if anim_player and anim_player.has_animation(ANIM_SLASH_SWORD):
		anim_player.play(ANIM_SLASH_SWORD)
	if sword and sword.has_method("swing"):
		sword.swing()

	# 🔒 ล็อกการเคลื่อนที่ระหว่างฟัน
	if lock_move_during_sword:
		move_locked = true

	# ✅ ใช้ความยาวแอนิเมชันจริงแทนคูลดาวน์ตายตัว
	var dur = anim_player.current_animation_length if anim_player else attack_cooldown
	await get_tree().create_timer(dur).timeout

	move_locked = false
	is_swing = false

func _shoot_gun():
	if not has_gun:
		push_warning("Shoot ignored: has_gun = false (กด 2 เพื่อ equip ก่อน)")
		return
	if is_shooting:
		return
	is_shooting = true

	var moving_before := Input.get_vector("move_left","move_right","move_forward","move_backward").length() > 0.1
	var running_before = Input.is_action_pressed("run") and stamina > 0

	# ยิง (เลือกอนิเมชันตามสถานะขณะเริ่มยิง)
	if not is_aiming and moving_before and anim_player and anim_player.has_animation(ANIM_RUN_SHOOT):
		# วิ่ง/เดินอยู่ (ไม่กดเล็ง) → ใช้ Run_Shoot
		anim_player.play(ANIM_RUN_SHOOT)
	else:
		# ยืน หรือกำลังเล็งอยู่ → ใช้อนิเมชันยิงท่ายืน
		_play_shoot_stand()

	# ยิงกระสุนจริง
	if is_instance_valid(pistol) and pistol.has_method("try_fire"):
		pistol.try_fire()

	# รอความยาวคลิปยิง/ดีเลย์สั้น ๆ
	await get_tree().create_timer(shoot_recover_time).timeout

	# หลังยิง: ไม่ว่าเล็งหรือไม่ ให้กลับไป movement ปกติทันที (ไม่เล่น Pointing)
	var vec := Input.get_vector("move_left","move_right","move_forward","move_backward")
	var moving_now := vec.length() > 0.1
	var running_now = Input.is_action_pressed("run") and stamina > 0

	if moving_now:
		anim_player.play(ANIM_RUN if running_now else ANIM_WALK)
	else:
		anim_player.play(ANIM_IDLE)

	is_shooting = false

func _update_animation(input_vec: Vector2):
	if is_attacking or is_rolling or is_shooting:
		return
	if not is_on_floor():
		anim_player.play(ANIM_HIT)
		return

	var moving := input_vec.length() > 0.1
	var running = Input.is_action_pressed("run") and stamina > 0

	# --- ถ้าถือดาบอยู่ ---
	if has_sword:
		if moving:
			anim_player.play(ANIM_RUN if running else ANIM_WALK)
		else:
			# ยืนนิ่ง → เล่นแอนิเมชันถือดาบเฉย ๆ
			if anim_player.has_animation(ANIM_IDLE_SWORD):
				anim_player.play(ANIM_IDLE_SWORD)
			else:
				anim_player.play(ANIM_IDLE)
		return

	# --- ถ้ามีปืนอยู่ ---
	if has_gun:
		if moving:
			anim_player.play(ANIM_RUN if running else ANIM_WALK)
		else:
			if anim_player.has_animation(ANIM_IDLE_GUN):
				anim_player.play(ANIM_IDLE_GUN)
			else:
				anim_player.play(ANIM_IDLE)
		return
		
	else:
		# --- มือเปล่า ---
		if moving:
			anim_player.play(ANIM_RUN if running else ANIM_WALK)
		else:
			anim_player.play(ANIM_IDLE)
