extends Node3D

@export var damage: int = 30
@onready var area: Area3D = $Area3D

var _is_swinging: bool = false
var _already_hit: Array = []

func _ready():
	add_to_group("player_weapon")
	area.monitoring = false
	area.body_entered.connect(_on_body_entered)

func swing():
	if _is_swinging: 
		return
	_is_swinging = true
	_already_hit.clear()
	
		# ✅ เล่นเสียงฟัน
	if has_node("SlashSfx"):
		$SlashSfx.play()

	# เปิด hitbox ชั่วคราว 0.25 วิ
	area.monitoring = true
	await get_tree().create_timer(1.0).timeout
	area.monitoring = false

	_is_swinging = false

func _on_body_entered(body: Node):
	if body in _already_hit:
		return
	_already_hit.append(body)

	if body.has_method("take_damage"):
		body.take_damage(damage, "Body") 
		print("Hit", body.name, "for", damage)
