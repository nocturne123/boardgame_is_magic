class_name MapLayer extends CanvasLayer

func _ready():
	scale = Vector2(2,2)

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
			
			var global_trans = get_final_transform()
			print(event.position)
			print(global_trans*event.position)
			
	#下面是利用Q、E控制地图的旋转，考虑到2d游戏旋转起来效果很差，暂时不需要这种操作
	#if event is InputEventKey:
		#if event.pressed:
			#if event.keycode == KEY_E:
				#rotation += 0.1
			#if event.keycode == KEY_Q:
				#rotation -= 0.1
