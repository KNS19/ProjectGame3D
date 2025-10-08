extends CanvasLayer

@onready var timer_label: Label = $TimerLabel
@onready var score_label: Label = $ScoreLabel # ต้องตั้งชื่อ Label ใน Scene ให้เป็น ScoreLabel ด้วย
@onready var timer: Timer = $Timer

var seconds_passed: int = 0
var kill_score: int = 0 # ตัวแปรสกอร์

func _ready():
	timer.timeout.connect(_on_timer_timeout)
	score_label.text = "Score: " + str(kill_score) # แสดงสกอร์เริ่มต้น

func _on_timer_timeout():
	seconds_passed += 1
	timer_label.text = format_time(seconds_passed)

func format_time(total_seconds: int) -> String:
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2)

# ฟังก์ชันสาธารณะสำหรับเพิ่มสกอร์
func add_kill_score(points: int = 1):
	kill_score += points
	score_label.text = "Score: " + str(kill_score) # อัปเดต Label สกอร์
