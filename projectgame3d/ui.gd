extends CanvasLayer

@onready var timer_label: Label = $TimerLabel
@onready var score_label: Label = $ScoreLabel
@onready var timer: Timer = $Timer

var seconds_passed: int = 0
var kill_score: int = 0

func _ready():
	timer.timeout.connect(_on_timer_timeout)
	score_label.text = "Score: " + str(kill_score)
	timer.start()
	GameManager.reset_game_data()  # รีเซ็ตข้อมูลใหม่
	GameManager.timer_active = true  # เริ่มจับเวลา

func _on_timer_timeout():
	seconds_passed += 1
	timer_label.text = format_time(seconds_passed)
	GameManager.total_time = seconds_passed  # อัปเดตเวลาไปยัง GameManager

func format_time(total_seconds: int) -> String:
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return str(minutes).pad_zeros(2) + ":" + str(seconds).pad_zeros(2)

func add_kill_score(points: int = 1):
	kill_score += points
	score_label.text = "Score: " + str(kill_score)
	GameManager.add_coin(points)  # อัปเดตคะแนนไปยัง GameManager

# 💀 เรียกตอนเกมจบ
func game_over():
	GameManager.timer_active = false
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
