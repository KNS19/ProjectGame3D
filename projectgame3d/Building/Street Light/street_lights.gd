extends Node3D

# --- เวลาและพลังงานไฟกระพริบ ---
var min_flicker_time := 0.05
var max_flicker_time := 0.2
var min_energy := 5.0    # ความสว่างต่ำสุด (ปรับค่านี้ได้ตามความเหมาะสมของฉาก)
var max_energy := 10.0   # ความสว่างสูงสุด (ปรับค่านี้ได้ตามความเหมาะสมของฉาก)

func _ready():
	# หาทุก SpotLight3D ในกลุ่ม "StreetLights"
	for node in get_tree().get_nodes_in_group("StreetLights"):
		if node is SpotLight3D:
			# เปิดไฟและเริ่มกระบวนการกระพริบ
			node.enabled = true
			flicker_light(node)
			print("Flicker started for:", node.name) # แสดงชื่อไฟที่เริ่มกระพริบ

# --- สร้าง Timer สำหรับกระพริบ ---
func flicker_light(light: SpotLight3D):
	# สร้าง Timer ใหม่สำหรับรอบการกระพริบนี้
	var t = Timer.new()
	# สุ่มเวลาก่อนจะเกิดการกระพริบครั้งต่อไป
	t.wait_time = randf_range(min_flicker_time, max_flicker_time)
	t.one_shot = true
	add_child(t)
	t.start()
	
	# เชื่อมสัญญาณ timeout ไปยังฟังก์ชัน _on_flicker_timeout 
	# พร้อมส่งโหนดไฟและ Timer ตัวนี้ไปด้วย
	t.timeout.connect(Callable(self, "_on_flicker_timeout").bind(light, t))

# --- เมื่อ Timer หมดเวลา (เกิดการกระพริบ) ---
func _on_flicker_timeout(light: SpotLight3D, t: Timer):
	# 1. สุ่มค่าพลังงาน (Energy) ให้กับไฟ
	light.energy = randf_range(min_energy, max_energy)
	
	# 2. เรียกตัวเองซ้ำเพื่อให้กระพริบต่อเนื่องไม่สิ้นสุด
	flicker_light(light)
	
	# 3. ลบ Timer ตัวเก่าที่หมดเวลาแล้วออกจากหน่วยความจำ
	t.queue_free()
