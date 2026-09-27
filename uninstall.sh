#!/system/bin/sh
MODDIR=${0%/*}

(
	# Wait for boot to complete, give up after ~5 minutes
	i=0
	until [ "$(getprop sys.boot_completed)" = "1" ]; do
		i=$((i + 1))
		[ "$i" -ge 150 ] && exit 0
		sleep 2
	done

	# Let PackageManager settle
	sleep 5

	# DiracUI first, then the service it binds to
	for pkg in me.algorhythmics.diracui se.dirac.acs; do
		if pm path "$pkg" >/dev/null 2>&1; then
			pm uninstall "$pkg" >/dev/null 2>&1
		fi
	done
) >/dev/null 2>&1 &
