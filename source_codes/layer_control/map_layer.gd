class_name MapLayer extends CanvasLayer

func _ready():
    #scale = Vector2(2,2)
    pass

func _process(_delta):
    pass

func _unhandled_input(event):
    if event is InputEventMouseButton and event.pressed:
        #基于鼠标位置的缩放
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            offset = (offset - event.position)*0.9 + event.position
            scale *= 0.9
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
            offset = (offset - event.position)*1.1 + event.position
            scale *= 1.1
        elif event.button_index == MOUSE_BUTTON_MIDDLE and event.double_click:
            #双击鼠标中键时，缩放调至1，将鼠标点击处设置为视口中心
            var local_pos = (event.position - offset)/scale
            var tween = get_tree().create_tween().bind_node(self).set_trans(Tween.TRANS_ELASTIC)
            tween.tween_property($".", "offset", Vector2(640,360) - local_pos, 0.5)
            tween.parallel().tween_property($".", "scale", Vector2(1,1), 0.5)
    #if event is InputEventKey:
        #if event.pressed:
            #if event.keycode == KEY_E:
                #rotation += 0.1
            #if event.keycode == KEY_Q:
                #rotation -= 0.1
