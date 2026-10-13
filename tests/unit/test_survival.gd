extends TestCase

var s: GameSession


func before_each() -> void:
	s = new_session()


func test_decay_over_time() -> void:
	var h0 := s.survival.hunger
	var t0 := s.survival.thirst
	s.advance(120)
	near(s.survival.hunger, h0 - 8.0, 0.01, "2時間で空腹-8")
	near(s.survival.thirst, t0 - 12.0, 0.01, "2時間で水分-12")
	check(s.survival.fatigue > 0.0, "疲労増加")


func test_use_item_restores() -> void:
	s.survival.hunger = 10
	var before := s.inventory.count("coconut")
	check(s.use_item("coconut"), "使用成功")
	near(s.survival.hunger, 22.0, 0.01, "空腹回復")
	eq(s.inventory.count("coconut"), before - 1, "1個消費")


func test_cannot_use_non_consumable() -> void:
	check(not s.use_item("wood"), "木材は使えない")
	s.inventory.stacks.erase("coconut")
	check(not s.use_item("coconut"), "持っていなければ使えない")


func test_starvation_damages_and_efficiency_drops() -> void:
	s.survival.hunger = 0
	s.survival.thirst = 0
	var hp := s.survival.health
	s.advance(60)
	check(s.survival.health < hp, "飢餓で体力減少")
	check(s.survival.efficiency() < 0.7, "効率低下: %f" % s.survival.efficiency())


func test_collapse_is_not_game_over() -> void:
	s.survival.health = 1
	s.survival.hunger = 0
	s.survival.thirst = 0
	var t := s.clock.total_minutes
	s.advance(60)
	check(s.survival.health > 0, "気絶後に回復")
	eq(s.survival.collapse_count, 1, "気絶回数")
	check(s.clock.total_minutes > t + 300, "時間が経過")
