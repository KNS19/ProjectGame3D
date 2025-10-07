# WeaponUI.gd
extends Control

@onready var slot_sword: TextureRect = $MarginContainer/HBoxContainer/Slot_Sword
@onready var slot_gun:   TextureRect = $MarginContainer/HBoxContainer/Slot_Gun
@onready var slot_medic: TextureRect = $MarginContainer/HBoxContainer/Slot_Medic

var active_color   := Color(1, 1, 1, 1)     # สว่าง
var inactive_color := Color(1, 1, 1, 0.35)  # ซีดลง

func update_slots(has_sword: bool, has_gun: bool, has_medic: bool) -> void:
	if is_instance_valid(slot_sword):
		slot_sword.modulate = (active_color if has_sword else inactive_color)
	if is_instance_valid(slot_gun):
		slot_gun.modulate   = (active_color if has_gun else inactive_color)
	if is_instance_valid(slot_medic):
		slot_medic.modulate = (active_color if has_medic else inactive_color)
