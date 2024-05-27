extends Node2D
#这个脚本模仿example2里面的主脚本来写

@onready var card_pile_ui = $card_layer/CardPileUI
@onready var targeting_line_2d = $TargetingLine2D
@onready var panel_container = $card_layer/PanelContainer
@onready var rich_text_label = $card_layer/PanelContainer/RichTextLabel

@onready var maud_pie = $map_layer/Player
@onready var map_layer = $map_layer
@onready var map = $map_layer/default_world_map

var current_hovered_card : CardUI

#拖拽相关数据
var is_draging_player = false
var temporary_player_coord:Vector2i


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
	#利用map_layer的transform2d乘算灰琪的地图内坐标，得到map_layer内的位置坐标，后期玩家图层有缩放的话这里要重写
	maud_pie.position = map.to_global(map.map_to_local(maud_pie.map_position))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if current_hovered_card:
		var target_pos = current_hovered_card.position
		target_pos.y += 80
		target_pos.x += 180
		panel_container.position = target_pos + Vector2(-300,-200)
		#print(target_pos)
		targeting_line_2d.set_point_position(1, get_global_mouse_position())
		
#简单考虑后决定先把玩家的拖拽逻辑放在这里，先将玩家作为一个数据类看待
#因为拖拽涉及到地图的交互，在这里可以直接通过子节点访问到地图，省去了信号的沟通
func _input(event):
	
	#虽然使用了一层canvas_layer，但玩家还是会大量使用相对于map的坐标
	#get_local_mouse_position()，永远的神，这个项目会大量用到这个方法来解决局部坐标系内的问题
	#有了这个，其他的变换几乎不用考虑了
	var canvas_trans = maud_pie.get_global_transform()
	var map_trans_to_local = map.get_transform()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if maud_pie.get_rect().has_point(maud_pie.get_local_mouse_position()):
			is_draging_player = true
			print("drag set true")
			temporary_player_coord = maud_pie.map_position
			print(maud_pie.map_position)
		else :
			is_draging_player = false
			print("drag set false")
			
	if event is InputEventMouseMotion and is_draging_player:
		maud_pie.position = map.to_global(map.get_local_mouse_position())
		
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:		
		
		#核心逻辑
		#maud_pie.map_position = map.local_to_map(map.get_local_mouse_position())
		
		#当拖拽玩家时
		if is_draging_player:
			is_draging_player = false
			#移动后的地图坐标，用于检测图块是否存在
			var temp_map_pos = map.local_to_map(map.get_local_mouse_position())
			if map.get_cell_alternative_tile(0,temp_map_pos) == -1:
				maud_pie.map_position = temporary_player_coord
			else :
				maud_pie.map_position = map.local_to_map(map.get_local_mouse_position())
			
			maud_pie.position = map.to_global(map.map_to_local(maud_pie.map_position))
		else:
			is_draging_player = false
			
