class_name Damage extends Resource

enum DamageType {Physical, Magic, Mental, Real}

var type:DamageType
var num
## 为 true 时结算伤害不扣护甲、只扣血
var ignore_armor: bool = false
