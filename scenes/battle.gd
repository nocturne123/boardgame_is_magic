extends Node2D
#这个脚本模仿example2里面的主脚本来写

@onready var card_pile_ui = $card_layer/CardPileUI
@onready var targeting_line_2d = $TargetingLine2D
@onready var panel_container = $card_layer/PanelContainer
@onready var rich_text_label = $card_layer/PanelContainer/RichTextLabel

@onready var maud_pie = $player_layer/Player
@onready var map_layer = $map_layer
@onready var map = $map_layer/default_world_map

var current_hovered_card : CardUI
func _ready():
	
	#卡牌统的初始化
	card_pile_ui.draw(5)
	card_pile_ui.connect("card_hovered", func(card_ui):
		rich_text_label.text = card_ui.card_data.format_description()
		panel_container.visible = true
		current_hovered_card = card_ui
	)
	card_pile_ui.connect("card_unhovered", func(_card_ui):
		panel_container.visible = false
		current_hovered_card = null
	)
	card_pile_ui.connect("card_clicked", func(card_ui):
		targeting_line_2d.set_point_position(0, card_ui.position + card_ui.size * 0.5)
		targeting_line_2d.visible = true
	)
	card_pile_ui.connect("card_dropped", func(_card_ui):
		targeting_line_2d.visible = false
	)
	
	#玩家位置的初始化
	#这里transform2d和vector的顺序很重要，详见官方矩阵教程
	#利用map_layer的transform2d乘算灰琪的地图内坐标，得到全局内的位置坐标，后期玩家图层有缩放的话这里要重写
	maud_pie.position = map_layer.get_final_transform()*map.map_to_local(maud_pie.map_position)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if current_hovered_card:
		var target_pos = current_hovered_card.position
		target_pos.y += 80
		target_pos.x += 180
		panel_container.position = target_pos + Vector2(-300,-200)
		#print(target_pos)
		targeting_line_2d.set_point_position(1, get_global_mouse_position())
