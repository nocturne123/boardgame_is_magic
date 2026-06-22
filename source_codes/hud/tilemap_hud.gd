class_name TilemapHUD
extends Node2D

## 在 TileMapLayer 上叠加彩色六边形内描边，区分地图格状态。
## - 默认格子：白色内描边
## - 当前玩家所在格：绿色内描边
## - 敌对角色所在格：红色内描边
## - 友方角色所在格：浅绿色内描边
##
## 使用 flat-top 六边形（匹配 tileset 的 TILE_OFFSET_AXIS_HORIZONTAL 配置）。

const COLORS := {
    default = Color(0.9, 0.9, 0.9, 1.0),
    current = Color(0.2, 1.0, 0.3, 1.0),
    enemy = Color(1.0, 0.15, 0.15, 1.0),
    friendly = Color(0.4, 1.0, 0.5, 1.0),
    move_range = Color(0.25, 0.45, 1.0, 0.85),
    terrain_forest = Color(0.15, 0.5, 0.2, 0.35),
    terrain_snow = Color(0.7, 0.8, 0.95, 0.35),
}

## 地形格子: {Vector2i: String}  cell → "forest" / "snow"
var _terrain_cells: Dictionary = {}

var _map_node: TileMapLayer = null

var _current_cell: Vector2i = Vector2i(-1_000_000, -1_000_000)
var _current_team: int = -1
var _player_cells: Dictionary = {}  # {Vector2i: int}  cell -> team_id
var _move_range_cells: Array[Vector2i] = []

var _hex_outer: PackedVector2Array
var _hex_inner: PackedVector2Array

func setup(map: TileMapLayer) -> void:
    _map_node = map
    position = map.position
    scale = map.scale
    z_index = 1  # 低于玩家的 10

    var ts := map.tile_set
    if ts:
        _calc_hex_vertices(ts.tile_size)
    queue_redraw()

func _calc_hex_vertices(tile_size: Vector2i) -> void:
    # flat-top 六边形：左右是尖角，上下是平边
    var w: float = tile_size.x * 0.5
    var h: float = tile_size.y * 0.5

    _hex_outer = PackedVector2Array([
        Vector2(w, 0),          # 右尖
        Vector2(w * 0.5, h),    # 右下
        Vector2(-w * 0.5, h),   # 左下
        Vector2(-w, 0),         # 左尖
        Vector2(-w * 0.5, -h),  # 左上
        Vector2(w * 0.5, -h),   # 右上
        Vector2(w, 0),          # 闭合
    ])

    _hex_inner = PackedVector2Array()
    for v in _hex_outer:
        _hex_inner.append(v * 0.8)

## 设置当前玩家所在格子及其队伍
func set_current_player(cell: Vector2i, team: int = -1) -> void:
    _current_cell = cell
    _current_team = team
    queue_redraw()

## 批量设置各队伍的玩家占位。传入 {Vector2i: team_id}
func set_player_cells(data: Dictionary) -> void:
    _player_cells = data
    queue_redraw()


## 设置移动范围（蓝色高亮格子），传入空数组清除。
func set_move_range(cells: Array[Vector2i]) -> void:
    _move_range_cells = cells
    queue_redraw()

## 设置地形格子 {Vector2i: terrain_type_string}
func set_terrain_cells(data: Dictionary) -> void:
    _terrain_cells = data
    queue_redraw()

func _get_cell_color(cell: Vector2i) -> Color:
    if cell == _current_cell:
        return COLORS.current

    if _player_cells.has(cell):
        var team: int = _player_cells[cell]
        if _current_team >= 0 and team != _current_team:
            return COLORS.enemy
        elif _current_team >= 0 and team == _current_team:
            return COLORS.friendly
        else:
            return COLORS.enemy

    return COLORS.default

func _draw() -> void:
    if _map_node == null:
        return

    var used_cells: Array[Vector2i] = _map_node.get_used_cells()

    var special_set := {}
    special_set[_current_cell] = true
    for cell in _player_cells.keys():
        special_set[cell] = true

    # 先画移动范围（蓝色半透明填充 + 描边）
    var move_set := {}
    for cell in _move_range_cells:
        move_set[cell] = true

    for cell in used_cells:
        # 先画地形填充
        if _terrain_cells.has(cell):
            var tcolor: Color = COLORS.terrain_forest
            match _terrain_cells[cell]:
                "snow": tcolor = COLORS.terrain_snow
            _draw_hex_fill(cell, tcolor)
        if move_set.has(cell):
            _draw_hex_fill(cell, COLORS.move_range)
        var color := _get_cell_color(cell)
        _draw_hex_border(cell, color, special_set.has(cell))

func _draw_hex_fill(cell: Vector2i, color: Color) -> void:
    var center := _map_node.map_to_local(cell)
    var pts := PackedVector2Array()
    for v in _hex_outer:
        pts.append(center + v)
    draw_colored_polygon(pts, color)

func _draw_hex_border(cell: Vector2i, color: Color, special: bool) -> void:
    var center := _map_node.map_to_local(cell)
    var src := _hex_inner if special else _hex_outer
    var wv := PackedVector2Array()
    for v in src:
        wv.append(center + v)
    var lw: float = 2.0 if special else 1.0
    draw_polyline(wv, color, lw, true)
