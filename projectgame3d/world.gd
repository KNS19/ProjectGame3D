extends Node3D

@onready var sun: DirectionalLight3D = $WorldEnvironment/DirectionalLight3D
@onready var world_env: Environment = $WorldEnvironment.environment

var time_of_day: float = 0.25
var day_speed: float = 0.005
var sun_max_energy: float = 3.0
var moon_light: DirectionalLight3D

func _ready():
	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.5, 0.6, 1.0)
	moon_light.light_energy = 0.0
	moon_light.shadow_enabled = true
	add_child(moon_light)
	moon_light.rotation_degrees = Vector3(-30, 0, 0)

func _process(delta):
	time_of_day += delta * day_speed
	if time_of_day > 1.0:
		time_of_day -= 1.0

	var sun_angle = time_of_day * 360.0 - 90.0
	sun.rotation_degrees.x = sun_angle
	moon_light.rotation_degrees.x = sun_angle + 180.0

	var sun_intensity = clamp(cos(deg_to_rad(sun_angle)), 0.0, 1.0)
	var moon_intensity = clamp(cos(deg_to_rad(sun_angle + 180.0)), 0.0, 1.0)

	sun.light_energy = sun_intensity * sun_max_energy
	moon_light.light_energy = moon_intensity * 0.6

	var dawn_color = Color(1.0, 0.6, 0.3)
	var day_color = Color(0.7, 0.85, 1.0)
	var dusk_color = Color(1.0, 0.5, 0.2)
	var night_color = Color(0.05, 0.05, 0.1)

	var sky_color: Color
	if time_of_day < 0.25:
		sky_color = night_color.lerp(dawn_color, time_of_day / 0.25)
	elif time_of_day < 0.5:
		sky_color = dawn_color.lerp(day_color, (time_of_day - 0.25) / 0.25)
	elif time_of_day < 0.75:
		sky_color = day_color.lerp(dusk_color, (time_of_day - 0.5) / 0.25)
	else:
		sky_color = dusk_color.lerp(night_color, (time_of_day - 0.75) / 0.25)

	# ---- เข้าถึง sky แบบ dynamic (ไม่อ้าง type ProceduralSky โดยตรง) ----
	var sky = null
	if world_env:
		sky = world_env.sky

	if sky and sky.get_class() == "ProceduralSky":
		# ใช้ตัวแปร dynamic (no :=) เพื่อหลีกเลี่ยงการ infer type
		var proc_sky = sky
		proc_sky.sky_top_color = sky_color
		proc_sky.sky_horizon_color = sky_color.darkened(0.3)
		proc_sky.ground_horizon_color = sky_color.darkened(0.6)
		proc_sky.ground_bottom_color = sky_color.darkened(0.8)

	# Fog / Ambient
# --- Fog (ปรับให้นุ่มขึ้น) ---
	world_env.fog_enabled = true
	world_env.fog_light_color = sky_color

	# ความหนาแน่นหมอกต่ำกว่าเดิม
	world_env.fog_density = lerp(0.0005, 0.01, 1.0 - sun_intensity)

	# ให้หมอกได้รับสีจากท้องฟ้าเล็กน้อย
	world_env.fog_sky_affect = 0.4
