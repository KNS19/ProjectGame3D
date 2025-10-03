extends CharacterBody3D

# --- Constants ---
const SPEED = 5.0
const RUN_SPEED = 9.0
const JUMP_VELOCITY = 4.5
const FRICTION = 25
const HORIZONTAL_ACCELERATION = 30
const ROLL_SPEED = 12.0
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
var default_fov = 70.0
@export var aim_fov = 55.0

# --- Nodes ---
@onready var camera = $Camera3D
@onready var anim_player: AnimationPlayer = $CSGMesh3D/AnimationPlayer
@onready var stamina_bar: ProgressBar = get_node("/root/World/UI/StaminaBar")
@onready var pistol: Node = $"Skeleton3D/WeaponSlot/Pistol"

# --- Animations ---
@export var ANIM_IDLE = "CharacterArmature|Idle"
@export var ANIM_WALK = "CharacterArmature|Walk"
@export var ANIM_RUN  = "CharacterArmature|Run"
@export var ANIM_ROLL = "CharacterArmature|Roll"
@export var ANIM_HIT  = "CharacterArmature|HitRecieve"

@export var ANIM_IDLE_GUN   = "CharacterArmature|Idle_Gun"
@export var ANIM_AIM_GUN    = "CharacterArmature|Idle_Gun_Pointing"
@export var ANIM_SHOOT_GUN  = "CharacterArmature|Idle_Gun_Shoot"

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	if camera: default_fov = camera.fov
	if pistol: pistol.visible = false

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _unhandled_key_input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

	# Toggle ปืนด้วยเลข 1
	if Input.is_action_just_pressed("equip_1"):
		_toggle_gun()

func _physics_process(delta):
	var current_time = Time.get_ticks_msec() / 1000.0

	# --- Stamina Recovery ---
	if not Input.is_action_pressed("run") and not is_rolling and not is_attacking:
		stamina = min(max_stamina, stamina + stamina_recovery * delta)

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- Jump ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = JUMP_VELOCITY

	# --- Input Movement ---
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cur_speed = SPEED

	# Run
	if Input.is_action_pressed("run") and stamina > 0.0 and input_vec.length() > 0.1 and not is_attacking:
		cur_speed = RUN_SPEED
		stamina = max(0, stamina - run_cost * delta)

	# Roll
	if Input.is_action_just_pressed("roll") and not is_rolling and not is_attacking and stamina >= roll_cost and input_vec.length() > 0.1:
		is_rolling = true
		roll_timer = ROLL_DURATION
		stamina -= roll_cost
		anim_player.play(ANIM_ROLL)

	var direction = (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()

	if is_rolling:
		roll_timer -= delta
		velocity.x = direction.x * ROLL_SPEED
		velocity.z = direction.z * ROLL_SPEED
		if roll_timer <= 0.0:
			is_rolling = false
	else:
		velocity.x = move_toward(velocity.x, direction.x * cur_speed, HORIZONTAL_ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * cur_speed, HORIZONTAL_ACCELERATION * delta)

	# --- Attack (มือเปล่า) ---
	if not has_gun and Input.is_action_just_pressed("attack") and not is_rolling:
		if stamina >= attack_cost and (current_time - last_attack_time >= attack_cooldown):
			_do_attack(current_time)

	# --- Gun controls ---
	if has_gun:
		is_aiming = Input.is_action_pressed("aim")
		if camera:
			camera.fov = lerp(camera.fov, aim_fov if is_aiming else default_fov, 10.0 * delta)
		if Input.is_action_just_pressed("fire"):
			_shoot_gun()

	# --- Move ---
	move_and_slide()
	force_update_transform()

	# --- Animation logic ---
	_update_animation(input_vec)

	# --- UI ---
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

# --- Gun helpers ---
func _toggle_gun():
	has_gun = not has_gun
	if pistol: pistol.visible = has_gun
	if not has_gun and camera:
		camera.fov = default_fov

func _shoot_gun():
	if anim_player and anim_player.has_animation(ANIM_SHOOT_GUN):
		anim_player.play(ANIM_SHOOT_GUN)
		await get_tree().create_timer(0.3).timeout
		if is_aiming:
			anim_player.play(ANIM_AIM_GUN)
		else:
			anim_player.play(ANIM_IDLE_GUN)
	if pistol and pistol.has_method("try_fire"):
		pistol.try_fire()

func _update_animation(input_vec: Vector2):
	if is_attacking: return
	if is_rolling: return

	if not is_on_floor():
		anim_player.play(ANIM_HIT)
		return

	var moving = input_vec.length() > 0.1

	if has_gun:
		if is_aiming:
			anim_player.play(ANIM_AIM_GUN)
		elif moving:
			anim_player.play(ANIM_IDLE_GUN) # ถ้ามี Run_Shoot เปลี่ยนเป็นอันนั้นได้
		else:
			anim_player.play(ANIM_IDLE_GUN)
	else:
		if moving:
			if Input.is_action_pressed("run") and stamina > 0:
				anim_player.play(ANIM_RUN)
			else:
				anim_player.play(ANIM_WALK)
		else:
			anim_player.play(ANIM_IDLE)
