# Working on or with easyset linux (for Claude Code)

easyset linux (command `easyset`, repo `hyydra/easyset-linux`) sets up a Linux desktop (XFCE base) and its hardware, with a safety net.

## Setting up a new machine (the order matters)
1. `easyset --doctor` (read-only): what hardware, desktop and tools the machine has. Read it before anything else.
2. `easyset --user` (no root): look, panel, desktop layout, icons. Safe to run and to undo (`desktop/theme/*.sh --undo`).
3. `sudo easyset --system` only after reading `--doctor`: system fixes. A snapshot is taken first; undo with `sudo easyset --rollback`.
4. Hardware fixes exist only for a ThinkPad X280; on other machines they are skipped. Do not invent fixes for hardware you cannot test: add a `hardware/<machine>/` folder only after measuring on that machine.

## Rules
- Root steps go through the graphical admin prompt (polkit, `pkexec`) or `sudo` typed by the user. Never set up passwordless sudo for yourself.
- Only verified sources: the distribution's official archive, verified snaps, LVFS firmware. No third-party snaps, PPAs, curl|sh.
- Firmware is never flashed automatically (`easyset --tbt-update` only on request).
- Everything in the repo is English. Run `bash tests/run.sh` before every push; tests are sandboxed and never touch the real /etc.
- Measure, do not guess: when a hardware symptom is reported, read the kernel counters, logs and sysfs first (the X280 notes in hardware/thinkpad-x280/README.md show how).
