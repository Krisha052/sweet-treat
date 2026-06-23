extends Node

func show_banner() -> void:
	# TODO: wire to AdMob.show_banner()
	pass

func hide_banner() -> void:
	# TODO: wire to AdMob.hide_banner()
	pass

func show_interstitial() -> void:
	# TODO: wire to AdMob.show_interstitial()
	pass

func show_rewarded(callback: Callable) -> void:
	# TODO: wire to AdMob.show_rewarded(); invoke callback on reward granted
	callback.call()
