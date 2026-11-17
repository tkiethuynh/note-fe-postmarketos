#!/bin/sh
# Ensure Exynos 8890 android_usb RNDIS gadget comes up reliably
ANDROID_USB="/sys/class/android_usb/android0"
if [ -d "$ANDROID_USB" ]; then
	if ! ip link show rndis0 >/dev/null 2>&1 && ! ip link show usb0 >/dev/null 2>&1; then
		echo 0 > "$ANDROID_USB/enable" 2>/dev/null || true
		echo "" > "$ANDROID_USB/functions" 2>/dev/null || true
		echo 1 > "$ANDROID_USB/enable" 2>/dev/null || true
		usleep 500000 2>/dev/null || sleep 1
		echo 0 > "$ANDROID_USB/enable" 2>/dev/null || true
		echo "04e8" > "$ANDROID_USB/idVendor" 2>/dev/null || true
		echo "6863" > "$ANDROID_USB/idProduct" 2>/dev/null || true
		echo "Samsung" > "$ANDROID_USB/iManufacturer" 2>/dev/null || true
		echo "Galaxy Note FE (pmOS)" > "$ANDROID_USB/iProduct" 2>/dev/null || true
		echo "rndis" > "$ANDROID_USB/functions" 2>/dev/null || true
		echo 1 > "$ANDROID_USB/enable" 2>/dev/null || true
	fi
fi
