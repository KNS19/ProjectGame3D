extends Node

# ตัวแปรสำหรับเก็บข้อมูลเกม
var total_score = 0
var total_time = 0.0 
var timer_active = false

# ฟังก์ชันสำหรับรีเซ็ตค่าเมื่อเริ่มเล่นใหม่
func reset_game_data():
	total_score = 0
	total_time = 0.0
	timer_active = false

# ฟังก์ชันสำหรับเพิ่มเหรียญ (เข้ากับโค้ด add_score() ของคุณ)
func add_coin(amount: int = 1):
	total_score += amount
	# สามารถเพิ่มสัญญาณ (Signal) เพื่ออัปเดต HUD ได้ที่นี่

# ฟังก์ชันที่ถูกเรียกทุกเฟรมเพื่อจับเวลา
func _process(delta):
	if timer_active:
		total_time += delta
