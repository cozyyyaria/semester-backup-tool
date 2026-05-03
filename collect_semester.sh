#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# collect_semester.sh
# Collects Year-2 Semester-2 school content (Sept 2025 – Apr 2026) from
# the entire home directory into a single folder ready to archive.
# ---------------------------------------------------------------------------

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
HOME_DIR="$HOME"
DEST="$HOME/Y2S2_Semester_Backup"
LOG="$DEST/_collection_log.txt"

# Date window: Sept 1 2025 – Apr 30 2026
START_DATE="2025-09-01"
END_DATE="2026-04-30"

# Name patterns that indicate school work (case-insensitive)
# Matches: comp followed by digits, or words project/assignment/lab/term
NAME_PATTERNS=(
  "*[Cc][Oo][Mm][Pp][0-9]*"
  "*[Pp][Rr][Oo][Jj][Ee][Cc][Tt]*"
  "*[Aa][Ss][Ss][Ii][Gg][Nn][Mm][Ee][Nn][Tt]*"
  "*[Ll][Aa][Bb][_-]*"
  "*[Ll][Aa][Bb][0-9]*"
  "*[Tt][Ee][Rr][Mm][-_][Pp][Rr][Oo][Jj]*"
  "*[Ss][Cc][Hh][Oo][Oo][Ll]*"
  "*[Ss][Ee][Mm][Ee][Ss][Tt][Ee][Rr]*"
  "*labtest*"
  "*[Ff][Ii][Nn][Aa][Ll][-_][Pp][Rr][Oo][Jj]*"
  "*[Ff][Ii][Nn][Aa][Ll][-_][Rr][Ee][Pp][Oo][Rr][Tt]*"
  "*[Ww][Ee][Ee][Kk][Ll][Yy][-_][Pp][Rr][Oo][Gg][Rr][Ee][Ss][Ss]*"
  "*[Mm][Ii][Dd][Tt][Ee][Rr][Mm]*"
  "*[Ss][Ee][Nn][Ee][Cc][Aa]*"
)

# Directories to always skip (system/cache noise)
SKIP_DIRS=(
  "$HOME/Library"
  "$HOME/.Trash"
  "$HOME/node_modules"
  "$HOME/.npm"
  "$HOME/.cache"
  "$HOME/.git"
)

# ── Helpers ──────────────────────────────────────────────────────────────────
in_date_range() {
  local file="$1"
  local mtime
  mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null || echo "0000-00-00")
  [[ "$mtime" > "$START_DATE" || "$mtime" == "$START_DATE" ]] && \
  [[ "$mtime" < "$END_DATE"   || "$mtime" == "$END_DATE"   ]]
}

copy_item() {
  local src="$1"
  # Compute a relative path from HOME so the folder structure is preserved
  local rel="${src#$HOME_DIR/}"
  local dst_dir="$DEST/$(dirname "$rel")"
  mkdir -p "$dst_dir"
  cp -R "$src" "$dst_dir/" 2>/dev/null && \
    echo "COPIED  $rel" >> "$LOG" || \
    echo "FAILED  $rel" >> "$LOG"
}

build_skip_prune() {
  local args=()
  for d in "${SKIP_DIRS[@]}"; do
    args+=( -path "$d" -prune -o )
  done
  printf '%s\n' "${args[@]}"
}

# ── Setup ────────────────────────────────────────────────────────────────────
mkdir -p "$DEST"
echo "=== Y2S2 Collection Log  $(date) ===" > "$LOG"
echo "Source      : $HOME_DIR"              >> "$LOG"
echo "Destination : $DEST"                  >> "$LOG"
echo "Date window : $START_DATE – $END_DATE" >> "$LOG"
echo "========================================" >> "$LOG"

echo ""
echo "Starting scan of $HOME_DIR ..."
echo "Output folder: $DEST"
echo ""

# ── Main scan ────────────────────────────────────────────────────────────────
FOUND=0
SKIPPED=0

# Build the -name OR chain for find
build_name_expr() {
  local expr=()
  local first=true
  for pat in "${NAME_PATTERNS[@]}"; do
    if $first; then
      expr+=( -name "$pat" )
      first=false
    else
      expr+=( -o -name "$pat" )
    fi
  done
  printf '%s\n' "${expr[@]}"
}

# Use find with pruning, then filter by date in shell
while IFS= read -r -d '' item; do
  # Skip anything inside the destination folder itself
  [[ "$item" == "$DEST"* ]] && continue

  if in_date_range "$item"; then
    copy_item "$item"
    (( FOUND++ ))
    echo "  [+] ${item#$HOME_DIR/}"
  else
    (( SKIPPED++ ))
    echo "  [ ] SKIPPED (date out of range): ${item#$HOME_DIR/}" >> "$LOG"
  fi
done < <(
  find "$HOME_DIR" \
    -path "$HOME/Library" -prune -o \
    -path "$HOME/.Trash" -prune -o \
    -path "$HOME/.npm" -prune -o \
    -path "$HOME/.cache" -prune -o \
    -path "$HOME/node_modules" -prune -o \
    -path "$DEST" -prune -o \
    \( \
      -name "*[Cc][Oo][Mm][Pp][0-9]*" -o \
      -name "*[Pp][Rr][Oo][Jj][Ee][Cc][Tt]*" -o \
      -name "*[Aa][Ss][Ss][Ii][Gg][Nn][Mm][Ee][Nn][Tt]*" -o \
      -name "*[Ll][Aa][Bb][_-]*"      -o \
      -name "*[Ll][Aa][Bb][0-9]*"     -o \
      -name "*labtest*"               -o \
      -name "*[Tt][Ee][Rr][Mm][-_][Pp]*" -o \
      -name "*[Ff][Ii][Nn][Aa][Ll][-_][Pp][Rr][Oo][Jj]*" -o \
      -name "*[Ff][Ii][Nn][Aa][Ll][-_][Rr][Ee][Pp][Oo][Rr][Tt]*" -o \
      -name "*[Mm][Ii][Dd][Tt][Ee][Rr][Mm]*" -o \
      -name "*[Ss][Ee][Nn][Ee][Cc][Aa]*" -o \
      -name "*[Ww][Ee][Ee][Kk][Ll][Yy][-_][Pp][Rr][Oo][Gg]*" \
    \) \
    -print0 2>/dev/null
)

# ── Also copy known school top-level folders (they may predate the window) ──
echo ""
echo "Checking known top-level school folders..."
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

for folder in "${KNOWN_FOLDERS[@]}"; do
  src="$HOME_DIR/$folder"
  if [ -e "$src" ]; then
    mkdir -p "$DEST/top-level-projects"
    cp -R "$src" "$DEST/top-level-projects/" 2>/dev/null && \
      echo "COPIED  top-level/$folder" >> "$LOG" && \
      echo "  [+] $folder (top-level known folder)" || \
      echo "FAILED  top-level/$folder" >> "$LOG"
    (( FOUND++ ))
  fi
done

# ── Desktop & Downloads school content (catch anything date-missed) ──
echo ""
echo "Checking Desktop for school content..."
for src in \
  "$HOME/Desktop/COMP2139-ICE" \
  "$HOME/Desktop/Afterthebeep proj" \
  "$HOME/Desktop/Website Project 2025" \
  "$HOME/Desktop/assignment3" \
  "$HOME/Desktop/comp1202" \
  "$HOME/Desktop/lab_wk4" \
  "$HOME/Desktop/2025" \
  "$HOME/Desktop/assignment2comp1239" \
; do
  if [ -e "$src" ]; then
    mkdir -p "$DEST/Desktop"
    cp -R "$src" "$DEST/Desktop/" 2>/dev/null && \
      echo "COPIED  Desktop/$(basename "$src")" >> "$LOG" && \
      echo "  [+] Desktop/$(basename "$src")" || true
    (( FOUND++ ))
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  Done!"
echo "  Items copied  : $FOUND"
echo "  Date-skipped  : $SKIPPED (see log)"
echo "  Output folder : $DEST"
echo "  Log file      : $LOG"
echo "========================================"
echo ""
echo "Next step: plug in your external SSD and run:"
echo "  rsync -av --progress \"$DEST/\" /Volumes/X10 Pro/Y2S2_Semester_Backup/"
echo ""
