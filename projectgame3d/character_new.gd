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
var stamina_recovery = 15.0   # ฟื้นคืนต่อวินาที
var run_cost = 20.0           # ต่อวินาที
var roll_cost = 25.0          # ต่อครั้ง
var attack_cost = 5.0        # ต่อการโจมตี 1 ครั้ง

# --- Attack Combo ---
var attack_index = 0
var last_attack_time = 0.0
var attack_cooldown = 1.0     # ดีเลย์โจมตี 1 วิ
var combo_window = 2.0        # เวลากดต่อเนื่อง 2 วิ
var is_attacking = false

# --- State ---
var is_rolling = false
var roll_timer = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Nodes ---
@onready var camera = $Camera3D
@onready var anim_player: AnimationPlayer = $CSGMesh3D/AnimationPlayer
@onready var stamina_bar: ProgressBar = get_node("/root/World/UI/StaminaBar")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _unhandled_key_input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: 
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

	# --- Movement input ---
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cur_speed = SPEED

	# --- Run with stamina ---
	if Input.is_action_pressed("run") and stamina > 0.0 and input_vec.length() > 0.1 and not is_attacking:
		cur_speed = RUN_SPEED
		stamina = max(0, stamina - run_cost * delta)

	# --- Roll with stamina ---
	if Input.is_action_just_pressed("roll") and not is_rolling and not is_attacking and stamina >= roll_cost and input_vec.length() > 0.1:
		is_rolling = true
		roll_timer = ROLL_DURATION
		stamina -= roll_cost
		anim_player.play("CharacterArmature|Roll")

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

	# --- Attack logic ---
	if Input.is_action_just_pressed("attack") and not is_rolling:
		if stamina >= attack_cost and (current_time - last_attack_time >= attack_cooldown):
			_do_attack(current_time)

	# --- Move ---
	move_and_slide()
	force_update_transform()

	# --- Animation logic ---
	if is_attacking:
		# ระหว่างโจมตีจะไม่เปลี่ยน animation
		pass
	elif not is_on_floor():
		if anim_player.current_animation != "CharacterArmature|HitRecieve":
			anim_player.play("CharacterArmature|HitRecieve")
	elif input_vec.length() > 0.1 and not is_rolling:
		if Input.is_action_pressed("run") and stamina > 0:
			if anim_player.current_animation != "CharacterArmature|Run":
				anim_player.play("CharacterArmature|Run")
		else:
			if anim_player.current_animation != "CharacterArmature|Walk":
				anim_player.play("CharacterArmature|Walk")
	elif not is_rolling:
		if anim_player.current_animation != "CharacterArmature|Idle":
			anim_player.play("CharacterArmature|Idle")

	# --- Update UI ---
	stamina_bar.value = stamina

func _do_attack(current_time):
	is_attacking = true
	stamina -= attack_cost

	# reset combo ถ้าเลย 2 วิ
	if current_time - last_attack_time > combo_window:
		attack_index = 0

	# เลือกท่าโจมตีตาม index
	var attack_anims = [
		"CharacterArmature|Punch_Left",
		"CharacterArmature|Punch_Right",
		"CharacterArmature|Kick_Left",
		"CharacterArmature|Kick_Right"
	]

	anim_player.play(attack_anims[attack_index])

	# เตรียมท่าต่อไป
	attack_index = (attack_index + 1) % attack_anims.size()
	last_attack_time = current_time

	# ตั้ง Timer ปลดล็อคโจมตีหลัง cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false
