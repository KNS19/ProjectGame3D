# bullet.gd — กระสุนแบบ Projectile (ไม่มีแรงโน้มถ่วง), กันทะลุด้วย ray
extends Node3D                                      # กระสุนเป็นโหนด 3D ปกติ

# ---------- ปรับค่าได้จาก Inspector ----------
@export var speed: float = 60.0                     # ความเร็วกระสุน (หน่วย/วินาที)
@export var lifetime: float = 3.0                   # อายุสูงสุดของกระสุน (วินาที)
@export var damage: int = 10                        # ดาเมจใส่เป้าหมาย
@export var impact_scene: PackedScene               # FX ตอนชน (ไม่ใส่ก็ได้)

@export var auto_orient := true                     # ให้หัวกระสุนหันตามทิศเคลื่อนที่ทุกเฟรมหรือไม่
@export var pitch_fix_deg := 0.0                    # ชดเชยมุม X (ถ้าโมเดลชี้แกนผิด)
@export var yaw_fix_deg := 0.0                      # ชดเชยมุม Y
@export var roll_fix_deg := 0.0                     # ชดเชยมุม Z

# ---------- ตัวแปรใช้งานภายใน ----------
var velocity: Vector3 = Vector3.ZERO                # เวกเตอร์ความเร็ว (ทิศ+ขนาด)
var shooter: Node = null                            # อ้างอิงผู้ยิง (กันยิงโดนตัวเอง)
var _time_left := 0.0                               # ตัวจับอายุ กระสุนจะลบตัวเองเมื่อหมดเวลา

func _ready() -> void:
	_time_left = lifetime                            # เริ่มนับอายุทันทีที่เกิด

# เรียกทันทีหลังจากถูกสปอว์นโดยปืน
# dir = ทิศยิง, dmg/spd = ค่าจากปืน, imp = FX, shooter_ref = ผู้ยิง
func configure(dir: Vector3, dmg: int, spd: float, imp: PackedScene, shooter_ref: Node) -> void:
	damage = dmg                                     # ตั้งค่าดาเมจ
	speed = spd                                      # ตั้งค่าความเร็ว
	impact_scene = imp                               # FX ตอนถูกชน
	shooter = shooter_ref                            # จำผู้ยิงไว้ เพื่อ exclude คอลลิเดอร์
	velocity = dir.normalized() * speed              # แปลงทิศเป็นความเร็วจริง

	# ตั้งท่ากระสุนตั้งแต่เฟรมแรก (ให้ -Z ของกระสุนชี้ไปตามทิศยิง)
	var basis := Basis().looking_at(velocity.normalized(), Vector3.UP)
	basis = basis.rotated(Vector3.RIGHT,   deg_to_rad(pitch_fix_deg))   # ชดเชย pitch
	basis = basis.rotated(Vector3.UP,      deg_to_rad(yaw_fix_deg))     # ชดเชย yaw
	basis = basis.rotated(Vector3.FORWARD, deg_to_rad(roll_fix_deg))    # ชดเชย roll
	global_transform = Transform3D(basis, global_transform.origin)       # เซ็ตหมุนให้โหนด

func _physics_process(delta: float) -> void:
	# หมดอายุ → ลบตัวเอง
	if _time_left <= 0.0:
		queue_free()
		return

	# คำนวณตำแหน่งจากความเร็วในเฟรมนี้
	var from: Vector3 = global_transform.origin       # ตำแหน่งเริ่ม
	var to:   Vector3 = from + velocity * delta       # ตำแหน่งปลาย

	# ยิง ray ระหว่าง from→to เพื่อกันทะลุเมื่อกระสุนวิ่งเร็ว
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.new()
	rq.from = from
	rq.to   = to
	rq.exclude = _excluded_rids()                    # ไม่ให้ ray ชนตัวผู้ยิง/ปืน/ส่วนประกอบของเขา

	var hit := space.intersect_ray(rq)               # ตรวจชน
	if hit:                                          # ถ้ามีชน
		_impact(hit)                                 # สร้าง FX + ใส่ดาเมจ
		queue_free()                                 # ลบกระสุน
		return
	else:
		global_transform.origin = to                 # ไม่มีชน → ขยับไปจุดใหม่

	# ให้หัวกระสุนหันตามทิศวิ่ง (ถ้าเปิด auto_orient)
	if auto_orient:
		var b := Basis().looking_at(velocity.normalized(), Vector3.UP)
		b = b.rotated(Vector3.RIGHT,   deg_to_rad(pitch_fix_deg))
		b = b.rotated(Vector3.UP,      deg_to_rad(yaw_fix_deg))
		b = b.rotated(Vector3.FORWARD, deg_to_rad(roll_fix_deg))
		global_transform = Transform3D(b, global_transform.origin)

	_time_left -= delta                               # ลดเวลาอายุ

# รวม RID ของคอลลิเดอร์ทุกชิ้นใต้โหนดที่ต้องการ (ไว้ exclude ตอนยิง ray)
func _collect_colliders_rids(root: Node, into: Array[RID]) -> void:
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n = stack.pop_back()
		var co := n as CollisionObject3D
		if co:
			into.append(co.get_rid())                 # เก็บ RID ของคอลลิเดอร์
		for c in n.get_children():
			stack.append(c)                           # ไล่ทั้งต้นไม้

# คืนรายการ RID ที่ต้อง exclude ตอนตรวจชน (กันยิงโดนตัวเอง)
func _excluded_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if shooter:
		_collect_colliders_rids(shooter, rids)       # ผู้ยิงทั้งตัว (ตัวละคร + อาวุธ)
	return rids

# จัดการผลกระทบเมื่อกระสุนโดนวัตถุ
func _impact(hit: Dictionary) -> void:
	# สร้าง FX ถ้ามี
	if impact_scene:
		var fx := impact_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = hit.position            # วาง FX ณ จุดชน
		fx.look_at(hit.position + hit.normal, Vector3.UP)

	# ใส่ดาเมจ ถ้าเป้ามีเมธอดรองรับ
	var target = hit.get("collider", null)
	if target:
		if target.has_method("apply_damage"):
			target.apply_damage(damage)              # ชื่อเมธอดยอดนิยม
		elif target.has_method("take_damage"):
			target.take_damage(damage)               # เผื่อใช้ชื่ออื่น
