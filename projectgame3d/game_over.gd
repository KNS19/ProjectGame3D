extends Control

# -----------------------------
# 🎯 ตัวแปร UI ที่เชื่อมกับ Label และปุ่มใน Scene
# -----------------------------
@onready var score_label: Label = $ScoreLabel
@onready var time_label: Label = $TimeLabel
@onready var play_again_button: Button = $PlayAgainButton
@onready var quit_button: Button = $QuitButton

func _ready():
	# 1️⃣ หยุดการจับเวลาใน GameManager
	GameManager.timer_active = false
	
	# 2️⃣ แสดงคะแนนรวม
	if is_instance_valid(score_label):
		score_label.text = "Score: %d" % GameManager.total_score
	
	# 3️⃣ คำนวณและแสดงเวลา
	var total_seconds = GameManager.total_time
	var minutes = int(total_seconds) / 60
	var seconds = int(total_seconds) % 60
	if is_instance_valid(time_label):
		time_label.text = "Time Survived: %02d:%02d" % [minutes, seconds]
	
	# 4️⃣ เปิดเมาส์ให้คลิกปุ่มได้
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	

# -----------------------------
# 🔁 ปุ่ม "เล่นอีกครั้ง"
# -----------------------------
func _on_play_again_button_pressed():
	GameManager.reset_game_data()
	get_tree().change_scene_to_file("res://world.tscn")


# -----------------------------
# 🚪 ปุ่ม "ออกเกม"
# -----------------------------
func _on_quit_button_pressed():
	get_tree().quit()
