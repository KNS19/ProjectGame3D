# pistol.gd  (ติดกับ Node ปืน เช่น Skeleton3D/WeaponSlot/Pistol)
extends Node3D

# --- Config ---
@export var fire_rate: float = 0.1   # นัดต่อวินาที (6 = ยิงได้ทุก ~0.166s)
@export var damage: int = 10
@export var max_distance: float = 120.0   # ระยะยิง (สำหรับ RayCast3D)
@export var recoil_deg: float = 1.2       # ดีดกล้องเล็กน้อย (ถ้าไม่ได้โยง camera จะไม่ทำอะไร)

# --- References (ลากใส่ใน Inspector) ---
@export var muzzle: Node3D                 # ปลายกระบอก (Marker3D/Position3D)
@export var ray: RayCast3D                 # RayCast3D ชี้ไปข้างหน้า (enabled=true)
@export var shoot_sfx: AudioStreamPlayer3D # เสียงปืน (ไม่บังคับ)
@export var anim_player: AnimationPlayer   # แอนิเมชันปืน (ถ้ามี clip ชื่อ "fire")
@export var muzzle_flash: GPUParticles3D   # เอฟเฟกต์ปากกระบอก (ไม่บังคับ)
@export var impact_scene: PackedScene      # ฉากฝุ่น/ประกายตอนโดนเป้า (ไม่บังคับ)
@export var camera: Camera3D               # กล้องผู้เล่น (ถ้าอยากโยน recoil)

var _can_fire := true

func try_fire() -> void:
	# ถูกเรียกจาก character.gd เท่านั้น
	if not _can_fire or not visible:
		return
	_can_fire = false

	# เอฟเฟกต์ยิง
	if anim_player and anim_player.has_animation("fire"):
		anim_player.play("fire")
	if muzzle_flash:
		muzzle_flash.restart()
	if shoot_sfx:
		shoot_sfx.play()

	# ยิงด้วย RayCast3D
	if ray:
		# ตั้งเป้าระยะ (RayCast3D ของ Godot 4 ใช้ local target_position)
		ray.target_position = Vector3(0, 0, -max_distance)
		ray.force_raycast_update()

		if ray.is_colliding():
			var collider = ray.get_collider()
			var hit_point = ray.get_collision_point()
			var hit_normal = ray.get_collision_normal()

			# สร้างเอฟเฟกต์โดนเป้า
			if impact_scene:
				var impact = impact_scene.instantiate()
				get_tree().current_scene.add_child(impact)
				impact.global_transform.origin = hit_point
				impact.look_at(hit_point + hit_normal, Vector3.UP)

			# ส่งดาเมจ ถ้าเป้ามีเมธอด apply_damage(dmg)
			if collider and collider.has_method("apply_damage"):
				collider.apply_damage(damage)

	# Recoil ง่าย ๆ
	if camera and recoil_deg != 0.0:
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x - recoil_deg, -89.0, 89.0)

	# คูลดาวน์ตาม fire_rate
	await get_tree().create_timer(1.0 / max(0.001, fire_rate)).timeout
	_can_fire = true
