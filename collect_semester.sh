#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# collect_semester.sh
# Scans your Mac for semester school files, syncs them to your SSD,
# and optionally deletes the local originals to free up space.
#
# Usage:
#   bash collect_semester.sh            # collect + sync only
#   bash collect_semester.sh --cleanup  # collect + sync + delete local files
# ---------------------------------------------------------------------------

set -uo pipefail

# ── UPDATE THESE EACH SEMESTER ───────────────────────────────────────────────
BACKUP_FOLDER_NAME="Y2S2_Semester_Backup"   # label for the backup folder
START_DATE="2025-09-01"                      # semester start
END_DATE="2026-04-30"                        # semester end
SSD_NAME="X10 Pro"                           # your SSD name as shown in Finder

# ── Known top-level project folders to always include ────────────────────────
KNOWN_FOLDERS=(
  "comp2080-project"
  "comp2152-termproject"
  "comp2152_assignment2"
  "schoolwork"
  "afterthebeep_project"
  "2147"
  "goodbehaviour"
  "valentines_2026"
  "portfolio"
)

# ── Known Desktop folders to always include ───────────────────────────────────
DESKTOP_FOLDERS=(
  "COMP2139-ICE"
  "Afterthebeep proj"
  "Website Project 2025"
  "assignment3"
  "comp1202"
  "lab_wk4"
  "2025"
  "assignment2comp1239"
)

# ── Internal config (no need to edit below this line) ────────────────────────
HOME_DIR="$HOME"
DEST="$HOME/$BACKUP_FOLDER_NAME"
SSD_DEST="/Volumes/$SSD_NAME/$BACKUP_FOLDER_NAME"
LOG="$DEST/_collection_log.txt"
DELETE_LIST="$DEST/_to_delete.txt"
CLEANUP=false

[[ "${1:-}" == "--cleanup" ]] && CLEANUP=true

# ── Helpers ───────────────────────────────────────────────────────────────────
in_date_range() {
  local mtime
  mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$1" 2>/dev/null || echo "0000-00-00")
  [[ "$mtime" > "$START_DATE" || "$mtime" == "$START_DATE" ]] &&
  [[ "$mtime" < "$END_DATE"   || "$mtime" == "$END_DATE"   ]]
}

copy_item() {
  local src="$1"
  local rel="${src#$HOME_DIR/}"
  local dst_dir="$DEST/$(dirname "$rel")"
  mkdir -p "$dst_dir"
  if cp -R "$src" "$dst_dir/" 2>/dev/null; then
    echo "COPIED  $rel" >> "$LOG"
    echo "$src" >> "$DELETE_LIST"
    return 0
  else
    echo "FAILED  $rel" >> "$LOG"
    return 1
  fi
}

print_header() {
  echo ""
  echo "========================================"
  echo "  Semester Backup Tool"
  echo "  Semester : $BACKUP_FOLDER_NAME"
  echo "  Window   : $START_DATE → $END_DATE"
  echo "  Cleanup  : $CLEANUP"
  echo "========================================"
  echo ""
}

# ── Phase 1: Collect ──────────────────────────────────────────────────────────
phase_collect() {
  mkdir -p "$DEST"
  > "$DELETE_LIST"  # reset delete list
  echo "=== Collection Log  $(date) ===" > "$LOG"
  echo "Source      : $HOME_DIR"         >> "$LOG"
  echo "Destination : $DEST"             >> "$LOG"
  echo "Window      : $START_DATE – $END_DATE" >> "$LOG"
  echo "========================================" >> "$LOG"

  echo "[ Phase 1 ] Scanning $HOME_DIR ..."
  echo ""

  local found=0 skipped=0

  while IFS= read -r -d '' item; do
    [[ "$item" == "$DEST"* ]] && continue
    if in_date_range "$item"; then
      copy_item "$item" && (( found++ )) && echo "  [+] ${item#$HOME_DIR/}"
    else
      (( skipped++ ))
      echo "SKIPPED (date) ${item#$HOME_DIR/}" >> "$LOG"
    fi
  done < <(
    find "$HOME_DIR" \
      -path "$HOME/Library"        -prune -o \
      -path "$HOME/.Trash"         -prune -o \
      -path "$HOME/.npm"           -prune -o \
      -path "$HOME/.cache"         -prune -o \
      -path "$HOME/.cursor"        -prune -o \
      -path "$HOME/.lmstudio"      -prune -o \
      -path "$HOME/.nuget"         -prune -o \
      -path "$HOME/.platformio"    -prune -o \
      -path "$HOME/.local"         -prune -o \
      -path "$HOME/.dotnet"        -prune -o \
      -path "$HOME/.ServiceHub"    -prune -o \
      -path "$HOME/.claude"        -prune -o \
      -path "$HOME/.config"        -prune -o \
      -path "$HOME/node_modules"   -prune -o \
      -name "node_modules"         -prune -o \
      -name ".git"                 -prune -o \
      -name "bin"                  -prune -o \
      -name "obj"                  -prune -o \
      -path "$DEST"                -prune -o \
      \( \
        -name "*[Cc][Oo][Mm][Pp][0-9]*"                 -o \
        -name "*[Pp][Rr][Oo][Jj][Ee][Cc][Tt]*"          -o \
        -name "*[Aa][Ss][Ss][Ii][Gg][Nn][Mm][Ee][Nn][Tt]*" -o \
        -name "*[Ll][Aa][Bb][_-]*"                       -o \
        -name "*[Ll][Aa][Bb][0-9]*"                      -o \
        -name "*labtest*"                                -o \
        -name "*[Tt][Ee][Rr][Mm][-_][Pp]*"              -o \
        -name "*[Ff][Ii][Nn][Aa][Ll][-_][Pp][Rr][Oo][Jj]*" -o \
        -name "*[Ff][Ii][Nn][Aa][Ll][-_][Rr][Ee][Pp][Oo][Rr][Tt]*" -o \
        -name "*[Mm][Ii][Dd][Tt][Ee][Rr][Mm]*"          -o \
        -name "*[Ss][Ee][Nn][Ee][Cc][Aa]*"               -o \
        -name "*[Ww][Ee][Ee][Kk][Ll][Yy][-_][Pp][Rr][Oo][Gg]*" \
      \) \
      -print0 2>/dev/null
  )

  echo ""
  echo "[ Phase 1 ] Checking known top-level folders..."
  for folder in "${KNOWN_FOLDERS[@]}"; do
    local src="$HOME_DIR/$folder"
    if [ -e "$src" ]; then
      mkdir -p "$DEST/top-level-projects"
      if cp -R "$src" "$DEST/top-level-projects/" 2>/dev/null; then
        echo "COPIED  top-level/$folder" >> "$LOG"
        echo "$src" >> "$DELETE_LIST"
        (( found++ ))
        echo "  [+] $folder"
      fi
    fi
  done

  echo ""
  echo "[ Phase 1 ] Checking Desktop folders..."
  for folder in "${DESKTOP_FOLDERS[@]}"; do
    local src="$HOME/Desktop/$folder"
    if [ -e "$src" ]; then
      mkdir -p "$DEST/Desktop"
      if cp -R "$src" "$DEST/Desktop/" 2>/dev/null; then
        echo "COPIED  Desktop/$folder" >> "$LOG"
        echo "$src" >> "$DELETE_LIST"
        (( found++ ))
        echo "  [+] Desktop/$folder"
      fi
    fi
  done

  echo ""
  echo "  Items collected : $found"
  echo "  Date-skipped    : $skipped (see log)"
  echo "  Backup folder   : $DEST"
}

# ── Phase 2: Sync to SSD ──────────────────────────────────────────────────────
phase_sync() {
  echo ""
  echo "[ Phase 2 ] Syncing to SSD \"$SSD_NAME\" ..."

  if [ ! -d "/Volumes/$SSD_NAME" ]; then
    echo ""
    echo "  ERROR: SSD \"$SSD_NAME\" is not mounted."
    echo "  Plug in your X10 Pro SSD, then run:"
    echo "    rsync -av --progress \"$DEST/\" \"$SSD_DEST/\""
    echo ""
    return 1
  fi

  mkdir -p "$SSD_DEST"
  rsync -av --progress "$DEST/" "$SSD_DEST/"
  echo ""
  echo "  Sync complete -> $SSD_DEST"
  return 0
}

# ── Phase 3: Cleanup local originals ─────────────────────────────────────────
phase_cleanup() {
  echo ""
  echo "[ Phase 3 ] Cleanup requested."

  # Verify the SSD backup actually exists and has content
  if [ ! -d "$SSD_DEST" ] || [ -z "$(ls -A "$SSD_DEST" 2>/dev/null)" ]; then
    echo ""
    echo "  ABORTED: Cannot confirm backup on SSD. Local files were NOT deleted."
    echo "  Make sure \"$SSD_NAME\" is mounted and the sync completed successfully."
    return 1
  fi

  local count
  count=$(wc -l < "$DELETE_LIST" | tr -d ' ')

  echo ""
  echo "  The following $count item(s) will be permanently deleted from your Mac:"
  echo ""
  while IFS= read -r path; do
    echo "    - $path"
  done < "$DELETE_LIST"
  echo ""
  echo "  The SSD backup at \"$SSD_DEST\" will be kept."
  echo ""
  read -r -p "  Type YES to confirm deletion: " confirm
  echo ""

  if [[ "$confirm" != "YES" ]]; then
    echo "  Cancelled. No files were deleted."
    return 0
  fi

  local deleted=0 failed=0
  while IFS= read -r path; do
    if [ -e "$path" ]; then
      if rm -rf "$path" 2>/dev/null; then
        echo "  DELETED  $path" >> "$LOG"
        (( deleted++ ))
        echo "  [-] $path"
      else
        echo "  FAILED   $path" >> "$LOG"
        (( failed++ ))
        echo "  [!] Could not delete: $path"
      fi
    fi
  done < "$DELETE_LIST"

  # Remove the local staging folder too
  rm -rf "$DEST"

  echo ""
  echo "  Deleted : $deleted item(s)"
  [ "$failed" -gt 0 ] && echo "  Failed  : $failed item(s) (check log)"
  echo "  Local staging folder removed: $DEST"
}

# ── Run ───────────────────────────────────────────────────────────────────────
print_header
phase_collect

if $CLEANUP; then
  if phase_sync; then
    phase_cleanup
  else
    echo "  Sync failed — local files were NOT deleted."
  fi
else
  phase_sync || true
  echo ""
  echo "Tip: run with --cleanup to also delete local originals after syncing:"
  echo "  bash collect_semester.sh --cleanup"
fi

echo ""
echo "========================================"
echo "  All done!"
echo "========================================"
echo ""
