#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# collect_semester.sh
# Scans your Mac for semester school files, syncs them to your SSD,
# and optionally deletes the local originals to free up space.
#
# Usage:
#   bash collect_semester.sh            # collect + sync only
#   bash collect_semester.sh --cleanup  # collect + sync + delete local files
#   bash collect_semester.sh --setup    # configure a new semester
# ---------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/semester.conf"

# ── Setup wizard ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--setup" ]]; then
  echo ""
  echo "========================================"
  echo "  Semester Backup — Setup"
  echo "========================================"
  echo ""
  read -r -p "  Semester label (e.g. Y3S1, Y3S2): " label
  read -r -p "  Start date  (YYYY-MM-DD):          " start
  read -r -p "  End date    (YYYY-MM-DD):           " end
  read -r -p "  SSD name    [X10 Pro]:              " ssd
  ssd="${ssd:-X10 Pro}"
  echo ""
  echo "  Enter your course codes, space-separated."
  echo "  Example: COMP3044 COMP3087 COMP3152"
  echo "  (The script already finds comp+any number automatically."
  echo "   Add codes here only if you want to search by full name.)"
  read -r -p "  Courses (optional): " courses
  echo ""
  echo "  Enter extra folder or project names to always include."
  echo "  Example: afterthebeep my-portfolio nch-companion"
  read -r -p "  Extra names (optional): " extras
  {
    echo "SEMESTER_LABEL=\"${label:-Semester}\""
    echo "START_DATE=\"$start\""
    echo "END_DATE=\"$end\""
    echo "SSD_NAME=\"$ssd\""
    echo "COURSES=\"${courses:-}\""
    echo "EXTRA_NAMES=\"${extras:-}\""
  } > "$CONF"
  echo ""
  echo "  Saved! Backup folder: ${label:-Semester}_Semester_Backup"
  echo "  Run:  bash collect_semester.sh"
  echo ""
  exit 0
fi

# ── Defaults (used when no semester.conf exists) ──────────────────────────────
BACKUP_FOLDER_NAME="Y2S2_Semester_Backup"
START_DATE="2025-09-01"
END_DATE="2026-04-30"
SSD_NAME="X10 Pro"
COURSES=""
EXTRA_NAMES=""

# ── Load semester.conf if it exists (overrides defaults above) ────────────────
if [ -f "$CONF" ]; then
  # shellcheck source=/dev/null
  source "$CONF"
  BACKUP_FOLDER_NAME="${SEMESTER_LABEL}_Semester_Backup"
fi

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

# ── Internal config ───────────────────────────────────────────────────────────
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
    echo "$src"         >> "$DELETE_LIST"
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
  [ -n "$COURSES"    ] && echo "  Courses  : $COURSES"
  [ -n "$EXTRA_NAMES"] && echo "  Extras   : $EXTRA_NAMES"
  echo "  Cleanup  : $CLEANUP"
  echo "========================================"
  echo ""
}

# ── Build find name-pattern arguments ─────────────────────────────────────────
# Starts with the original hardcoded patterns, then appends anything from config
build_name_patterns() {
  NAME_ARGS=(
    \(
      # Original patterns — always on
      -iname "*comp[0-9]*"
      -o -iname "*project*"
      -o -iname "*assignment*"
      -o -iname "lab[0-9]*"
      -o -iname "lab_*"
      -o -iname "lab-*"
      -o -iname "*labtest*"
      -o -iname "*term-proj*"
      -o -iname "*term_proj*"
      -o -iname "*final-proj*"
      -o -iname "*final_proj*"
      -o -iname "*final-report*"
      -o -iname "*final_report*"
      -o -iname "*weekly-progress*"
      -o -iname "*weekly_progress*"
      -o -iname "*midterm*"
      -o -iname "*seneca*"
  )

  # Course codes from setup (e.g. COMP3044 → finds "COMP3044-lab1", "comp3044_assignment" etc.)
  for course in $COURSES; do
    NAME_ARGS+=( -o -iname "*${course}*" )
  done

  # Extra names from setup
  for name in $EXTRA_NAMES; do
    NAME_ARGS+=( -o -iname "*${name}*" )
  done

  NAME_ARGS+=( \) )
}

# ── Phase 1: Collect ──────────────────────────────────────────────────────────
phase_collect() {
  mkdir -p "$DEST"
  > "$DELETE_LIST"
  {
    echo "=== Collection Log  $(date) ==="
    echo "Semester    : $BACKUP_FOLDER_NAME"
    echo "Courses     : ${COURSES:-default patterns only}"
    echo "Extras      : ${EXTRA_NAMES:-none}"
    echo "Window      : $START_DATE – $END_DATE"
    echo "Destination : $DEST"
    echo "========================================"
  } > "$LOG"

  build_name_patterns

  echo "[ Phase 1 ] Scanning $HOME_DIR ..."
  echo ""

  local found=0 skipped=0

  while IFS= read -r -d '' item; do
    [[ "$item" == "$DEST"* ]] && continue
    if in_date_range "$item"; then
      if copy_item "$item"; then
        (( found++ ))
        echo "  [+] ${item#$HOME_DIR/}"
      fi
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
      -path "$DEST"                -prune -o \
      -name "node_modules"         -prune -o \
      -name ".git"                 -prune -o \
      -name "bin"                  -prune -o \
      -name "obj"                  -prune -o \
      "${NAME_ARGS[@]}"            -print0 \
      2>/dev/null
  )

  # Known top-level folders (always included regardless of date)
  echo ""
  echo "[ Phase 1 ] Checking known top-level folders..."

  # Merge KNOWN_FOLDERS with any EXTRA_NAMES that are root-level folders
  local all_extras=( "${KNOWN_FOLDERS[@]}" )
  for name in $EXTRA_NAMES; do
    # Only add if not already listed and exists at root level
    local already=false
    for k in "${KNOWN_FOLDERS[@]}"; do [[ "$k" == "$name" ]] && already=true; done
    $already || all_extras+=( "$name" )
  done

  for folder in "${all_extras[@]}"; do
    local src="$HOME_DIR/$folder"
    [ -e "$src" ] || continue
    mkdir -p "$DEST/top-level-projects"
    if cp -R "$src" "$DEST/top-level-projects/" 2>/dev/null; then
      echo "COPIED  top-level/$folder" >> "$LOG"
      echo "$src" >> "$DELETE_LIST"
      (( found++ ))
      echo "  [+] $folder"
    fi
  done

  # Known Desktop folders
  echo ""
  echo "[ Phase 1 ] Checking Desktop folders..."

  local all_desktop=( "${DESKTOP_FOLDERS[@]}" )
  for name in $EXTRA_NAMES; do
    local already=false
    for k in "${DESKTOP_FOLDERS[@]}"; do [[ "$k" == "$name" ]] && already=true; done
    $already || all_desktop+=( "$name" )
  done

  for folder in "${all_desktop[@]}"; do
    local src="$HOME/Desktop/$folder"
    [ -e "$src" ] || continue
    mkdir -p "$DEST/Desktop"
    if cp -R "$src" "$DEST/Desktop/" 2>/dev/null; then
      echo "COPIED  Desktop/$folder" >> "$LOG"
      echo "$src" >> "$DELETE_LIST"
      (( found++ ))
      echo "  [+] Desktop/$folder"
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
    return 1
  fi

  mkdir -p "$SSD_DEST"
  rsync -av --progress "$DEST/" "$SSD_DEST/"
  echo ""
  echo "  Sync complete → $SSD_DEST"
  return 0
}

# ── Phase 3: Cleanup local originals ─────────────────────────────────────────
phase_cleanup() {
  echo ""
  echo "[ Phase 3 ] Cleanup requested."

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

  [[ "$confirm" != "YES" ]] && { echo "  Cancelled. No files were deleted."; return 0; }

  local deleted=0 failed=0
  while IFS= read -r path; do
    if [ -e "$path" ]; then
      if rm -rf "$path" 2>/dev/null; then
        echo "DELETED  $path" >> "$LOG"
        (( deleted++ ))
        echo "  [-] $path"
      else
        echo "FAILED   $path" >> "$LOG"
        (( failed++ ))
        echo "  [!] Could not delete: $path"
      fi
    fi
  done < "$DELETE_LIST"

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
  phase_sync && phase_cleanup || echo "  Sync failed — local files were NOT deleted."
else
  phase_sync || true
  echo ""
  echo "  Tip: run with --cleanup to also delete local originals after syncing:"
  echo "    bash collect_semester.sh --cleanup"
fi

echo ""
echo "========================================"
echo "  All done!"
echo "========================================"
echo ""
