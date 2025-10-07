extends Node3D

@export var heal_amount: float = 20.0
#@export var pickup_sound: AudioStreamPlayer3D

func _ready():
	if has_node("Area3D"):
		$Area3D.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("heal"):
			body.heal(heal_amount)
			print("💊 Player healed +", heal_amount)
		
		# เล่นเสียงถ้ามี
		#if is_instance_valid(pickup_sound):
			#pickup_sound.play()
		#
		# รอเสียงจบก่อนลบ (ถ้ามี)
		#await get_tree().create_timer(0.5).timeout
		#queue_free()
