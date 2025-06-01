# asus-zenbook-backlight-sync

Sync the Backlight of the Asus ScreenPad (secondary) display with the brightness of the Intel (primary) display.

## What does this do?
This script installs a small background service that automatically keeps your Asus ScreenPad (Pro Duo Display) brightness in sync with your main screen's brightness.

## How to use

### 1. Download or clone this repository

```
git clone https://github.com/pgarsk/asus-zenbook-backlight-sync.git
cd asus-zenbook-backlight-sync
```

### 2. Run the installer script as root

You need to run the script with root privileges because it installs a system service and needs access to backlight controls.

```
sudo ./install_screenpad_sync.sh
```

### 3. Follow the prompts
- **Install**: Sets up the sync service so it starts automatically and runs in the background.
- **Uninstall**: Removes the service and all installed files.
- **Quit**: Exits without making changes.

### 4. That's it!
- After installation, your ScreenPad brightness will always match your main display.
- The service will start automatically on boot.

## Troubleshooting
- Make sure you are running on an Asus Zenbook with a ScreenPad.
- You must run the script as root (use `sudo`).
- If you see errors about missing files, your device may not use the same backlight paths. This script expects:
  - `/sys/class/backlight/intel_backlight/`
  - `/sys/class/backlight/asus_screenpad/`

## Uninstall
Run the script again and choose **Uninstall**.

---

**Note:** This script is provided as-is. Use at your own risk.
