#character.gd
extends CharacterBody3D

# --- Constants ---
const BASE_SPEED = 4.0
const BASE_RUN_SPEED = 6.0
const JUMP_VELOCITY = 4.5
const FRICTION = 25
const HORIZONTAL_ACCELERATION = 30
const ROLL_SPEED = 7.0
const ROLL_DURATION = 1.333
const INVULNERABILITY_DURATION = 0.5 # ระยะเวลาอมตะหลังโดนโจมตี

# --- Dynamic Speed (ค่าที่เปลี่ยนได้) ---
var SPEED = BASE_SPEED
var RUN_SPEED = BASE_RUN_SPEED

# --- Health ---
var max_health: float = 100.0
var health: float = max_health
var is_dead: bool = false
var is_invulnerable: bool = false
var heal_amount: float = 20.0        # ฟื้นเลือดครั้งละ
var heal_cooldown: float = 3.0       # ดีเลย์ระหว่างใช้ยา (วินาที)
var last_heal_time: float = 0.0      # เวลาใช้ยาครั้งล่าสุด

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

var is_stunned: bool = false
var stun_duration: float = 0.6

# --- State ---
var is_rolling = false
var roll_timer = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Gun states ---
var has_gun = false
var is_aiming = false  
var is_shooting = false
var default_fov = 70.0
var is_reloading_gun: bool = false
@export var aim_fov = 55.0
@export var shoot_recover_time: float = 0.4

#--- Sword states ---
var has_sword = false
var is_swing = false
@export var lock_move_during_sword: bool = true
var move_locked: bool = false

#--- Heal states ---
var has_medic = false
var is_healing: bool = false

# --- Nodes ---
@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $CSGMesh3D/AnimationPlayer
@onready var stamina_bar: ProgressBar = get_node("/root/World/UI/StaminaBar")
@onready var health_bar: ProgressBar = get_node("/root/World/UI/HealthBar")
@onready var weapon_ui: Node = get_node_or_null("/root/World/UI/WeaponSlots")
@onready var weapon_slot = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot
@onready var pistol = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot/Pistol
@onready var sword = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot/Katana
@onready var punch_L = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/BoneAttachment3D_Hand_L/Hand_L_Area
@onready var punch_R = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/BoneAttachment3D_Hand_R/Hand_R_Area
@onready var kick_L = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/BoneAttachment3D_Leg_L/Leg_L_Area
@onready var kick_R = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/BoneAttachment3D_Leg_R/Leg_R_Area
@onready var medic = $CSGMesh3D/RootNode/CharacterArmature/Skeleton3D/WeaponSlot/HealItem


# --- Animations ---
@export var ANIM_IDLE = "CharacterArmature|Idle"
@export var ANIM_WALK = "CharacterArmature|Walk"
@export var ANIM_RUN = "CharacterArmature|Run"
@export var ANIM_ROLL = "CharacterArmature|Roll"
@export var ANIM_HIT = "CharacterArmature|HitRecieve"
@export var ANIM_DEATH = "CharacterArmature|Death"

@export var ANIM_IDLE_GUN = "CharacterArmature|Idle_Gun"
@export var ANIM_AIM_GUN = "CharacterArmature|Idle_Gun_Pointing"
@export var ANIM_SHOOT_GUN = "CharacterArmature|Idle_Gun_Shoot"
@export var ANIM_RUN_SHOOT = "CharacterArmature|Run_Shoot"
@export var ANIM_SHOOT_ALT = "CharacterArmature|Gun_Shoot"
@export var ANIM_FIRE = "PistolArmature|Fire"
@export var ANIM_RELOAD = "PistolArmature|Reload"
@export var ANIM_SLIDE = "PistolArmature|Slide"
@export var reload_anim_delay: float = 0.12   # หน่วงก่อนเล่นท่ารีโหลด (วินาที)
@export var reload_anim_speed: float = 1.0    # ความเร็วท่ารีโหลด (1.0 = ปกติ)

@export var ANIM_IDLE_SWORD = "CharacterArmature|Idle_Sword"
@export var ANIM_SLASH_SWORD = "CharacterArmature|Sword_Slash"

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina

	if is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = health

	# ✅ ต่อสัญญาณจากปืนให้ถูกอินเดนต์ และเช็กว่ามีโหนดจริง
	if is_instance_valid(pistol):
		if not pistol.is_connected("reload_started", Callable(self, "_on_pistol_reload_started")):
			pistol.connect("reload_started", Callable(self, "_on_pistol_reload_started"))
		if not pistol.is_connected("reload_finished", Callable(self, "_on_pistol_reload_finished")):
			pistol.connect("reload_finished", Callable(self, "_on_pistol_reload_finished"))

	has_gun = false
	if camera:
		default_fov = camera.fov

	_hide_all_weapons_in_slot()
	if is_instance_valid(pistol): pistol.visible = false
	if is_instance_valid(sword):  sword.visible  = false
	if is_instance_valid(medic):  medic.visible  = false

	if anim_player and anim_player.has_animation(ANIM_IDLE):
		anim_player.play(ANIM_IDLE)

	if is_instance_valid(punch_L): punch_L.add_to_group("player_weapon")
	if is_instance_valid(punch_R): punch_R.add_to_group("player_weapon")
	if is_instance_valid(kick_L):  kick_L.add_to_group("player_weapon")
	if is_instance_valid(kick_R):  kick_R.add_to_group("player_weapon")

	_disable_all_melee_hitboxes() # ปิด hitbox ตอนเริ่มเกม

	if weapon_ui and weapon_ui.has_method("update_slots"):
		weapon_ui.update_slots(has_sword, has_gun, has_medic)

func _on_pistol_reload_started() -> void:
	is_reloading_gun = true
	if not anim_player:
		return

	# หน่วงก่อนเล่น (กันกระชากจากจังหวะยิง)
	if reload_anim_delay > 0.0:
		await get_tree().create_timer(reload_anim_delay).timeout

	# ลดความเร็วชั่วคราว แล้วเล่นท่า
	var old_speed := anim_player.speed_scale
	anim_player.speed_scale = reload_anim_speed

	if anim_player.has_animation(ANIM_SLASH_SWORD):
		anim_player.play(ANIM_SLASH_SWORD)

	# ประเมินเวลาเล่นจริง (ยาวขึ้นตาม speed_scale) เพื่อคืน speed ทีหลัง
	var dur = anim_player.current_animation_length / max(0.001, anim_player.speed_scale)
	get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(anim_player):
			anim_player.speed_scale = old_speed
	)


# ฟังก์ชันรับสัญญาณรีโหลดเสร็จ
func _on_pistol_reload_finished() -> void:
	is_reloading_gun = false
	if anim_player:
		anim_player.speed_scale = 1.0   # คืนความเร็วเผื่อกรณีโดนขัดจังหวะ

	var mv := Input.get_vector("move_left","move_right","move_forward","move_backward")
	var moving := mv.length() > 0.1
	var running := Input.is_action_pressed("run") and stamina > 0

	if not anim_player:
		return

	if has_gun:
		if is_aiming and anim_player.has_animation(ANIM_AIM_GUN):
			anim_player.play(ANIM_AIM_GUN)
		elif moving:
			if running and anim_player.has_animation(ANIM_RUN_SHOOT):
				anim_player.play(ANIM_RUN_SHOOT)
			else:
				anim_player.play(ANIM_WALK)
		else:
			anim_player.play(ANIM_IDLE_GUN)
	else:
		if moving:
			anim_player.play(ANIM_RUN if running else ANIM_WALK)
		else:
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
		anim_player.play(ANIM_IDLE_SWORD)

	if Input.is_action_just_pressed("equip_2"):
		_toggle_gun()
		anim_player.play(ANIM_IDLE_GUN)
		
	if Input.is_action_just_pressed("equip_3"):
		_toggle_medic()
		anim_player.play(ANIM_IDLE_SWORD)

	# กด R เพื่อ reload (เฉพาะตอนถือปืน)
	if Input.is_action_just_pressed("reload"):
		if has_gun and is_instance_valid(pistol) and pistol.has_method("try_reload"):
			var need = pistol.mag_size - pistol.ammo_in_mag
			var reserve_ok = (pistol.ammo_reserve < 0) or (pistol.ammo_reserve > 0)  # <0 = unlimited
			# ไม่อนุญาตรีโหลดถ้าแม็กเต็ม หรือไม่มีกระสุนสำรอง
			if need <= 0 or not reserve_ok:
			# (ตัวเลือก) เล่นเสียงแจ้งเตือน/โชว์ UI ที่นี่
				return
			is_reloading_gun = true 
			pistol.try_reload()
			# (ตัวเลือก) เล่นท่าร่างกายตอนรีโหลด ถ้ามี
			if anim_player and anim_player.has_animation(ANIM_SLASH_SWORD):
				anim_player.play(ANIM_SLASH_SWORD)  # หรือคลิปรีโหลดของ "ตัวละคร" ถ้ามี

func _do_attack(current_time: float) -> void:
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

	if anim_player and attack_index < attack_anims.size() and anim_player.has_animation(attack_anims[attack_index]):
		anim_player.play(attack_anims[attack_index])
		_apply_melee_damage(attack_anims[attack_index]) # ✅ เพิ่มการทำดาเมจต่อย/เตะ

	attack_index = (attack_index + 1) % attack_anims.size()
	last_attack_time = current_time

	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false

func _physics_process(_delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if is_stunned:
		velocity = Vector3.ZERO
		return

	if not Input.is_action_pressed("run") and not is_rolling and not is_attacking:
		stamina = min(max_stamina, stamina + stamina_recovery * _delta)

	if not is_on_floor():
		velocity.y -= gravity * _delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = JUMP_VELOCITY

	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cur_speed = SPEED

	if Input.is_action_pressed("run") and stamina > 0.0 and input_vec.length() > 0.1 and not is_attacking:
		cur_speed = RUN_SPEED
		stamina = max(0, stamina - run_cost * _delta)

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

	if has_sword and not has_gun and not has_medic:
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

	if has_gun and not has_sword and not has_medic:
		is_aiming = Input.is_action_pressed("aim")
		if camera:
			camera.fov = lerp(camera.fov, aim_fov if is_aiming else default_fov, 10.0 * _delta)
		if Input.is_action_just_pressed("fire") and not is_attacking and not is_rolling:
			print("[DEBUG] fire pressed")
			_shoot_gun()

	if has_medic and not has_sword and not has_gun:
		if Input.is_action_just_pressed("fire") and not is_attacking and not is_rolling:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_heal_time >= heal_cooldown and health < max_health:
				_use_heal()
				last_heal_time = now

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
func _apply_stun(duration: float) -> void:
	if is_stunned:
		return # ถ้าสตันอยู่แล้ว ไม่ต้องซ้อน
	is_stunned = true
	print("😵 Player stunned for", duration, "seconds")
	
	await get_tree().create_timer(duration).timeout
	is_stunned = false
	print("✅ Stun ended")

func take_damage(amount: float, _source: Variant = null) -> void:
	if is_dead or is_invulnerable:
		return

	health -= amount
	health = max(0, health)
	if is_instance_valid(health_bar):
		health_bar.value = health

	print("Took damage: ", amount, " | HP:", health)

	if health <= 0:
		_die()
	else:
		_start_invulnerability()
		if anim_player and anim_player.has_animation("CharacterArmature|HitRecieve_2"):
			anim_player.play("CharacterArmature|HitRecieve_2")
		_apply_stun(stun_duration)
		

func heal(amount: float) -> void:
	if is_dead: return
	health = min(max_health, health + amount)
	if is_instance_valid(health_bar): health_bar.value = health

func _start_invulnerability() -> void:
	is_invulnerable = true
	await get_tree().create_timer(INVULNERABILITY_DURATION).timeout
	is_invulnerable = false

func _die() -> void:
	if is_dead: return
	is_dead = true
	print("Character is dead!")

	set_physics_process(false)
	set_process(false)

	if anim_player and anim_player.has_animation(ANIM_DEATH):
		anim_player.play(ANIM_DEATH)

	velocity = Vector3.ZERO

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("mons"):
		var dmg = 10.0
		if body.has_method("get_attack_damage"):
			dmg = body.get_attack_damage()
		elif body.has_meta("damage"):
			dmg = body.get_meta("damage")
		take_damage(dmg)

# -----------------------------------------------
# WEAPON SLOT HELPERS
# -----------------------------------------------
func _toggle_sword():
	has_sword = not has_sword
	if has_sword:
		has_gun = false
		has_medic = false
	_hide_all_weapons_in_slot()
	if has_sword and is_instance_valid(sword):
		sword.visible = true
	if weapon_ui and weapon_ui.has_method("update_slots"):
		weapon_ui.update_slots(has_sword, has_gun, has_medic)

func _toggle_gun():
	has_gun = not has_gun
	if has_gun:
		has_sword = false
		has_medic = false
	_hide_all_weapons_in_slot()
	if has_gun and is_instance_valid(pistol):
		pistol.visible = true
	else:
		if camera:
			camera.fov = default_fov
	if weapon_ui and weapon_ui.has_method("update_slots"):
		weapon_ui.update_slots(has_sword, has_gun, has_medic)

func _toggle_medic():
	has_medic = not has_medic
	if has_medic:
		has_sword = false
		has_gun = false
	_hide_all_weapons_in_slot()
	if has_medic and is_instance_valid(medic):
		medic.visible = true
	else:
		if camera:
			camera.fov = default_fov
	if weapon_ui and weapon_ui.has_method("update_slots"):
		weapon_ui.update_slots(has_sword, has_gun, has_medic)

func _slash_sword():
	if not has_sword or is_swing: return
	is_swing = true
	if anim_player and anim_player.has_animation(ANIM_SLASH_SWORD):
		anim_player.play(ANIM_SLASH_SWORD)
	if sword and sword.has_method("swing"):
		sword.swing()
	if lock_move_during_sword:
		move_locked = true
	
	var dur = anim_player.current_animation_length if anim_player and anim_player.current_animation == ANIM_SLASH_SWORD else attack_cooldown
	
	await get_tree().create_timer(dur).timeout
	move_locked = false
	is_swing = false
	is_attacking = false

func _shoot_gun():
	if not has_gun: return
	if is_shooting: return

	is_shooting = true

	var moving_now := Input.get_vector("move_left","move_right","move_forward","move_backward").length() > 0.1
	# --- เล่นคลิปฝั่ง "ตัวละคร" (ร่างกาย) ---
	if anim_player:
		# ถ้าวิ่ง/เดินตอนยิง และมีคลิป Run_Shoot ให้เล่นอันนั้นก่อน
		if moving_now and anim_player.has_animation(ANIM_RUN_SHOOT):
			anim_player.play(ANIM_RUN_SHOOT)
		elif anim_player.has_animation(ANIM_SHOOT_GUN):
			anim_player.play(ANIM_SHOOT_GUN)
		elif anim_player.has_animation(ANIM_SHOOT_ALT):
			anim_player.play(ANIM_SHOOT_ALT)
	# --- ยิงปืนจริง (hitscan + เอฟเฟกต์ อยู่ใน Pistol.gd) ---
	if pistol and pistol.has_method("try_fire"):
		pistol.try_fire()
	# --- หน่วงเวลาคืนท่า (ให้มือปืน/ตัวละครมีเวลาจบคีย์เฟรม) ---
	# แนะนำตั้ง shoot_recover_time ≈ 1.0 / fire_rate ของปืน
	await get_tree().create_timer(shoot_recover_time).timeout
	# --- คืนท่าตามสถานะหลังยิง (ผู้เล่นอาจเริ่ม/หยุดเดินระหว่างรอ) ---
	var move_vec := Input.get_vector("move_left","move_right","move_forward","move_backward")
	var moving_after := move_vec.length() > 0.1
	var running_after = Input.is_action_pressed("run") and stamina > 0

	if anim_player:
		if moving_after:
			anim_player.play(ANIM_RUN if running_after else ANIM_WALK)
		else:
			anim_player.play(ANIM_IDLE_GUN)

	is_shooting = false

func _use_heal():
	if is_dead or is_healing: return
	if health >= max_health: return

	is_healing = true

	if is_instance_valid(medic):
		medic.visible = true

	if anim_player and anim_player.has_animation("CharacterArmature|Interact"):
		anim_player.play("CharacterArmature|Interact")

	# ระหว่างดื่มยา ระหว่างใช้ยาความเร็วลดลง
	var original_speed = SPEED
	var original_run_speed = RUN_SPEED
	SPEED *= 0.1
	RUN_SPEED *= 0.1
	is_attacking = true
	# ✅ รอ 2 วินาที (หรือปรับตามความยาวแอนิเมชัน Heal)
	await get_tree().create_timer(2.0).timeout

	# ✅ ฟื้นเลือด
	var old_hp = health
	health = min(max_health, health + heal_amount)
	if is_instance_valid(health_bar):
		health_bar.value = health

	# ✅ คืนค่าความเร็ว
	SPEED = original_speed
	RUN_SPEED = original_run_speed

	is_attacking = false
	is_healing = false
	
func _update_animation(input_vec: Vector2):
	# --- อย่า override animation ตอนกำลังโจมตี, สวิงดาบ, ยิง หรือใช้ยา ---
	if is_attacking or is_rolling or is_shooting or is_swing or is_healing or is_reloading_gun:
		return
	
	var moving = input_vec.length() > 0.1
	var running = Input.is_action_pressed("run") and stamina > 0

	# --- เลือก animation ตามอาวุธที่ถือ ---
	if has_sword:
		if moving:
			anim_player.play(ANIM_RUN if running else ANIM_WALK)
		else:
			anim_player.play(ANIM_IDLE_SWORD)
	elif has_gun:
		if is_aiming:
			anim_player.play(ANIM_AIM_GUN)
		elif moving:
			anim_player.play(ANIM_RUN if running else ANIM_WALK)
		else:
			anim_player.play(ANIM_IDLE_GUN)
	else:
		# มือเปล่า หรือไม่มีอาวุธ
		if moving:
			anim_player.play(ANIM_RUN if running else ANIM_WALK)
		else:
			anim_player.play(ANIM_IDLE)

# -----------------------------------------------
# MELEE ATTACK DAMAGE SYSTEM (Punch/Kick)
# -----------------------------------------------

@export var melee_damage_punch: float = 25
@export var melee_damage_kick: float = 25
@export var hitbox_active_time: float = 0.25

func _enable_hitbox(area: Area3D, dmg: float):
	if not is_instance_valid(area):
		return
	area.monitoring = true
	area.set_meta("damage", dmg)
	await get_tree().create_timer(hitbox_active_time).timeout
	if is_instance_valid(area):
		area.monitoring = false
		area.set_meta("damage", 0)

func _disable_all_melee_hitboxes():
	for a in [punch_L, punch_R, kick_L, kick_R]:
		if is_instance_valid(a):
			a.monitoring = false
			a.set_meta("damage", 0)

func _apply_melee_damage(attack_name: String):
	match attack_name:
		"CharacterArmature|Punch_Left":
			_enable_hitbox(punch_L, melee_damage_punch)
		"CharacterArmature|Punch_Right":
			_enable_hitbox(punch_R, melee_damage_punch)
		"CharacterArmature|Kick_Left":
			_enable_hitbox(kick_L, melee_damage_kick)
		"CharacterArmature|Kick_Right":
			_enable_hitbox(kick_R, melee_damage_kick)

# --- Signals สำหรับ hitbox ทั้ง 4 ---
func _on_Hand_L_Area_body_entered(body):
	_handle_melee_hit(body, punch_L)
func _on_Hand_R_Area_body_entered(body):
	_handle_melee_hit(body, punch_R)
func _on_Leg_L_Area_body_entered(body):
	_handle_melee_hit(body, kick_L)
func _on_Leg_R_Area_body_entered(body):
	_handle_melee_hit(body, kick_R)

func _handle_melee_hit(body, area):
	if not is_instance_valid(area):
		return

	# 🚫 หากถืออาวุธ (ดาบ, ปืน, หรือยา) ให้หมัด/เตะไม่มีผล
	if has_sword or has_gun or has_medic:
		return

	if body.is_in_group("mons") and area.has_meta("damage"):
		var dmg = area.get_meta("damage")
		if dmg > 0 and body.has_method("take_damage"):
			body.take_damage(dmg)
