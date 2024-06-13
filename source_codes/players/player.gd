class_name Player extends Sprite2D

enum Species {EarthPony, Unicorn, Pegasi, Alicon, others}
enum PlayerState {Wait, Draw, Play, Discard}
enum LivingState {Alive,Fainted,Dead}

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
#玩家在上一轮的生命值，记录给沙漏使用，在回合结束时记录
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
