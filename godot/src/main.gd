extends Node
## ルートシーン。World（3D）と UILayer / OverlayLayer（2D）を持つだけ。進行は Game が行う。


func _ready() -> void:
	Game.register_main(self)
	if not Game.testing:
		Game.show_title()
