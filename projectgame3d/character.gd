extends CharacterBody3D

# ——— Tunables ———
const SPEED := 5.0
const ACCEL := 12.0         # เร่งตอนเริ่มวิ่ง
const DEACCEL := 14.0       # หน่วงตอนปล่อยปุ่ม
const JUMP_VELOCITY := 6.0
const AIR_CONTROL := 0.3    # ควบคุมทิศทางกลางอากาศ
const MOUSE_SENS_X := 0.12  # ความไวเมาส์แกน X (องศา/พิกเซล)
const MOUSE_SENS_Y := 0.12  # ความไวเมาส์แกน Y (องศา/พิกเซล)
const PITCH_MIN := deg_to_rad(-85)
const PITCH_MAX := deg_to_rad(85)

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# หมุนมุมมองด้วยเมาส์เมื่อถูกจับ
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# หมุนตัว (yaw) ด้วยแกน X ของเมาส์
		rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENS_X))
		# หมุนกล้อง (pitch) ด้วยแกน Y ของเมาส์ แล้วจำกัดมุม
		camera.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENS_Y))
		camera.rotation.x = clamp(camera.rotation.x, PITCH_MIN, PITCH_MAX)

	# คลิกซ้ายเมื่อเมาส์ว่างจะจับเมาส์กลับ
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_key_input(_event: InputEvent) -> void:
	# กด ESC สลับโหมดเมาส์
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

func _physics_process(delta: float) -> void:
	# แรงโน้มถ่วง
	if not is_on_floor():
		velocity.y -= gravity * delta

	# กระโดด
	if Input.is_action_just_pressed("ui_accept") \
		and is_on_floor() \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = JUMP_VELOCITY

	# ทิศทางอินพุต (WASD) — ชี้ตามทิศของตัวละคร (ที่หมุนด้วย yaw)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wishdir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# เร่ง/หน่วงความเร็วให้ลื่นขึ้น และลดการคุมกลางอากาศ
	var target_speed := SPEED
	var accel := ACCEL if is_on_floor() else ACCEL * AIR_CONTROL
	var deaccel := DEACCEL if is_on_floor() else DEACCEL * AIR_CONTROL

	if wishdir != Vector3.ZERO and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# เคลื่อนที่เข้าหาเป้าความเร็วในทิศ wishdir
		var desired := wishdir * target_speed
		velocity.x = move_toward(velocity.x, desired.x, accel * delta)
		velocity.z = move_toward(velocity.z, desired.z, accel * delta)
	else:
		# หน่วงให้หยุด
		velocity.x = move_toward(velocity.x, 0.0, deaccel * delta)
		velocity.z = move_toward(velocity.z, 0.0, deaccel * delta)

	move_and_slide()
