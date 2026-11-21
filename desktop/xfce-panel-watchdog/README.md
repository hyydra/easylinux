# XFCE Panel Auto-Restart Watchdog

A lightweight background watchdog and systemd user service that automatically recovers the XFCE taskbar (`xfce4-panel`) if it crashes, closes, or fails.

### Features:
- **Instant Recovery**: Continuously checks if `xfce4-panel` is alive during active X11 sessions and relaunches it within seconds.
- **Session Reattachment**: Automatically attaches the revived panel back to the active XFCE session manager (`SESSION_MANAGER`).
- **Crash Loop Throttling**: Automatically backs off if repeated rapid restarts occur within 60 seconds to avoid high CPU usage.
- **Systemd User Service**: Runs cleanly under `systemd --user` with `Restart=always` without consuming unnecessary system resources.
- **Audit Logging**: Keeps timestamped logs of restarts in `~/.cache/xfce4-panel-watchdog.log`.

### Installation:
```bash
./install.sh
```

### Uninstallation:
```bash
./uninstall.sh
```

### Manual Commands:
- Check status:
  ```bash
  systemctl --user status xfce4-panel-watchdog.service
  ```
- View watchdog logs:
  ```bash
  tail -f ~/.cache/xfce4-panel-watchdog.log
  ```
