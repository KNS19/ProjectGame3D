extends Control

# กำหนดเส้นทางไปยัง Scene เล่นเกม (เปลี่ยนชื่อ player.tscn เป็นชื่อ Scene เลเวลของคุณ)
const GAME_SCENE_PATH = "res://world.tscn"

func _ready():
	# 1. รีเซ็ตข้อมูลเกมเมื่อเข้าหน้าเริ่มต้น
	GameManager.reset_game_data()
	# 2. แสดงเมาส์ (ถ้าจำเป็น)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_button_pressed():
	# 1. เริ่มจับเวลา
	GameManager.timer_active = true
	# 2. โหลด Scene เล่นเกม
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
