extends Node3D
## ค่าพลังชีวิตสูงสุด
class_name DamageReceiver # ใช้ class_name เพื่อให้เรียกใช้ได้ง่ายขึ้น

## ค่าพลังชีวิตเริ่มต้น
@export var health: float = 50.0

## สัญญาณที่จะปล่อยออกมาเมื่อ Object นี้ถูกทำลาย
signal destroyed

func take_damage(damage: float, hit_part: String = "Body"):
	if health <= 0:
		return # ไม่รับดาเมจแล้ว ถ้าถูกทำลายแล้ว

	var final_damage = damage
	
	# ถ้าโดน Headshot ให้ตายทันที (หากต้องการ)
	if hit_part == "Head":
		final_damage = health # ดาเมจเท่ากับพลังชีวิตที่เหลือ
		print(owner.name, " HEADSHOT! Instant destruction.")

	health -= final_damage
	health = max(0.0, health) # ไม่ให้พลังชีวิตติดลบ

	print(owner.name, " took: ", final_damage, " damage. Health remaining: ", health)

	if health <= 0:
		_die()

func _die():
	if health <= 0:
		queue_free()
