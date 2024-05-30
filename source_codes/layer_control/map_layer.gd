class_name MapLayer extends CanvasLayer

func _ready():
	#scale = Vector2(2,2)
	pass

func _process(delta):
	pass

func _input(event):
	if event is InputEventMouse:
		if event.is_pressed():
			
			if event.get_button_index() == 5:
				scale *= 0.9
			elif event.get_button_index() == 4:
				scale *= 1.1
				print(transform)
			elif event.get_button_index() == 3:
				#按下鼠标中键时，缩放调至1，将鼠标点击处设置为视口中心
				#现在能解决不带缩放的canvas
				#TODO:解决带缩放的canvas
				offset -= event.position*scale - Vector2(640,360)*scale
				scale = Vector2(1,1)
				print(offset)
			
	#下面是利用Q、E控制地图的旋转，考虑到2d游戏旋转起来效果很差，暂时不需要这种操作
	#if event is InputEventKey:
		#if event.pressed:
			#if event.keycode == KEY_E:
				#rotation += 0.1
			#if event.keycode == KEY_Q:
				#rotation -= 0.1
