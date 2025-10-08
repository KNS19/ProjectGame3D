extends Node3D

@onready var bgm = $AudioStreamPlayer

func _ready():
	bgm.play()
