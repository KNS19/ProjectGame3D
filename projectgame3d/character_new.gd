extends CharacterBody3D

const SPEED = 5.0
const RUN_SPEED = 9.0
const JUMP_VELOCITY = 4.5
const FRICTION = 25
const HORIZONTAL_ACCELERATION = 30
const MAX_SPEED = 5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var anim_player: AnimationPlayer = $CSGMesh3D/AnimationPlayer

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- Jump ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = JUMP_VELOCITY

	# --- Movement input ---
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	var cur_speed = SPEED
	if Input.is_action_pressed("run"):
		cur_speed = RUN_SPEED

	var direction = (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized() * cur_speed

	velocity.x = move_toward(velocity.x, direction.x, HORIZONTAL_ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z, HORIZONTAL_ACCELERATION * delta)

	# --- Move ---
	move_and_slide()
	force_update_transform()

	# --- Animation logic ---
	if not is_on_floor():
		if anim_player.current_animation != "CharacterArmature|HitRecieve":
			anim_player.play("CharacterArmature|HitRecieve")
	elif input_vec.length() > 0.1:
		if Input.is_action_pressed("run"):
			if anim_player.current_animation != "CharacterArmature|Run":
				anim_player.play("CharacterArmature|Run")
		else:
			if anim_player.current_animation != "CharacterArmature|Walk":
				anim_player.play("CharacterArmature|Walk")
	else:
		if anim_player.current_animation != "CharacterArmature|Idle":
			anim_player.play("CharacterArmature|Idle")
