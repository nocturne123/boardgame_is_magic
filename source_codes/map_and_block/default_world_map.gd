extends TileMap


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
			var pos_clicked = local_to_map(to_local(global_clicked))
			print(pos_clicked)
