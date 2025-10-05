extends CharacterBody3D

# --- Constants ---
const SPEED = 4.0
const RUN_SPEED = 6.0
const JUMP_VELOCITY = 4.5
const FRICTION = 25
const HORIZONTAL_ACCELERATION = 30
const ROLL_SPEED = 7.0
const ROLL_DURATION = 1.333
const INVULNERABILITY_DURATION = 0.5 # ระยะเวลาอมตะหลังโดนโจมตี

# --- Health ---
var max_health: float = 100.0
var health: float = max_health
var is_dead: bool = false
var is_invulnerable: bool = false

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
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

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
@onready var health_bar: ProgressBar = get_node("/root/World/UI/HealthBar")
@onready var weapon_slot = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot
@onready var pistol = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot/Pistol
@onready var sword = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot/Katana

# --- Animations ---
@export var ANIM_IDLE = "CharacterArmature|Idle"
@export var ANIM_WALK = "CharacterArmature|Walk"
@export var ANIM_RUN = "CharacterArmature|Run"
@export var ANIM_ROLL = "CharacterArmature|Roll"
@export var ANIM_HIT = "CharacterArmature|HitRecieve"
@export var ANIM_DEATH = "CharacterArmature|Death" # <<< เพิ่มแอนิเมชันตาย

@export var ANIM_IDLE_GUN = "CharacterArmature|Idle_Gun"
@export var ANIM_AIM_GUN = "CharacterArmature|Idle_Gun_Pointing"
@export var ANIM_SHOOT_GUN = "CharacterArmature|Idle_Gun_Shoot"
@export var ANIM_RUN_SHOOT = "CharacterArmature|Run_Shoot"
@export var ANIM_SHOOT_ALT = "CharacterArmature|Gun_Shoot"

@export var ANIM_IDLE_SWORD = "CharacterArmature|Idle_Sword"
@export var ANIM_SLASH_SWORD = "CharacterArmature|Sword_Slash"

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina

	# ตั้งค่า Health Bar
	if is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = health

	has_gun = false
	if camera:
		default_fov = camera.fov

	_hide_all_weapons_in_slot()
	if is_instance_valid(pistol): pistol.visible = false
	if is_instance_valid(sword): sword.visible = false

	if anim_player and anim_player.has_animation(ANIM_IDLE):
		anim_player.play(ANIM_IDLE)

# -----------------------------------------------
# INPUT & MOVEMENT
# -----------------------------------------------
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
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

	if Input.is_action_just_pressed("equip_1"):
		_toggle_sword()
		anim_player.play(ANIM_IDLE_SWORD) # ใช้ ANIM_IDLE_SWORD แทน hardcode

	if Input.is_action_just_pressed("equip_2"):
		_toggle_gun()
		anim_player.play(ANIM_IDLE_GUN) # ใช้ ANIM_IDLE_GUN แทน hardcode

func _do_attack(current_time: float) -> void:
	is_attacking = true
	stamina -= attack_cost

	# ถ้าช่วงห่างจากการต่อยครั้งก่อนเกิน combo_window → รีเซ็ตคอมโบ
	if current_time - last_attack_time > combo_window:
		attack_index = 0

	# เลือกอนิเมชันคอมโบ (หมัดซ้าย → หมัดขวา → เตะซ้าย → เตะขวา)
	var attack_anims = [
		"CharacterArmature|Punch_Left",
		"CharacterArmature|Punch_Right",
		"CharacterArmature|Kick_Left",
		"CharacterArmature|Kick_Right"
	]

	if anim_player and attack_index < attack_anims.size() and anim_player.has_animation(attack_anims[attack_index]):
		anim_player.play(attack_anims[attack_index])

	# หมุนคอมโบไปเรื่อย ๆ
	attack_index = (attack_index + 1) % attack_anims.size()
	last_attack_time = current_time

	# รอ cooldown ก่อนจะต่อยได้อีก
	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false

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
				_slash_sword()
				if is_instance_valid(sword) and sword.has_method("swing"):
					sword.swing()
				await get_tree().create_timer(attack_cooldown).timeout
				is_attacking = false

	# Gun controls
	if has_gun and not has_sword:
		is_aiming = Input.is_action_pressed("aim")
		if camera:
			camera.fov = lerp(camera.fov, aim_fov if is_aiming else default_fov, 10.0 * _delta)
		if Input.is_action_just_pressed("fire") and not is_attacking and not is_rolling:
			print("[DEBUG] fire pressed")
			_shoot_gun()

	# ✅ Punch controls (ต่อยได้ทุกกรณี)
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling:
		if stamina >= attack_cost and (current_time - last_attack_time >= attack_cooldown):
			print("[DEBUG] punch attack")
			_do_attack(current_time)


			
	move_and_slide()
	force_update_transform()
	_update_animation(input_vec)
	stamina_bar.value = stamina
# -----------------------------------------------
# HEALTH SYSTEM
# -----------------------------------------------
func take_damage(amount: float) -> void:
	if is_dead or is_invulnerable:
		return

	health -= amount
	health = max(0, health)
	if is_instance_valid(health_bar):
		health_bar.value = health

	print("Took damage: ", amount, " | HP:", health)

	if health <= 0:
		_die() # <<< เรียกฟังก์ชัน _die() เมื่อเลือดหมด
	else:
		_start_invulnerability()
		if anim_player and anim_player.has_animation(ANIM_HIT):
			anim_player.play(ANIM_HIT)

func heal(amount: float) -> void:
	if is_dead: return
	health = min(max_health, health + amount)
	if is_instance_valid(health_bar): health_bar.value = health

func _start_invulnerability() -> void:
	is_invulnerable = true
	await get_tree().create_timer(INVULNERABILITY_DURATION).timeout
	is_invulnerable = false

func _die() -> void:
	if is_dead: return # ป้องกันการเรียกซ้ำ
	is_dead = true
	print("Character is dead!")
	
	# หยุดการทำงานทางฟิสิกส์และการรับอินพุต
	set_physics_process(false)
	set_process(false)
	
	# เล่นแอนิเมชันตาย
	if anim_player and anim_player.has_animation(ANIM_DEATH):
		anim_player.play(ANIM_DEATH)
	
	# ให้ตัวละครล้มลงไปเลย (ถ้าต้องการ)
	velocity = Vector3.ZERO 
	
	# ลบ Collision Shape/Body ออกหลังแอนิเมชันจบ (ทางเลือก)
	# if anim_player and anim_player.has_animation(ANIM_DEATH):
	# 	await anim_player.animation_finished
	# 	# โค้ดสำหรับจัดการลบ/เปลี่ยนสถานะหลังตาย

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("mons"):
		var dmg = 10.0
		if body.has_method("get_attack_damage"):
			dmg = body.get_attack_damage()
		elif body.has_meta("damage"):
			dmg = body.get_meta("damage")
		take_damage(dmg)

# -----------------------------------------------
# WEAPON HELPERS
# -----------------------------------------------
func _toggle_sword():
	has_sword = not has_sword
	if has_sword:
		has_gun = false   # ปิดปืนเมื่อถือดาบ
	_hide_all_weapons_in_slot()
	if has_sword and is_instance_valid(sword):
		sword.visible = true

func _toggle_gun():
	has_gun = not has_gun
	if has_gun:
		has_sword = false   # ปิดดาบเมื่อถือปืน
	_hide_all_weapons_in_slot()
	if has_gun and is_instance_valid(pistol):
		pistol.visible = true
	else:
		if camera:
			camera.fov = default_fov

func _slash_sword():
	if not has_sword or is_swing: return
	is_swing = true
	if anim_player and anim_player.has_animation(ANIM_SLASH_SWORD):
		anim_player.play(ANIM_SLASH_SWORD)
	if sword and sword.has_method("swing"):
		sword.swing()
	if lock_move_during_sword:
		move_locked = true
	
	# ใช้ current_animation_length จากแอนิเมชันที่กำลังเล่นอยู่
	var dur = anim_player.current_animation_length if anim_player and anim_player.current_animation == ANIM_SLASH_SWORD else attack_cooldown
	
	await get_tree().create_timer(dur).timeout
	move_locked = false
	is_swing = false
	is_attacking = false # <<< รีเซ็ตสถานะโจมตีที่นี่

func _shoot_gun():
	if not has_gun: 
		return
	if is_shooting: 
		return

	is_shooting = true

	# ตรวจว่ากำลังเคลื่อนที่หรือไม่
	var moving_now := Input.get_vector("move_left","move_right","move_forward","move_backward").length() > 0.1

	# 🔸 เลือกแอนิเมชันยิงตามสถานะการเคลื่อนที่
	if anim_player:
		if moving_now and anim_player.has_animation(ANIM_RUN_SHOOT):
			anim_player.play(ANIM_RUN_SHOOT)  # เดิน/วิ่งอยู่
		elif anim_player.has_animation(ANIM_SHOOT_GUN):
			anim_player.play(ANIM_SHOOT_GUN)  # ยืนนิ่งยิง
		elif anim_player.has_animation(ANIM_SHOOT_ALT):
			anim_player.play(ANIM_SHOOT_ALT)  # fallback

	# 🔫 ยิงกระสุนจริง
	if pistol and pistol.has_method("try_fire"):
		pistol.try_fire()

	# รอเวลาคืน cooldown
	await get_tree().create_timer(shoot_recover_time).timeout

	# 🔄 หลังยิง: กลับไปอนิเมชัน idle / เดิน / วิ่ง
	var move_vec := Input.get_vector("move_left","move_right","move_forward","move_backward")
	var moving_after := move_vec.length() > 0.1
	var running_after = Input.is_action_pressed("run") and stamina > 0

	if anim_player:
		if moving_after:
			anim_player.play(ANIM_RUN if running_after else ANIM_WALK)
		else:
			anim_player.play(ANIM_IDLE_GUN)

	is_shooting = false


func _update_animation(input_vec: Vector2):
	if is_attacking or is_rolling or is_shooting or not is_on_floor():
		return
		
	var moving = input_vec.length() > 0.1
	var running = Input.is_action_pressed("run") and stamina > 0

	if has_sword:
		anim_player.play(ANIM_RUN if running else (ANIM_WALK if moving else ANIM_IDLE_SWORD))
	elif has_gun:
		if is_aiming:
			anim_player.play(ANIM_AIM_GUN)
		else:
			anim_player.play(ANIM_RUN if running else (ANIM_WALK if moving else ANIM_IDLE_GUN))
	else:
		anim_player.play(ANIM_RUN if running else (ANIM_WALK if moving else ANIM_IDLE))

# -----------------------------------------------
# MELEE ATTACK (ต่อย / เตะ)
# -----------------------------------------------
