#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sandbox
LIB="$TEST_ROOT/safety/lib.sh"; RB="$TEST_ROOT/safety/easylinux-rollback.sh"
snap() { bash -c "source $LIB; es_begin $1; shift; for f in \"\$@\"; do es_backup \"\$f\"; done; es_arm" -- "$@" >/dev/null 2>&1; }

echo "-- snapshot + manual rollback"
echo original > "$SB/etc/a.conf"
snap t1 "$SB/etc/a.conf" "$SB/etc/new.conf" "$SB/etc/a.conf"
S1="$(find "$SB/bk" -mindepth 1 -maxdepth 1 -type d | head -n1)"
assert_eq "$(wc -l < "$S1/manifest" | tr -d ' ')" 2 "duplicate backups are recorded once"
assert_file "$S1/rollback.sh" "snapshot carries its own rollback script"
case "$(readlink "$SB/bk/latest")" in /*) bad "latest link is relative" ;; *) ok "latest link is relative" ;; esac
assert_file "$SB/st/pending" "snapshot is pending after arming"
echo changed > "$SB/etc/a.conf"; echo x > "$SB/etc/new.conf"
bash "$RB" >/dev/null
assert_eq "$(cat "$SB/etc/a.conf")" original "modified file restored"
assert_no_file "$SB/etc/new.conf" "file that did not exist is removed"
assert_no_file "$SB/st/pending" "pending cleared after rollback"
assert_file "$S1/ROLLED_BACK" "snapshot marked as rolled back"

echo "-- notes are printed"
rm -rf "$SB/bk" "$SB/st"
bash -c "source $LIB; es_begin n1; es_backup $SB/etc/a.conf; es_note 'remove package foo'; es_arm" >/dev/null 2>&1
bash "$RB" > "$SB/out" 2>&1
assert_contains "$SB/out" "remove package foo" "snapshot note shown on rollback"

echo "-- --auto rolls back every unconfirmed snapshot, newest first"
rm -rf "$SB/bk" "$SB/st"; echo original > "$SB/etc/a.conf"
snap s1 "$SB/etc/a.conf"; echo v1 > "$SB/etc/a.conf"; sleep 1
snap s2 "$SB/etc/a.conf"; echo v2 > "$SB/etc/a.conf"
bash "$RB" --auto >/dev/null 2>&1
assert_eq "$(cat "$SB/etc/a.conf")" original "all pending snapshots undone back to the first state"
assert_no_file "$SB/st/pending" "pending cleared after --auto"

echo "-- --list ignores the latest symlink"
assert_eq "$(bash "$RB" --list | wc -l | tr -d ' ')" 2 "two snapshot dirs listed, no symlink"

echo "-- pruning keeps pending snapshots"
rm -rf "$SB/bk" "$SB/st"; mkdir -p "$SB/bk/20200101-old" "$SB/bk/20200102-old" "$SB/bk/20200103-old" "$SB/st"
echo "$SB/bk/20200101-old" > "$SB/st/pending"
ES_KEEP=2 bash -c "source $LIB; es_begin p" >/dev/null 2>&1
assert_file "$SB/bk/20200101-old" "pending snapshot survives pruning"
assert_no_file "$SB/bk/20200102-old" "old unpinned snapshot pruned"

echo "-- offline --root rollback (live USB)"
R="$SB/mnt"; mkdir -p "$R/etc" "$R/var/lib/easylinux"
unset ES_BACKUP_DIR ES_STATE_DIR
echo original > "$R/etc/a.conf"
S="$R/var/backups/easylinux/20260101-000000-demo"; mkdir -p "$S/files/etc"
cp "$R/etc/a.conf" "$S/files/etc/a.conf"; printf 'F\t/etc/a.conf\nN\t/etc/new.conf\n' > "$S/manifest"
cp "$RB" "$S/rollback.sh"; ln -sfn 20260101-000000-demo "$R/var/backups/easylinux/latest"
echo "/var/backups/easylinux/20260101-000000-demo" > "$R/var/lib/easylinux/pending"
echo broken > "$R/etc/a.conf"; echo x > "$R/etc/new.conf"
(command -v dash >/dev/null && dash "$R/var/backups/easylinux/latest/rollback.sh" --root "$R" || sh "$R/var/backups/easylinux/latest/rollback.sh" --root "$R") >/dev/null 2>&1
assert_eq "$(cat "$R/etc/a.conf")" original "--root restores into the mounted system"
assert_no_file "$R/etc/new.conf" "--root removes files that did not exist"
assert_no_file "$R/var/lib/easylinux/pending" "--root clears the pending state"
finish
