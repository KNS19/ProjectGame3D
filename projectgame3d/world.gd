extends Node3D

@export var NormalZom1: PackedScene
@export var NormalZom2: PackedScene
@export var BossZom: PackedScene

# ตัวแปรตั้งต้น
var initial_wait_time := 5.0      # เริ่ม spawn ทุก 15 วิ
var decrease_interval := 10.0      # ทุก 10 วิ ลดความถี่
var decrease_amount := 0.2         # ลดลงทีละ 0.2 วิ
var min_wait_time := 2.0           # ต่ำสุดคือ 2 วิ

var boss_interval := 15.0          # Boss จะเกิดทุก 10 วิ
var boss_count := 1                # เริ่มต้นเกิดทีละ 1 ตัว
var boss_increase := 1             # ทุกครั้งจะเพิ่มขึ้น 1 ตัว

func _ready():
	randomize()

	# ---- Normal Zombie Timer ----
	$MobTimer.wait_time = initial_wait_time
	$MobTimer.start()
	
	# ---- Timer สำหรับลดความถี่ spawn ----
	var adjust_timer = Timer.new()
	adjust_timer.wait_time = decrease_interval
	adjust_timer.autostart = true
	adjust_timer.timeout.connect(_on_adjust_timer_timeout)
	add_child(adjust_timer)

	# ---- Timer สำหรับ Boss Zombie ----
	var boss_timer = Timer.new()
	boss_timer.wait_time = boss_interval
	boss_timer.autostart = true
	boss_timer.timeout.connect(_on_boss_timer_timeout)
	add_child(boss_timer)


# -----------------------
# Normal Zombie
# -----------------------
func _on_mob_timer_timeout():
	spawn_zombie()

func spawn_zombie():
	var zombie_types = [NormalZom1, NormalZom2]
	var zombie_scene = zombie_types[randi() % zombie_types.size()]
	if zombie_scene == null:
		return

	var mob = zombie_scene.instantiate()
	var spawn_points = [
		$SpawnPath/Marker3D,
		$SpawnPath/Marker3D2,
		$SpawnPath/Marker3D3,
		$SpawnPath/Marker3D4
	]
	var spawn_point = spawn_points[randi() % spawn_points.size()]

	add_child(mob)
	mob.call_deferred("set_global_position", spawn_point.global_position)


# -----------------------
# Boss Zombie
# -----------------------
func _on_boss_timer_timeout():
	for i in range(boss_count):
		var boss = BossZom.instantiate()
		var spawn_points = [
			$SpawnPath/Marker3D,
			$SpawnPath/Marker3D2,
			$SpawnPath/Marker3D3,
			$SpawnPath/Marker3D4
		]
		var spawn_point = spawn_points[randi() % spawn_points.size()]
		add_child(boss)
		boss.call_deferred("set_global_position", spawn_point.global_position)
	
	print("💀 Boss Zombies spawned:", boss_count)
	boss_count += boss_increase


# -----------------------
# ปรับเวลา Spawn เร็วขึ้นเรื่อย ๆ
# -----------------------
func _on_adjust_timer_timeout():
	$MobTimer.wait_time = max(min_wait_time, $MobTimer.wait_time - decrease_amount)
	print("🕒 Normal spawn rate:", $MobTimer.wait_time, " sec | Boss per wave:", boss_count)
