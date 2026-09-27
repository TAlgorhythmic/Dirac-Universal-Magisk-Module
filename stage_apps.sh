#!/system/bin/sh
# stage_apps.sh - sourced by customize.sh (flash time) and service.sh (boot).
#
# Dirac and DiracUI are persistent priv-apps. Root managers may unmount module
# files from app processes, which breaks them, so both are also installed as
# updates of their priv-app copies: their code then loads from /data/app,
# which every process can see. Persistent apps can only be updated through
# staged installs, which apply on the next reboot.
#
# Set before sourcing:
#   MODDIR      module folder
#   CHECK_PATH  "true" to also restage apps not running from /data/app (boot only)

STAGEDIR=/data/local/tmp

# package:APK inside the module. Dirac first, DiracUI binds to it.
STAGE_APPS="
se.dirac.acs:$MODDIR/system/priv-app/DiracAudioControlService/DiracAudioControlService.apk
me.algorhythmics.diracui:$MODDIR/system/priv-app/DiracUI/DiracUI.apk
"

# Print to the flash screen when available, always to logcat
slog() {
	command -v ui_print >/dev/null 2>&1 && ui_print "$1"
	/system/bin/log -p i -t dirac "$1" 2>/dev/null
}

apk_hash() { sha256sum "$1" | cut -d' ' -f1; }

# Session ID from "Success: created install session [1234]", empty on failure
new_session() {
	pm install-create "$@" 2>&1 | sed -n 's/.*\[\([0-9]*\)\].*/\1/p'
}

# True if the package needs (re)staging
needs_stage() {
	local pkg=$1 apk=$2
	if [ ! -f "$apk" ]; then
		slog "! $pkg: APK missing at $apk"
		return 1
	fi
	[ "$(cat "$MODDIR/.installed_$pkg" 2>/dev/null)" != "$(apk_hash "$apk")" ] && return 0
	if [ "$CHECK_PATH" = "true" ] && ! pm path "$pkg" 2>/dev/null | grep -q '/data/app/'; then
		return 0
	fi
	return 1
}

mark_staged() { apk_hash "$2" > "$MODDIR/.installed_$1"; }

# Stage one APK on its own
stage_single() {
	local pkg=$1 apk=$2 tmp="$STAGEDIR/$1.apk" out
	cp "$apk" "$tmp" && chmod 644 "$tmp"
	out=$(pm install --staged -r "$tmp" 2>&1)
	rm -f "$tmp"
	case "$out" in
		*Success*) mark_staged "$pkg" "$apk"; slog "- $pkg staged"; return 0 ;;
		*) slog "! $pkg staging failed: $out"; return 1 ;;
	esac
}

# Stage several APKs in one multi-package session (counts as one staged session)
stage_multi() {
	local parent child children="" tmps="" entry pkg apk tmp out s ok=true
	parent=$(new_session --multi-package --staged -r)
	if [ -z "$parent" ]; then
		slog "! Could not create multi-package session"
		return 1
	fi
	for entry in $1; do
		pkg=${entry%%:*}
		apk=${entry#*:}
		tmp="$STAGEDIR/$pkg.apk"
		tmps="$tmps $tmp"
		cp "$apk" "$tmp" && chmod 644 "$tmp"
		child=$(new_session --staged -r)
		if [ -z "$child" ]; then
			out="could not create session for $pkg"
			ok=false
			break
		fi
		children="$children $child"
		out=$(pm install-write "$child" base.apk "$tmp" 2>&1)
		case "$out" in *Success*) ;; *) ok=false; break ;; esac
	done
	if $ok; then
		out=$(pm install-add-session "$parent" $children 2>&1)
		case "$out" in *Failure*|*Error*|*Exception*) ok=false ;; esac
	fi
	if $ok; then
		out=$(pm install-commit "$parent" 2>&1)
		case "$out" in *Success*) ;; *) ok=false ;; esac
	fi
	rm -f $tmps
	if ! $ok; then
		slog "! Multi-package staging failed: $out"
		for s in $children $parent; do
			pm install-abandon "$s" >/dev/null 2>&1
		done
		return 1
	fi
	for entry in $1; do
		mark_staged "${entry%%:*}" "${entry#*:}"
	done
	slog "- Apps staged"
	return 0
}

SDK=$(getprop ro.build.version.sdk)
if [ "$SDK" -lt 29 ]; then
	slog "! Android $SDK can't update persistent apps"
	slog "! Disable module unmounting for Dirac and DiracUI in your root manager"
else
	PENDING=""
	FIRST=""
	COUNT=0
	for entry in $STAGE_APPS; do
		if needs_stage "${entry%%:*}" "${entry#*:}"; then
			PENDING="$PENDING $entry"
			[ -z "$FIRST" ] && FIRST=$entry
			COUNT=$((COUNT + 1))
		fi
	done

	STAGED=false
	if [ "$COUNT" -eq 1 ]; then
		stage_single "${FIRST%%:*}" "${FIRST#*:}" && STAGED=true
	elif [ "$COUNT" -gt 1 ]; then
		if stage_multi "$PENDING"; then
			STAGED=true
		else
			# Some ROMs allow only one pending staged install: do one per boot
			slog "- Falling back to one app per boot"
			stage_single "${FIRST%%:*}" "${FIRST#*:}" && STAGED=true
		fi
	fi

	if $STAGED; then
		slog "- Reboot to finish installing the apps"
	elif [ "$COUNT" -gt 0 ]; then
		slog "! Could not stage the apps, will retry on next boot"
		slog "! If this persists, disable module unmounting for Dirac and DiracUI"
	fi
fi
