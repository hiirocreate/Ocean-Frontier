class_name GameClock
extends RefCounted
## ゲーム内時間（分単位）。実時間との倍率は balance_config.json の time 設定で決まる。

var total_minutes: float = 0.0


func advance(minutes: float) -> void:
	if minutes > 0.0:
		total_minutes += minutes


func day() -> int:
	return int(total_minutes / 1440.0) + 1


func hour() -> int:
	return int(fmod(total_minutes, 1440.0) / 60.0)


func minute() -> int:
	return int(fmod(total_minutes, 60.0))


## 0.0=0時, 0.5=正午
func time_of_day() -> float:
	return fmod(total_minutes, 1440.0) / 1440.0


func label() -> String:
	return "%d日目 %02d:%02d" % [day(), hour(), minute()]


func to_dict() -> Dictionary:
	return {"total_minutes": total_minutes}


func from_dict(d: Dictionary) -> void:
	total_minutes = maxf(0.0, float(d.get("total_minutes", 0.0)))
