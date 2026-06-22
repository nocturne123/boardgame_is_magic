extends Control

## 可拖拽的 UI 分割条，用于调整相邻面板的尺寸。
## 插入到 Container 子节点之间，拖拽时修改目标节点的 custom_minimum_size。
##
## orientation = 0 (VERTICAL):   水平条，上下拖拽（用于 VBoxContainer 中）
## orientation = 1 (HORIZONTAL): 垂直条，左右拖拽（用于 HBoxContainer 中）
##
## target_path: 被控制的相邻节点路径（相对于本节点）
## target_is_before: 目标在分割条上方/左方=true，下方/右方=false

const VERTICAL := 0
const HORIZONTAL := 1

@export_enum("VERTICAL", "HORIZONTAL") var orientation: int = VERTICAL
@export var target_path: NodePath = NodePath("")
@export var target_is_before: bool = true

const GRAB_SIZE := 8.0
const MIN_TARGET_SIZE := 30.0

var _target: Control = null
var _dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_size: Vector2 = Vector2.ZERO
var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	match orientation:
		VERTICAL:
			custom_minimum_size = Vector2(0, GRAB_SIZE)
			mouse_default_cursor_shape = Control.CURSOR_VSIZE
		HORIZONTAL:
			custom_minimum_size = Vector2(GRAB_SIZE, 0)
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
	if not target_path.is_empty():
		_target = get_node(target_path) as Control
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_start_mouse = get_global_mouse_position()
				if _target:
					_drag_start_size = _target.custom_minimum_size
			else:
				_dragging = false
			queue_redraw()
	elif event is InputEventMouseMotion and _dragging and _target:
		var delta: Vector2 = get_global_mouse_position() - _drag_start_mouse
		match orientation:
			VERTICAL:
				var d: float = delta.y if target_is_before else -delta.y
				var new_h: float = max(MIN_TARGET_SIZE, _drag_start_size.y + d)
				_target.custom_minimum_size = Vector2(_target.custom_minimum_size.x, new_h)
			HORIZONTAL:
				var d: float = delta.x if target_is_before else -delta.x
				var new_w: float = max(MIN_TARGET_SIZE, _drag_start_size.x + d)
				_target.custom_minimum_size = Vector2(new_w, _target.custom_minimum_size.y)
		queue_redraw()


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	if not _dragging:
		queue_redraw()


func _draw() -> void:
	var color: Color = Color(0.35, 0.32, 0.28, 0.5)
	if _dragging:
		color = Color(0.75, 0.7, 0.5, 0.9)
	elif _hovered:
		color = Color(0.5, 0.46, 0.38, 0.7)

	match orientation:
		VERTICAL:
			var y: float = size.y / 2.0
			draw_line(Vector2(4, y), Vector2(size.x - 4, y), color, 2.0)
			var grip_w: float = 30.0
			draw_rect(Rect2(size.x / 2 - grip_w / 2, y - 1.5, grip_w, 3.0), color, true)
		HORIZONTAL:
			var x: float = size.x / 2.0
			draw_line(Vector2(x, 4), Vector2(x, size.y - 4), color, 2.0)
			var grip_h: float = 30.0
			draw_rect(Rect2(x - 1.5, size.y / 2 - grip_h / 2, 3.0, grip_h), color, true)
