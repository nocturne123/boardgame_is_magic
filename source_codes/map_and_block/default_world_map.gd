extends TileMap

@onready var map_camera = $map_camera


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _input(event):
	if event is InputEventMouse:
		if event.is_pressed():
			var global_clicked = event.position
			var camera_pos = map_camera.get_local_mouse_position()
			var mapped_position = local_to_map(camera_pos)
			print(mapped_position)
