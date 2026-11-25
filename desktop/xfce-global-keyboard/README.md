# XFCE Global Keyboard Layout

Prevents XFCE from resetting or switching keyboard layouts/languages independently between different application windows.

### What it does:
- Configures the XFCE panel `xkb` plugin layout management policy (`group-policy`) to `0` (**Globally**).
- Ensures IBus input method (`use-global-engine`) is enabled.
- Result: When you switch languages (e.g. from English to Hungarian), the language remains selected system-wide for all open windows.

### Usage:
```bash
./set-global-keyboard.sh
```
