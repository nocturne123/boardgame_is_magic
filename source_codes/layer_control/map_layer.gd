class_name MapLayer extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready():
	scale = Vector2(2,2)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _input(event):
	if event is InputEventMouse:
		if event.is_pressed():
			if event.get_button_index() == 5:
				scale *= 0.9
			elif event.get_button_index() == 4:
				scale *= 1.1
			elif event.get_button_index() == 3:
				scale = Vector2(2,2)
			
			#点击地图时，打印出地图的对应坐标
			#var global_clicked = event.position
			var global_pos = event.position
			var local_pos = get_offset()
			#print("全局鼠标坐标:{0}".format([global_pos]))
			#print("本地坐标:{0}".format([local_pos]))
			
			var global_trans = get_final_transform()
			print(event.position)
			print(global_trans*event.position)
			
			
			
			#这个是打印鼠标
			#print(event.get_button_index())
