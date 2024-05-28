class_name Player extends Sprite2D

enum Species {EarthPony, Unicorn, Pegasi, Alicon, others}
enum PlayerState {Wait, Draw, Play, Discard}
enum LivingState {Alive,Fainted,Dead}

@export var player_name:String
@export var health:int
@export var speed:int
@export var species:Species
@export var living_state:LivingState = LivingState.Alive
@export var turn_stage = PlayerState.Wait
@export var map_position:Vector2i

# Called when the node enters the scene tree for the first time.
func _ready():
	#map_position = Vector2i(0,0)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func get_drag_data(position):
	pass



	
