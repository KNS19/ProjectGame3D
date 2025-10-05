extends CharacterBody3D

# --- Constants ---
const ATTACK_RANGE = 1.5
const ATTACK_DAMAGE = 10.0 # <--- ค่าดาเมจโจมตีของซอมบี้
#const PLAYER_WEAPON_DAMAGE = 100.0 # <--- ดาเมจตั้งต้นสำหรับการโจมตีจากผู้เล่น
const ANIM_ATTACK = "Armature|Attack"

# --- Variables ---
@export var speed: float = 5.0
var players: Array = []
var is_screaming: bool = false
var is_attacking: bool = false
@export var health: float = 100.0 # <--- เลือดเริ่มต้น
var is_dead: bool = false # <--- สถานะการตาย

# --- Animations ---
const ANIM_WALK = "Armature|Walk2"
const ANIM_IDLE = "Armature|Idle"
const ANIM_SCREAM = "Armature|Scream"
const ANIM_DEATH = "Armature|Die" # <--- แอนิเมชันตาย

# --- Nodes ---
@onready var detection_area: Area3D = $DetectionArea
@onready var anim: AnimationPlayer = $AnimationPlayer
# Node Path ที่คุณระบุ
@onready var head_area: Area3D = $"RootNode/Armature/Skeleton3D/BoneAttachment3D_Head/HeadArea"
@onready var body_area: Area3D = $"RootNode/Armature/Skeleton3D/BoneAttachment3D_Body/BodyArea"


func _ready():
	# ตรวจจับผู้เล่น
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

	# *** การรับดาเมจ: ตรวจสอบและเชื่อมต่อสัญญาณ ***
	
	# ตรวจสอบ Head Area
	if is_instance_valid(head_area):
		head_area.area_entered.connect(_on_hit_area_entered.bind("Head"))
		print("✅ HeadArea connected successfully.")
	else:
		# หากโหนดเป็น 'null instance' จะแสดงข้อความแจ้งเตือน
		print("❌ ERROR: HeadArea node is NULL! Check your Node Path: 'RootNode/Armature/Skeleton3D/BoneAttachment3D_Head/HeadArea'")

	# ตรวจสอบ Body Area
	if is_instance_valid(body_area):
		body_area.area_entered.connect(_on_hit_area_entered.bind("Body"))
		print("✅ BodyArea connected successfully.")
	else:
		# หากโหนดเป็น 'null instance' จะแสดงข้อความแจ้งเตือน
		print("❌ ERROR: BodyArea node is NULL! Check your Node Path: 'RootNode/Armature/Skeleton3D/BoneAttachment3D_Body/BodyArea'")

	if anim.has_animation(ANIM_IDLE):
		_play_animation_safe(ANIM_IDLE)

# --------------------------------------------------------------------------------
## ระบบดาเมจและการตาย (Damage & Death System)
# --------------------------------------------------------------------------------

# --- ฟังก์ชันรับสัญญาณการชนจาก Area3D อื่น (เช่น อาวุธผู้เล่น) ---
func _on_hit_area_entered(area: Area3D, hit_part: String):
	# ตรวจสอบว่า Area ที่ชนเข้ามาเป็นอาวุธของผู้เล่นหรือไม่
	if area.is_in_group("player_weapon"):
		# 💡 การแก้ไข: ดึงค่า 'damage' มาจากโหนด Area ของอาวุธโดยตรง
		# เราสมมติว่า Area นี้มีตัวแปร 'damage' อยู่ในโหนดแม่ของมัน
		
		# พยายามเข้าถึงโหนดแม่ของ Area3D ซึ่งก็คือโหนดอาวุธ (Node3D)
		var weapon_node = area.get_parent() 
		
		if weapon_node and weapon_node.has_property("damage"):
			# ถ้ามี property 'damage' ให้ใช้ค่านี้
			var damage_amount = weapon_node.damage 
			take_damage(damage_amount, hit_part)
			
		else:
			# ถ้าหาค่าดาเมจไม่ได้ ค่อยกลับไปใช้ค่า Default (ถ้ายังต้องการ)
			print("Error: Weapon does not have a 'damage' property!")
			# ถ้ายังไม่ลบ const PLAYER_WEAPON_DAMAGE = 100.0:
			# take_damage(PLAYER_WEAPON_DAMAGE, hit_part) 


# --- ฟังก์ชันรับดาเมจ (Damage Receiver) ---
func take_damage(damage: float, hit_part: String):
	if is_dead:
		return

	if hit_part == "Head":
		# Headshot: โดนทีเดียวตาย
		health = 0.0
		print("HEADSHOT! Zombie took full damage (", damage, ") and died instantly.")
	elif hit_part == "Body":
		# Bodyshot: โดนตามจำนวนดาเมจปกติ
		health -= damage
		print("Body hit. Zombie took:", damage, " damage. Health remaining:", health)
	else:
		# กรณีทั่วไป
		health -= damage
		print("Generic hit. Zombie took:", damage, " damage. Health remaining:", health)

	# ตรวจสอบการตาย
	if health <= 0 and not is_dead:
		_die()

# --- ฟังก์ชันจัดการการตาย ---
func _die():
	is_dead = true
	# หยุดการทำงานของ Physics Process ทันที
	set_physics_process(false)
	velocity = Vector3.ZERO
	
	# เล่นแอนิเมชันตาย
	if anim.has_animation(ANIM_DEATH):
		_play_animation_safe(ANIM_DEATH)
		# ใช้ await เพื่อรอให้แอนิเมชันจบก่อนลบ
		if is_instance_valid(anim): # เช็คป้องกันการเกิดข้อผิดพลาด
			await anim.animation_finished
	
	# ลบตัวละครซอมบี้ออกจากฉาก
	queue_free()


# --------------------------------------------------------------------------------
## AI และการเคลื่อนที่ (AI & Movement)
# --------------------------------------------------------------------------------

# --- ตรวจจับผู้เล่น ---
func _on_body_entered(body):
	if body.is_in_group("player"):
		if not players.has(body):
			players.append(body)
			print("Zombie detected player:", body.name)

			if not is_screaming and not is_attacking and players.size() == 1 and anim.has_animation(ANIM_SCREAM):
				_do_scream()


func _on_body_exited(body):
	if players.has(body):
		players.erase(body)
		print("Player left detection:", body.name)


# --- ฟังก์ชันตะโกนก่อนโจมตี ---
func _do_scream():
	is_screaming = true

	if players.size() > 0:
		look_at(players[0].global_transform.origin, Vector3.UP, true)

	_play_animation_safe(ANIM_SCREAM)

	await anim.animation_finished
	is_screaming = false


# --- ฟังก์ชันโจมตี ---
func _do_attack():
	is_attacking = true
	_play_animation_safe(ANIM_ATTACK)

	var attack_time = 1.0
	if anim.has_animation(ANIM_ATTACK):
		attack_time = anim.get_animation(ANIM_ATTACK).length

	# รอครึ่งหนึ่งของแอนิเมชันก่อนทำดาเมจ
	await get_tree().create_timer(attack_time * 0.5).timeout
	_deal_damage()

	# รอครึ่งหลังของแอนิเมชัน
	await get_tree().create_timer(attack_time * 0.5).timeout
	is_attacking = false


# --- ฟังก์ชันทำดาเมจ (ซอมบี้โจมตีผู้เล่น) ---
func _deal_damage():
	for p in players:
		var dist = global_transform.origin.distance_to(p.global_transform.origin)

		if dist <= ATTACK_RANGE:
			if p.has_method("take_damage"):
				print("ZOMBIE ATTACKED:", p.name, "for", ATTACK_DAMAGE, "damage.")
				p.take_damage(ATTACK_DAMAGE)
			else:
				print("Player node", p.name, "is missing 'take_damage' function.")


# --- การอัปเดตในทุกเฟรม ---
func _physics_process(delta):
	# ตรวจสอบสถานะตายก่อน
	if is_dead:
		return
		
	# หยุดถ้ากำลังตะโกนหรือโจมตี
	if is_screaming or is_attacking:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# ไม่มีผู้เล่น -> Idle
	if players.size() == 0:
		velocity = Vector3.ZERO
		move_and_slide()
		_play_animation_safe(ANIM_IDLE)
		return

	# มีผู้เล่น -> หาเป้าหมายที่ใกล้ที่สุด
	var nearest = players[0]
	var nearest_dist = global_transform.origin.distance_to(nearest.global_transform.origin)

	for p in players:
		var d = global_transform.origin.distance_to(p.global_transform.origin)
		if d < nearest_dist:
			nearest = p
			nearest_dist = d

	# หันหน้าไปหาเป้าหมาย
	look_at(nearest.global_transform.origin, Vector3.UP, true)

	# ตรวจสอบระยะโจมตี
	if nearest_dist <= ATTACK_RANGE:
		velocity = Vector3.ZERO
		move_and_slide()

		if not is_attacking and anim.has_animation(ANIM_ATTACK):
			_do_attack()
	else:
		# เดินไล่เป้าหมาย
		var dir = (nearest.global_transform.origin - global_transform.origin).normalized()
		velocity = dir * speed
		move_and_slide()

		_play_animation_safe(ANIM_WALK)


# --- ฟังก์ชันป้องกันการเล่นแอนิเมชันซ้ำ ---
func _play_animation_safe(animation_name: String):
	if anim and anim.has_animation(animation_name):
		if anim.current_animation != animation_name:
			anim.play(animation_name)
