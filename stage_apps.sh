#!/system/bin/sh

STAGEDIR=/data/local/tmp
STAGE_APPS="
se.dirac.acs:$MODDIR/system/priv-app/DiracAudioControlService/DiracAudioControlService.apk
me.algorhythmics.diracui:$MODDIR/system/priv-app/DiracUI/DiracUI.apk
"

slog() {
	command -v ui_print >/dev/null 2>&1 && ui_print "$1"
	/system/bin/log -p i -t dirac "$1" 2>/dev/null
}

apk_hash() { sha256sum "$1" | cut -d' ' -f1; }

needs_stage() {
	[ -f "$2" ] || { slog "! $1: APK missing"; return 1; }
	[ "$(cat "$MODDIR/.installed_$1" 2>/dev/null)" != "$(apk_hash "$2")" ] && return 0
	[ "$CHECK_PATH" = "true" ] && ! pm path "$1" 2>/dev/null | grep -q '/data/app/'
}

stage() {
	local tmp="$STAGEDIR/$1.apk" out
	cp "$2" "$tmp" && chmod 644 "$tmp"
	out=$(pm install --staged -r "$tmp" 2>&1)
	rm -f "$tmp"
	case "$out" in
		*Success*)
			apk_hash "$2" > "$MODDIR/.installed_$1"
			slog "- $1 staged"
			;;
		*)
			slog "! $1 not staged: $out"
			return 1
			;;
	esac
}

if [ "$(getprop ro.build.version.sdk)" -lt 29 ]; then
	slog "! Android 9 or older can't update persistent apps"
	slog "! Disable module unmounting for Dirac and DiracUI in your root manager"
else
	CHECKPOINT=$(sm supports-checkpoint 2>/dev/null)
	STAGED=false
	LEFT=false
	for entry in $STAGE_APPS; do
		needs_stage "${entry%%:*}" "${entry#*:}" || continue
		if $STAGED && [ "$CHECKPOINT" != "true" ]; then
			LEFT=true
			continue
		fi
		if stage "${entry%%:*}" "${entry#*:}"; then
			STAGED=true
		else
			LEFT=true
		fi
	done

	if $STAGED && $LEFT; then
		slog "- Reboot to install, the remaining app is staged on the next boot"
	elif $STAGED; then
		slog "- Reboot to finish installing the apps"
	elif $LEFT; then
		slog "! Could not stage the apps, will retry on next boot"
	fi
fi
