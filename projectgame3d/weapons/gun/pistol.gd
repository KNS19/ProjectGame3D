# pistol.gd — ยิงกระสุนเป็น "projectile" (มีซีนกระสุน Bullet.tscn) ออกจากปลายลำกล้อง
# โค้ดนี้คอมเมนต์ละเอียดอธิบายทุกส่วนว่าทำอะไร

extends Node3D  # ปืนเป็นโหนด 3D ทั่วไป

# -------------------- ตัวแปรตั้งค่าได้จาก Inspector --------------------

@export var bullet_pitch_fix_deg: float = 0.0   # ชดเชยมุม "ก้ม/เงย" (แกน X) ของโมเดลกระสุน หากหัวกระสุนชี้แกนไม่ตรง
@export var bullet_yaw_fix_deg: float = 0.0     # ชดเชยมุม "หมุนซ้าย/ขวา" (แกน Y)
@export var bullet_roll_fix_deg: float = 0.0    # ชดเชยมุม "กลิ้ง/เอียง" (แกน Z)

@export var fire_rate: float = 6.0              # อัตรายิง (นัด/วินาที) → คูลดาวน์ = 1 / fire_rate
@export var damage: int = 10                    # ดาเมจของกระสุนนัดนี้
@export var bullet_speed: float = 60.0          # ความเร็วกระสุน (หน่วย/วินาที) ต้องตรงกับ bullet.gd ที่เอาไปคูณทิศ
@export var recoil_deg: float = 1.2             # มุมดีดกล้องแนวตั้ง (องศา) ทุกครั้งที่ยิง
@export var impact_scene: PackedScene            # ซีน FX ตอนกระสุนโดนเป้า (ใส่หรือไม่ใส่ก็ได้)

@export var muzzle: Node3D                       # จุด "ปลายลำกล้อง" (Marker3D/Node3D) ใช้เป็นตำแหน่งสปอว์นกระสุน
@export var bullet_scene: PackedScene            # ซีนกระสุน (root ควรเป็น Node3D และแนบ bullet.gd)
@export var shoot_sfx: AudioStreamPlayer3D       # เสียงปืน (ออปชัน)
@export var anim_player: AnimationPlayer         # แอนิเมชันปืน (ออปชัน) เช่นมีคลิปชื่อ "fire"
@export var muzzle_flash: GPUParticles3D         # เอฟเฟกต์ไฟปากกระบอก (ออปชัน)
@export var camera: Camera3D                     # กล้องผู้เล่น ใช้หา"ทิศเล็ง"ให้กระสุนยิงไป

@export var muzzle_spawn_offset: float = 0.35    # ดันตำแหน่งเกิดกระสุนออกจากปลายลำกล้องอีกหน่อย กันชนปืน/แขนตัวละคร

# -------------------- ตัวแปรภายใน --------------------

var _can_fire := true                            # ตัวล็อกคูลดาวน์ ป้องกันกดยิงรัวเกิน fire_rate
@onready var _character := _find_character()     # เก็บอ้างอิงตัวละครผู้ถือปืน (ไว้ exclude collider ตอนยิง ray หาเป้า)

# -------------------- ยูทิลิตี้: หา CharacterBody3D ผู้ถือปืน --------------------

func _find_character() -> Node:
	# ไต่ขึ้นตามพาเรนต์จนเจอโหนดประเภท CharacterBody3D
	var n: Node = self
	while n and not (n is CharacterBody3D):
		n = n.get_parent()
	return n

# -------------------- ยูทิลิตี้: รวม RID ของคอลลิเดอร์ใต้โหนด (แบบ recursive) --------------------

func _collect_colliders_rids(root: Node, into: Array[RID]) -> void:
	# ใช้เมื่อจะยิง ray จาก "กล้อง" หาเป้า เพื่อ exclude ร่างผู้ยิง/ปืน/มัดเซิล ไม่ให้ ray ชนตัวเอง
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n = stack.pop_back()
		var co := n as CollisionObject3D
		if co:
			into.append(co.get_rid())           # เก็บ RID ของคอลลิเดอร์ไว้ในลิสต์
		for c in n.get_children():
			stack.append(c)                     # ไล่ลูกทุกตัว

# -------------------- คำนวณ "ทิศยิง" จากกล้อง (crosshair) → แปลงเป็นทิศจากปลายลำกล้อง --------------------

func _get_aim_dir() -> Vector3:
	# ถ้าไม่มีกล้องหรือไม่มีมัดเซิล ให้ยิงไปตาม -Z ของปืนเพื่อกันพัง
	if camera == null or muzzle == null:
		return -global_transform.basis.z

	# จุดกำเนิดและทิศของกล้อง (Godot กล้องมองไปทาง -Z)
	var cam_origin := camera.global_transform.origin
	var cam_forward := -camera.global_transform.basis.z

	# สร้าง ray จาก "กล้อง → ไกลมาก" เพื่อหาจุดเล็ง (ชนกำแพง/ศัตรูก็จะได้จุดชน)
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.new()
	rq.from = cam_origin
	rq.to   = cam_origin + cam_forward * 10000.0

	# exclude คอลลิเดอร์ทั้งหมดของ "ตัวละคร + ปืน + มัดเซิล" ไม่ให้ ray เล็งชนตัวเอง
	var ex: Array[RID] = []
	if _character:
		_collect_colliders_rids(_character, ex)  # ตัวละครทั้งตัว (บอดี้/แขน/กล้องที่มี collider)
	_collect_colliders_rids(self, ex)            # ปืนและลูก ๆ (ถ้ามี collider)
	if muzzle:
		_collect_colliders_rids(muzzle, ex)      # มัดเซิล (เผื่อใส่ collider)
	rq.exclude = ex

	# ยิง ray หาเป้า
	var hit := space.intersect_ray(rq)
	# aim_point = ตำแหน่งที่ ray จากกล้องชน (ถ้าไม่ชนเลย ใช้ปลายทางไกลสุด)
	var aim_point = (hit.position if hit else rq.to)

	# ทิศสุดท้าย = เวกเตอร์จาก "ปลายลำกล้อง" → "aim_point"
	return (aim_point - muzzle.global_transform.origin).normalized()

# -------------------- ฟังก์ชันหลัก: ยิงกระสุน (สร้าง projectile ออกจากปลายลำกล้อง) --------------------

func try_fire() -> void:
	# 1) กันคูลดาวน์ และถ้าปืนถูกซ่อนไว้ (visible=false) ก็ไม่ยิง
	if not _can_fire or not visible:
		return
	_can_fire = false  # ล็อกยิง ไว้ปลดตอนครบคูลดาวน์

	# 2) เอฟเฟกต์ปืน (แล้วแต่จะมีหรือไม่)
	if anim_player and anim_player.has_animation("fire"):
		anim_player.play("fire")       # เล่นคลิปยิง
	if muzzle_flash:
		muzzle_flash.restart()         # จุดประกายไฟปากลำกล้อง
	if shoot_sfx:
		shoot_sfx.play()               # เล่นเสียงยิง

	# 3) ต้องมีซีนกระสุนและมัดเซิลก่อนถึงจะยิง projectile ได้
	if bullet_scene == null or muzzle == null:
		push_warning("ตั้งค่า 'bullet_scene' และ 'muzzle' ใน Inspector ให้เรียบร้อยก่อน")
	else:
		# 3.1) สร้างอินสแตนซ์ของซีนกระสุน
		var b := bullet_scene.instantiate()
		# 3.2) เอาไปแปะไว้ใต้ซีนหลัก (world) เพื่อให้กระสุนมีอิสระ
		get_tree().current_scene.add_child(b)

		# 3.3) ถ้ากระสุนเป็น Node3D (ตามที่คาด) ให้ตั้งค่าตำแหน่ง/หมุน/ความเร็ว
		if b is Node3D:
			# คำนวณ "ทิศยิง" ตามกล้อง (เล็ง crosshair) แล้วไปจากปลายลำกล้อง
			var dir := _get_aim_dir()

			# คำนวณตำแหน่งเกิดกระสุน: ปลายลำกล้อง + ดันไปตามทิศอีกนิด กันชนปืน/แขน
			var spawn_pos := muzzle.global_transform.origin + dir * muzzle_spawn_offset

			# สร้าง Basis ให้ -Z ของกระสุนชี้ตามทิศยิง (แล้วค่อยชดเชยมุมตามโมเดลกระสุน)
			var basis := Basis().looking_at(dir, Vector3.UP)
			basis = basis.rotated(Vector3.RIGHT,   deg_to_rad(bullet_pitch_fix_deg))  # ชดเชยแกน X
			basis = basis.rotated(Vector3.UP,      deg_to_rad(bullet_yaw_fix_deg))    # ชดเชยแกน Y
			basis = basis.rotated(Vector3.FORWARD, deg_to_rad(bullet_roll_fix_deg))   # ชดเชยแกน Z

			# เซ็ตทรานส์ฟอร์มเริ่มต้นของกระสุน (หมุน + ตำแหน่งเกิด)
			b.global_transform = Transform3D(basis, spawn_pos)

			# ส่งพารามิเตอร์เข้ากระสุนให้เริ่มวิ่ง: ทิศ, ดาเมจ, ความเร็ว, FX, และอ้างผู้ยิง
			# (bullet.gd ควรมีเมธอด configure(dir, dmg, spd, imp, shooter))
			if b.has_method("configure"):
				b.configure(dir, damage, bullet_speed, impact_scene, _character)

	# 4) ดีดกล้องเล็กน้อยเพื่อฟีลลิ่งการยิง
	if camera and recoil_deg != 0.0:
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x - recoil_deg, -89.0, 89.0)

	# 5) ตั้งตัวจับเวลาคูลดาวน์ตาม fire_rate แล้วค่อยปลดล็อกยิง
	await get_tree().create_timer(1.0 / max(0.001, fire_rate)).timeout
	_can_fire = true
