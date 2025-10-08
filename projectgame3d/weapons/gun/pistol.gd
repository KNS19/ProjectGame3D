# Pistol.gd — Hitscan + External/Particle Muzzle + Animations
extends Node3D
class_name Pistol
signal reload_started
signal reload_finished

# ===== ammo =====
@export var mag_size: int = 12                 # ความจุแม็ก
@export var ammo_in_mag: int = 12              # กระสุนที่เหลือในแม็กตอนเริ่ม
@export var ammo_reserve: int = -1             # กระสุนสำรองที่พกอยู่ไม่จำกัด
@export var allow_dry_fire_click: bool = true  # ให้คลิกแห้งเมื่อแม็กว่าง
@export var auto_reload_on_empty: bool = true    # หมดแม็กแล้วรีโหลดอัตโนมัติ
@export var auto_reload_delay: float = 3      # หน่วงนิดให้แอนิเมชัน/เสียงยิงออกก่อน
@export var damage: float = 20.0
@export var range: float = 200.0                 # ระยะยิงสูงสุด
@export var fire_rate: float = 2.0               # นัด/วินาที

# ---- Nodes / assets ----
@export var camera_path: NodePath                # Camera3D ของผู้เล่น
@export var muzzle_path: NodePath = ^"Muzzle"    # Marker3D ปลายลำกล้อง
@export var impact_scene: PackedScene            # เอฟเฟกต์โดนเป้า
@export var muzzle_flash_scene: PackedScene      # เอฟเฟกต์ปืนจากภายนอก (.tscn/.glb)
@export var use_layers_mask: int = 0             # 0 = ใช้ mask ของโลก

# ---- Animation ----
@export var anim_player_path: NodePath           # ชี้ไปที่ AnimationPlayer ในซีนปืน
@export var ANIM_FIRE = "PistolArmature|Fire"
@export var ANIM_RELOAD = "PistolArmature|Reload"
@export var ANIM_SLIDE = "PistolArmature|Slide"
@export var fire_anim_restart: bool = true       # ยิงซ้ำให้รีสตาร์ทคลิปได้ไหม
@export var ANIM_SLASH_SWORD = "CharacterArmature|Sword_Slash"

@onready var _cam: Camera3D = get_node_or_null(camera_path)
@onready var _muzzle: Marker3D = get_node_or_null(muzzle_path)
@onready var _sfx: AudioStreamPlayer3D = $ShootSfx if has_node("ShootSfx") else null
@onready var _flash_particle: GPUParticles3D = $MuzzleFlash if has_node("MuzzleFlash") else null
@onready var _anim: AnimationPlayer = get_node_or_null(anim_player_path)
@onready var _dry_sfx: AudioStreamPlayer3D = $DrySfx if has_node("DrySfx") else null
@onready var anim_player: AnimationPlayer = $CSGMesh3D/AnimationPlayer

var _last_shot_time := -9999.0
var _is_reloading := false

func _ready() -> void:
	# fallback: ใช้ active camera ของ viewport ถ้าไม่ได้ assign
	if _cam == null:
		_cam = get_viewport().get_camera_3d()

	if _anim:
		_anim.animation_finished.connect(_on_anim_finished)

	if _cam == null:
		push_warning("Pistol.gd: กรุณาเซ็ต camera_path ให้ชี้ไปยัง Camera3D ของผู้เล่น")

func try_fire() -> void:
	if _is_reloading: 
		return

# --- เช็คกระสุนในแม็ก ---
	if ammo_in_mag <= 0:
		# แม็กว่าง → เล่นสไลด์/เสียงคลิก แล้วไม่ยิง
		if allow_dry_fire_click and _dry_sfx:
			_dry_sfx.play()
		# (ถ้ามีคลิป Slide ของปืน)
		play_slide()
		return

	# --- คูลดาวน์ ---
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown = 1.0 / max(0.001, fire_rate)
	if now - _last_shot_time < cooldown:
		return
	_last_shot_time = now
	# ✅ หักกระสุนในแม็ก 1 นัด
	ammo_in_mag = max(0, ammo_in_mag - 1)
	
	# --- ยิง Ray จากใจกลางจอ ---
	if _cam == null: 
		return
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	var origin: Vector3 = _cam.project_ray_origin(center)
	var dir: Vector3    = _cam.project_ray_normal(center).normalized()
	var to: Vector3     = origin + dir * range

	var space := get_world_3d().direct_space_state
	var exclude: Array = [self]
	var p := get_parent()
	if p: exclude.append(p)
	if p and p.get_parent(): exclude.append(p.get_parent())

	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = to
	query.exclude = exclude
	if use_layers_mask != 0:
		query.collision_mask = use_layers_mask

	var hit := space.intersect_ray(query)

	# --- เอฟเฟกต์ปากกระบอก + เสียง + แอนิเมชัน ---
	#_spawn_muzzle_flash()
	if _sfx: _sfx.play()
	_play_fire_anim()

	# --- ถ้าโดนเป้า: ดาเมจ + impact ---
	if hit:
		var pos: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		var collider = hit.collider

		if collider:
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
			elif collider.has_method("apply_damage"):
				collider.apply_damage(damage)
			elif collider.has_meta("health"):
				var hp: float = float(collider.get_meta("health"))
				collider.set_meta("health", max(0.0, hp - damage))

		if impact_scene:
			var impact := impact_scene.instantiate()
			get_tree().current_scene.add_child(impact)
			impact.global_transform.origin = pos
			impact.look_at(pos + normal, Vector3.UP)
			
	# --- ยิงเสร็จ: ถ้าแม็กหมด ให้รีโหลดอัตโนมัติ (ถ้าตั้งไว้และมีสำรอง/ไม่จำกัด) ---
	if ammo_in_mag == 0 and auto_reload_on_empty and _can_reload():
		if auto_reload_delay <= 0.0:
			anim_player.play(ANIM_SLASH_SWORD)
			try_reload()
			
		else:
			var t := get_tree().create_timer(auto_reload_delay)
			t.timeout.connect(Callable(self, "try_reload"))
			
# -------------------- Reload & Slide API --------------------
func _reserve_unlimited() -> bool:
	return ammo_reserve < 0
	
func _can_reload() -> bool:
	var need := mag_size - ammo_in_mag
	return need > 0 and (_reserve_unlimited() or ammo_reserve > 0)
	
var _pending_reload: int = 0

func try_reload() -> void:
	if _is_reloading:
		return
	# คำนวณว่าควรเติมกี่นัด
	var need := mag_size - ammo_in_mag
	if need <= 0:
		return

# ถ้าไม่ unlimited และสำรองหมด → ยกเลิก
	if (not _reserve_unlimited()) and ammo_reserve <= 0:
		return

	# จำนวนที่จะเติม: ถ้า unlimited ก็เติมเต็ม need, ถ้าไม่ใช่ก็ขั้นต่ำ
	_pending_reload = need if _reserve_unlimited() else min(need, ammo_reserve)
	_is_reloading = true
	reload_started.emit()  

	if _anim and _anim.has_animation(ANIM_RELOAD):
		_anim.play(ANIM_RELOAD)
	else:
		# ถ้าไม่มีคลิป Reload ก็ถือว่ารีโหลดเสร็จทันที
		_complete_reload()

func play_slide() -> void:
	if _anim and _anim.has_animation(ANIM_SLIDE):
		_anim.play(ANIM_SLIDE)

func _on_anim_finished(name: StringName) -> void:
	if name == ANIM_RELOAD or name == StringName("Reload") or name == StringName("PistolArmature|Reload"):
		_complete_reload()

func _complete_reload() -> void:
	if _pending_reload > 0:
		ammo_in_mag += _pending_reload
		if not _reserve_unlimited():
			ammo_reserve -= _pending_reload
	_pending_reload = 0
	_is_reloading = false
	reload_finished.emit() 
	_anim.play(ANIM_SLIDE)

# -------------------- Internal helpers --------------------

#func _spawn_muzzle_flash() -> void:
	# ใช้ particle เดิมถ้ามี
	#if _flash_particle:
		#_flash_particle.emitting = false
		#_flash_particle.emitting = true
		#return
#
	# ใช้ซีนเอฟเฟกต์ภายนอก
	#if muzzle_flash_scene:
		#var fx := muzzle_flash_scene.instantiate()
		#get_tree().current_scene.add_child(fx)
		#if _muzzle:
			#fx.global_transform = _muzzle.global_transform
		#else:
			#fx.global_transform.origin = _cam.project_ray_origin(get_viewport().get_visible_rect().size * 0.5)
		#get_tree().create_timer(1.0).connect("timeout", Callable(fx, "queue_free"))

func _play_fire_anim() -> void:
	if _anim == null:
		return

	# ถ้ามีคลิป Fire ให้เล่น (เลือกชื่อสำรองอัตโนมัติ)
	var clip: StringName = ANIM_FIRE
	if not _anim.has_animation(clip):
		if _anim.has_animation("Fire"): clip = "Fire"
		elif _anim.has_animation("PistolArmature|Fire"): clip = "PistolArmature|Fire"
		else: return

	if fire_anim_restart:
		_anim.stop(true) # reset เพื่อยิงติดนิ้ว
	_anim.play(clip)
