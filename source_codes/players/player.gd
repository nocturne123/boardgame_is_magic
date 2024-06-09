class_name Player extends Sprite2D

enum Species {EarthPony, Unicorn, Pegasi, Alicon, others}
enum PlayerState {Wait, Draw, Play, Discard}
enum LivingState {Alive,Fainted,Dead}

signal hand_pile_updated
#due to the seperate of hand pile and draw,discard pile
#now func like _maybe_remove and set_card_pile
#will conmunicate by signal
signal _maybe_remove_from_hand_pile
signal remove_from_any_dropzone

@export_group("基础属性")
@export var player_name:String
#生命值、最大生命值、初始生命值
@export var health:int
@export var max_health:int
@export var base_health:int
@export var speed:int
@export var species:Species
@export var living_state:LivingState = LivingState.Alive
@export var turn_stage = PlayerState.Wait
@export var map_position:Vector2i
#玩家的回合计数和轮次计数
@export var turn_count:int = 0
@export var round_count:int = 0

@export_group("额外属性")
@export var physical_defence:int
@export var magic_defence:int
@export	var mental_defence:int
#可以被卡牌指定，比如攻击牌、偷牌
@export var is_selectable:bool = true
@export var immune_from_attack:bool = false
@export var immune_from_steal:bool = false
#角色在回合开始时的抽牌
@export var draw_stage_card_number:int = 2
#角色初始手牌数量
@export var start_game_draw:int = 4
#角色最大手牌数量
@export var max_hand_sequence_num = 6
#玩家的移动次数和攻击次数，在回合开始时用这个属性进行初始化
@export var move_chance:int = 1
@export var attack_chance:int = 1
#玩家在回合中的移动和攻击次数，回合开始时从上面的属性初始化得到
@export var move_chance_in_turn:int = 0
@export var attack_chance_in_turn:int = 0
#玩家在上一轮的生命值，记录给沙漏使用
@export var health_last_turn:int = max_health

@export_group("hand_pile_setting")
@export var hand_pile_position = Vector2(640, 480)
@export var hand_enabled := true
@export var hand_face_up := true
@export var max_hand_size := 10 # if any more cards are added to the hand, they are immediately discarded
@export var max_hand_spread := 400
@export var card_ui_hover_distance := 60
@export var drag_when_clicked := true

## This works best as a 2-point linear rise from -X to +X
@export var hand_rotation_curve : Curve
## This works best as a 3-point ease in/out from 0 to X to 0
@export var hand_vertical_curve : Curve

#手牌
var _hand_pile := []

#copyed from card_pile_ui
#TODO:add chinese
func _set_hand_pile_target_positions():
	for i in _hand_pile.size():
		var card_ui = _hand_pile[i]
		card_ui.move_to_front()
		var hand_ratio = 0.5
		if _hand_pile.size() > 1:
			hand_ratio = float(i) / float(_hand_pile.size() - 1)
		var target_pos = hand_pile_position
		var card_spacing = max_hand_spread / (_hand_pile.size() + 1)
		target_pos.x += (i + 1) * card_spacing - max_hand_spread / 2.0
		if hand_vertical_curve:
			target_pos.y -= hand_vertical_curve.sample(hand_ratio)
		if hand_rotation_curve:
			card_ui.rotation = deg_to_rad(hand_rotation_curve.sample(hand_ratio))
		if hand_face_up:
			card_ui.set_direction(Vector2.UP)
		else:
			card_ui.set_direction(Vector2.DOWN)
		card_ui.target_position = target_pos
		#TODO:rewrite discard logic
		#now just leave it there
	#while _hand_pile.size() > max_hand_size:
	#	set_card_pile(_hand_pile[_hand_pile.size() - 1], Piles.discard_pile)
	_reset_hand_pile_z_index()

#copyed from card_pile_ui.gd
#TODO:add chinese	
func _reset_hand_pile_z_index():
	for i in _hand_pile.size():
		var card_ui = _hand_pile[i]
		card_ui.z_index = 1000 + i
		card_ui.move_to_front()
		if card_ui.mouse_is_hovering:
			card_ui.z_index = 2000 + i
		if card_ui.is_clicked:
			card_ui.z_index = 3000 + i
	
#copyed from card_pile_ui.gd
#TODO:add chinese
func _maybe_remove_card_from_hand_piles(card : CardUI):
	if _hand_pile.find(card) != -1:
		_hand_pile.erase(card)
		emit_signal("hand_pile_updated")
		emit_signal("_maybe_remove_card_from_hand_piles",card)
		
func set_card_pile(card : CardUI):
	_maybe_remove_card_from_hand_piles(card)
	_maybe_remove_card_from_any_dropzones(card)
	
	_hand_pile.push_back(card)
	emit_signal("hand_pile_updated")
	_set_hand_pile_target_positions()
	
#due to all dropzone is managed by battle,
#hand pile will only emit a signal
#to let battle node do it's job
func _maybe_remove_card_from_any_dropzones(card:CardUI):
	emit_signal("remove_from_any_dropzone",card)
