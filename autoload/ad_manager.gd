extends Node

## Thin wrapper around the Admob plugin node (see addons/AdmobPlugin/Admob.gd).
## Gameplay code only ever talks to this autoload, never to the Admob node
## directly, so ad-format details stay isolated here.

signal _interstitial_finished

@onready var _admob: Admob = $Admob

func _ready() -> void:
	_admob.initialization_completed.connect(_on_initialization_completed)
	_admob.interstitial_ad_failed_to_load.connect(_on_interstitial_ad_failed_to_load)
	_admob.interstitial_ad_dismissed_full_screen_content.connect(_on_interstitial_ad_finished)
	_admob.interstitial_ad_failed_to_show_full_screen_content.connect(_on_interstitial_ad_finished)
	_admob.initialize()

func _on_initialization_completed(_status_data: InitializationStatus) -> void:
	_admob.load_interstitial_ad()

func _on_interstitial_ad_failed_to_load(_ad_info: AdInfo, _error_data: LoadAdError) -> void:
	# No fill / network error — retry rather than leaving the game without a
	# preloaded ad for the rest of the session.
	await get_tree().create_timer(5.0).timeout
	_admob.load_interstitial_ad()

func show_banner() -> void:
	pass # Not part of this phase — see design doc Section 8.

func hide_banner() -> void:
	pass # Not part of this phase — see design doc Section 8.

## Shows a preloaded interstitial and waits for it to close. If no ad is
## loaded yet (still loading, failed to load, or SDK not initialized), it
## returns immediately — callers must never stall a scene transition
## waiting on an ad that may never come. Also guards against the dismissed/
## failed-to-show signals never firing (native SDK misbehavior) with a
## timeout, for the same reason.
func show_interstitial() -> void:
	if not _admob.is_interstitial_ad_loaded():
		return
	_admob.show_interstitial_ad()
	var timeout_timer := get_tree().create_timer(10.0)
	timeout_timer.timeout.connect(_interstitial_finished.emit)
	await _interstitial_finished

func _on_interstitial_ad_finished(_ad_info: AdInfo, _error_data: AdError = null) -> void:
	_interstitial_finished.emit()
	_admob.load_interstitial_ad() # preload the next one

func show_rewarded(callback: Callable) -> void:
	# TODO: rewarded ads deferred — reward mechanic (extra time? free retry?)
	# not yet designed. See design doc Section 8.
	callback.call()
