extends Node

## Thin wrapper around the Admob plugin node (see addons/AdmobPlugin/Admob.gd).
## Gameplay code only ever talks to this autoload, never to the Admob node
## directly, so ad-format details stay isolated here.

## Ads are fully implemented (interstitial + GDPR/UMP consent flow) but
## disabled for the initial launch -- no real AdMob account/IDs yet (see
## design doc Section 8). Flip this back on once real IDs are wired into
## the Admob node on ad_manager.tscn. While false, no consent request, SDK
## init, or ad load ever happens -- zero ad-related network activity.
const ADS_ENABLED := false

signal _interstitial_finished

@onready var _admob: Admob = $Admob

var _consent_form_retry_count: int = 0
const MAX_CONSENT_FORM_RETRIES := 1

func _ready() -> void:
	if not ADS_ENABLED:
		return

	_admob.initialization_completed.connect(_on_initialization_completed)
	_admob.interstitial_ad_failed_to_load.connect(_on_interstitial_ad_failed_to_load)
	_admob.interstitial_ad_dismissed_full_screen_content.connect(_on_interstitial_ad_finished)
	_admob.interstitial_ad_failed_to_show_full_screen_content.connect(_on_interstitial_ad_finished)

	_admob.consent_info_updated.connect(_on_consent_info_updated)
	_admob.consent_info_update_failed.connect(_on_consent_info_update_failed)
	_admob.consent_form_loaded.connect(_on_consent_form_loaded)
	_admob.consent_form_failed_to_load.connect(_on_consent_form_failed_to_load)
	_admob.consent_form_dismissed.connect(_on_consent_form_dismissed)

	# GDPR/UMP: must resolve consent (EEA/UK "Required" case shows a form)
	# before requesting ads. This runs unconditionally for every region --
	# outside EEA/UK the SDK reports NOT_REQUIRED almost immediately and we
	# fall straight through to _start_ads().
	_admob.update_consent_info()

func _on_consent_info_updated() -> void:
	if _admob.is_consent_form_available():
		_admob.load_consent_form()
	else:
		_start_ads()

func _on_consent_info_update_failed(_error_data: FormError) -> void:
	# Can't resolve consent state (e.g. no network) -- don't block the game
	# over it. The SDK will fall back to non-personalized ads as needed.
	_start_ads()

func _on_consent_form_loaded() -> void:
	var consent := _admob.get_consent_status()
	if consent != null and consent.status == UserConsent.Status.REQUIRED:
		_admob.show_consent_form()
	else:
		_start_ads()

func _on_consent_form_failed_to_load(_error_data: FormError) -> void:
	_start_ads()

func _on_consent_form_dismissed(_error_data: FormError) -> void:
	var consent := _admob.get_consent_status()
	# A well-behaved form always resolves to non-REQUIRED once the user
	# makes a choice; retry once in case of a stray dismiss, then give up
	# and proceed rather than risk blocking the game on a broken form.
	if consent != null and consent.status == UserConsent.Status.REQUIRED and _consent_form_retry_count < MAX_CONSENT_FORM_RETRIES:
		_consent_form_retry_count += 1
		_admob.load_consent_form()
	else:
		_start_ads()

func _start_ads() -> void:
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
	if not ADS_ENABLED or not _admob.is_interstitial_ad_loaded():
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
