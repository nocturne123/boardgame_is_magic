class_name EventDeck
extends Node

## 事件牌堆管理。独立于 CardManager，管理事件牌的抽取和弃置。
## 默认洗牌，抽空后自动洗弃牌堆。

signal event_pile_updated
signal event_discard_updated

@export_file("*.json") var event_database_path: String = ""

var _database: Array = []
var _event_pile: Array[Resource] = []
var _event_discard_pile: Array[Resource] = []

func _ready() -> void:
    if not event_database_path.is_empty():
        load_database(event_database_path)

func load_database(path: String) -> void:
    _database = _load_json_array(path)

func reset() -> void:
    _event_pile.clear()
    _event_discard_pile.clear()
    for entry in _database:
        var card = _create_event_card(entry)
        if card:
            _event_pile.append(card)
    _event_pile.shuffle()
    event_pile_updated.emit()
    event_discard_updated.emit()

## 从事件牌堆抽一张事件牌（随机）。抽空时自动洗弃牌堆。
func draw_event() -> Resource:
    if _event_pile.is_empty() and not _event_discard_pile.is_empty():
        _shuffle_discard_into_pile()
    if _event_pile.is_empty():
        return null
    var card = _event_pile.pop_back()
    event_pile_updated.emit()
    return card

## 将事件牌（或事件手牌）放入事件弃牌堆。
func discard_event(card: Resource) -> void:
    if card == null:
        return
    _event_discard_pile.append(card)
    event_discard_updated.emit()

## 按 event_id 从数据库创建一张新事件牌实例（不经过牌堆）。
func create_event_by_id(id: String) -> Resource:
    for entry in _database:
        if entry.get("event_id") == id:
            return _create_event_card(entry)
    push_warning("EventDeck: 事件 '%s' 未找到" % id)
    return null

func get_pile_size() -> int:
    return _event_pile.size()

func get_discard_size() -> int:
    return _event_discard_pile.size()

# ---- 内部辅助 ----

func _shuffle_discard_into_pile() -> void:
    while not _event_discard_pile.is_empty():
        var card = _event_discard_pile.pop_back()
        # 只有 EventCardData 才洗回事件牌堆；MagicDuelCard 等非事件牌移出游戏
        if card is EventCardData:
            _event_pile.append(card)
    _event_pile.shuffle()
    event_pile_updated.emit()
    event_discard_updated.emit()

func _create_event_card(json_data: Dictionary) -> Resource:
    var script_path: String = json_data.get("instant_effect_script", "")
    var card: EventCardData
    if script_path.is_empty():
        card = EventCardData.new()
    else:
        var scr = load(script_path)
        if scr == null:
            push_error("EventDeck: 无法加载事件效果脚本: %s" % script_path)
            card = EventCardData.new()
        else:
            card = scr.new()
    card.event_id = json_data.get("event_id", "")
    card.nice_name = json_data.get("nice_name", "")
    card.description = json_data.get("description", "")
    var dt: String = json_data.get("duration_type", "INSTANT")
    match dt:
        "INSTANT": card.duration_type = EventCardData.DurationType.INSTANT
        "UNTIL_NEXT_TRIGGER_TURN": card.duration_type = EventCardData.DurationType.UNTIL_NEXT_TRIGGER_TURN
        "UNTIL_END_OF_NEXT_OWN_TURN": card.duration_type = EventCardData.DurationType.UNTIL_END_OF_NEXT_OWN_TURN
        "CUSTOM": card.duration_type = EventCardData.DurationType.CUSTOM
    card.can_enter_hand = bool(json_data.get("can_enter_hand", false))
    return card

func _load_json_array(path: String) -> Array:
    if path.is_empty():
        return []
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("EventDeck: 无法打开 JSON: %s" % path)
        return []
    var text = file.get_as_text()
    var parsed = JSON.parse_string(text)
    if parsed is Array:
        return parsed
    return []
