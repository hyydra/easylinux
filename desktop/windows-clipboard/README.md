# Windows-style Ctrl+C / Ctrl+V

Copy and paste with plain **Ctrl+C / Ctrl+V** everywhere, never Shift+Ctrl, just like Windows.

- GUI apps (browser, editor, file manager, office) already behave this way on Linux.
- Terminals are the exception: there Ctrl+C means "interrupt", so copy/paste is Ctrl+Shift+C/V.
- This module switches the default terminal to **kitty** and configures it like Windows Terminal:
  - text selected + **Ctrl+C** -> copies (and clears the selection)
  - nothing selected + **Ctrl+C** -> interrupts the running program (also over ssh)
  - **Ctrl+V** -> pastes

```bash
./install.sh     # installs kitty if missing (sudo), writes config, sets it as XFCE default terminal (Ctrl+Alt+T)
./uninstall.sh   # removes the config, restores the previous default terminal
```
Not covered: terminals embedded in other apps (e.g. the VS Code terminal) keep their own keys.
