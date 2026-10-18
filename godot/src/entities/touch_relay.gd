extends Area3D
## Area3D から 親（Friend など）へ on_player_touch を中継する。


func on_player_touch(player: Node) -> void:
	var p := get_parent()
	if p and p.has_method("on_player_touch"):
		p.on_player_touch(player)


func on_player_stay(player: Node, delta: float) -> void:
	var p := get_parent()
	if p and p.has_method("on_player_stay"):
		p.on_player_stay(player, delta)
