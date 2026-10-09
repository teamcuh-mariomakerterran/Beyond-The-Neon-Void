class_name SettingsFlags
extends RefCounted
## Accessibility / debug toggles readable from anywhere.

static var reduce_motion: bool = false
static var fast_battles: bool = false
## Sync Blade Additions resolve automatically at ~70% strength (no timing).
static var auto_additions: bool = false
## Icon style: "painted" (detailed, frameless) or "framed" (orange bevel tiles).
static var icon_style: String = "painted"
## Battle barks: speech bubbles (and recorded voice lines) on crits, kills…
static var barks: bool = true
