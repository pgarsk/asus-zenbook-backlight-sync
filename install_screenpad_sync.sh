#!/usr/bin/env bash
#
# setup_asus_brightness.sh
# https://github.com/pgarsk/asus-zenbook-backlight-sync
#
# Interactive installer/uninstaller for the ASUS Screenpad brightness-sync daemon.
#
# When run, this script will prompt you to either:
#   1) Install the daemon and systemd service
#   2) Uninstall the daemon and service
#   3) Quit
#
# Usage: Run as root (e.g. sudo ./setup_asus_brightness.sh)
#

set -e

DAEMON_PATH="/usr/local/bin/asus_brightness_daemon.sh"
SERVICE_PATH="/etc/systemd/system/asus-brightness-daemon.service"

print_header() {
  echo "==========================================="
  echo " ASUS Screenpad Brightness Sync Installer"
  echo "==========================================="
}

install() {
  echo
  echo "Installing ASUS brightness-sync daemon..."
  echo

  # 1) Write daemon script
  cat > "$DAEMON_PATH" << 'EOF'
#!/usr/bin/env bash
#
# /usr/local/bin/asus_brightness_daemon.sh
#
# Poll Intel backlight brightness every 0.2s, and whenever it changes,
# set ASUS Screenpad brightness to the same percentage.
#
# Meant to be run as a systemd service at boot (as root).
#

# — Paths to the backlight interfaces —
INTEL_BRIGHT="/sys/class/backlight/intel_backlight/brightness"
INTEL_MAX="/sys/class/backlight/intel_backlight/max_brightness"

ASUS_BRIGHT="/sys/class/backlight/asus_screenpad/brightness"
ASUS_MAX="/sys/class/backlight/asus_screenpad/max_brightness"

# — Poll interval (in seconds; e.g. 0.1 = 100 ms) —
SLEEP_INTERVAL=0.1

# — Check that all required files exist and are readable/writable —
for path in "$INTEL_BRIGHT" "$INTEL_MAX" "$ASUS_BRIGHT" "$ASUS_MAX"; do
  if [[ ! -e "$path" ]]; then
    echo "[$(date '+%F %T')] ERROR: File not found: $path" >&2
    exit 1
  fi
done

# We need read permission on INTEL_*, and write permission on ASUS_BRIGHT.
if [[ ! -r "$INTEL_BRIGHT" || ! -r "$INTEL_MAX" ]]; then
  echo "[$(date '+%F %T')] ERROR: Cannot read Intel backlight files." >&2
  exit 1
fi
if [[ ! -r "$ASUS_MAX" ]]; then
  echo "[$(date '+%F %T')] ERROR: Cannot read ASUS Screenpad max_brightness." >&2
  exit 1
fi
if [[ ! -w "$ASUS_BRIGHT" ]]; then
  echo "[$(date '+%F %T')] ERROR: Cannot write to ASUS Screenpad brightness." >&2
  exit 1
fi

# — Read “max” values once —
intel_max_val=$(< "$INTEL_MAX")
asus_max_val=$(< "$ASUS_MAX")

# Sanity check on numeric contents:
if ! [[ "$intel_max_val" =~ ^[0-9]+$ ]] || [[ "$intel_max_val" -le 0 ]]; then
  echo "[$(date '+%F %T')] ERROR: Intel max_brightness invalid: $intel_max_val" >&2
  exit 1
fi
if ! [[ "$asus_max_val" =~ ^[0-9]+$ ]] || [[ "$asus_max_val" -le 0 ]]; then
  echo "[$(date '+%F %T')] ERROR: ASUS max_brightness invalid: $asus_max_val" >&2
  exit 1
fi

# — Helper: compute & write ASUS brightness given an Intel value —
sync_to_asus() {
  local intel_val="$1"
  # Calculate new ASUS value:  (intel_val/intel_max) * asus_max
  local raw=$(( intel_val * asus_max_val / intel_max_val ))
  # Clamp to [0 .. asus_max_val]
  if   [[ $raw -lt 0 ]]; then
    asus_val=0
  elif [[ $raw -gt $asus_max_val ]]; then
    asus_val=$asus_max_val
  else
    asus_val=$raw
  fi

  # Write it
  echo "$asus_val" > "$ASUS_BRIGHT" || {
    echo "[$(date '+%F %T')] ERROR: Failed to write $asus_val -> $ASUS_BRIGHT" >&2
  }
}

# — Initial read & sync at startup —
prev_intel_val=$(< "$INTEL_BRIGHT")
sync_to_asus "$prev_intel_val"

# — Main loop: poll every $SLEEP_INTERVAL seconds —
while true; do
  sleep "$SLEEP_INTERVAL"
  cur_intel_val=$(< "$INTEL_BRIGHT")

  if [[ "$cur_intel_val" -ne "$prev_intel_val" ]]; then
    sync_to_asus "$cur_intel_val"
    prev_intel_val="$cur_intel_val"
  fi
done
EOF

  chmod +x "$DAEMON_PATH"
  echo "→ Created daemon script at $DAEMON_PATH (executable)."

  # 2) Write systemd service unit
  cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Daemon: Sync Intel backlight → ASUS Screenpad
After=multi-user.target

[Service]
Type=simple
ExecStart=$DAEMON_PATH
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "$SERVICE_PATH"
  echo "→ Created systemd service at $SERVICE_PATH."

  # 3) Reload systemd, enable & start service
  systemctl daemon-reload
  systemctl enable --now asus-brightness-daemon.service

  echo
  echo "Installation complete!"
  echo "Service 'asus-brightness-daemon.service' is enabled and running."
  echo
}

uninstall() {
  echo
  echo "Uninstalling ASUS brightness-sync daemon..."
  echo

  # Stop & disable service if exists
  if systemctl is-active --quiet asus-brightness-daemon.service; then
    systemctl stop asus-brightness-daemon.service
    echo "→ Stopped service."
  fi

  if systemctl is-enabled --quiet asus-brightness-daemon.service; then
    systemctl disable asus-brightness-daemon.service
    echo "→ Disabled service."
  fi

  # Remove service file
  if [[ -f "$SERVICE_PATH" ]]; then
    rm -f "$SERVICE_PATH"
    echo "→ Removed $SERVICE_PATH."
  fi

  # Remove daemon script
  if [[ -f "$DAEMON_PATH" ]]; then
    rm -f "$DAEMON_PATH"
    echo "→ Removed $DAEMON_PATH."
  fi

  # Reload systemd to apply removal
  systemctl daemon-reload

  echo
  echo "Uninstallation complete."
  echo
}

main_menu() {
  while true; do
    print_header
    echo "Choose an option:"
    echo "  1) Install"
    echo "  2) Uninstall"
    echo "  3) Quit"
    read -rp "Enter choice [1-3]: " choice
    case "$choice" in
      1)
        install
        break
        ;;
      2)
        uninstall
        break
        ;;
      3)
        echo "Exiting."
        exit 0
        ;;
      *)
        echo "Invalid choice. Please enter 1, 2 or 3."
        ;;
    esac
  done
}

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root (e.g. sudo ./setup_asus_brightness.sh)."
  exit 1
fi

main_menu
