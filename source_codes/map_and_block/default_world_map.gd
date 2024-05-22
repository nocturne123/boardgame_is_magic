extends TileMap

@onready var map_camera = $map_camera




# Called when the node enters the scene tree for the first time.
func _ready():
	#设置地图的缩放
	#也可以在编辑器里做这一步
	#map_camera.zoom = Vector2(2,2)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _input(event):
	if event is InputEventMouse:
		if event.is_pressed():
			if event.get_button_index() == 5:
				map_camera.zoom *= 0.9
			elif event.get_button_index() == 4:
				map_camera.zoom *= 1.1
			elif event.get_button_index() == 3:
				map_camera.zoom = Vector2(0.3,0.3)
			
			#点击地图时，打印出地图的对应坐标
			#var global_clicked = event.position
			var camera_pos = map_camera.get_local_mouse_position()
			var mapped_position = local_to_map(camera_pos)
			print(mapped_position)
			print(camera_pos)
			print(event.get_button_index())
