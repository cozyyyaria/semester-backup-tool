# Semester Backup Tool

A macOS shell script that scans your entire home directory for school-related files from the current semester, syncs them to your external SSD, and optionally deletes the local originals to free up space.

---

## Features

- Scans your whole home directory for school files
- Matches names containing: `comp` + course number, `project`, `assignment`, `lab`, `midterm`, `term-proj`, `final-report`, `weekly-progress`, `seneca`
- Filters by a configurable date range (set per semester)
- Preserves your original folder structure inside the backup
- Auto-syncs to your external SSD when it's plugged in
- `--cleanup` mode deletes local originals **only after** the SSD sync is confirmed
- Writes a full log of everything copied, skipped, and deleted

---

## Requirements

- macOS
- External SSD (default name in the script: `X10 Pro`)

---

## Usage

### Collect and sync only (safe — nothing is deleted):
```bash
bash collect_semester.sh
```

### Collect, sync, then delete local originals:
```bash
bash collect_semester.sh --cleanup
```

When `--cleanup` is used the script will:
1. Collect all matching school files into `~/Y2S2_Semester_Backup/`
2. Sync that folder to your SSD
3. Show you exactly which files will be deleted
4. Ask you to type `YES` to confirm before deleting anything
5. Remove the local originals and the staging folder

---

## Updating for a New Semester

Open `collect_semester.sh` and edit these four lines at the top:

```bash
BACKUP_FOLDER_NAME="Y3S1_Semester_Backup"   # new label
START_DATE="2026-09-01"                      # new semester start
END_DATE="2027-04-30"                        # new semester end
SSD_NAME="X10 Pro"                           # your SSD name (leave as-is if unchanged)
```

Also update the `KNOWN_FOLDERS` and `DESKTOP_FOLDERS` arrays to list any top-level project folders from the new semester.

---

## What Gets Collected

| Pattern | Example matches |
|---|---|
| `comp` + digits | `comp2152-termproject`, `COMP2139-ICE` |
| `project` | `afterthebeep_project`, `Website Project 2025` |
| `assignment` | `comp2152_assignment2`, `assignment3` |
| `lab` + digit or separator | `comp1235_lab5`, `lab_wk4` |
| `labtest` | `labtest1_comp1202` |
| `midterm` | `comp3044_midterm.pdf` |
| `final-proj` / `final-report` | `final-project-report.pdf` |
| `weekly-progress` | `Weekly-Progress-Report-1.docx` |
| `seneca` | any file mentioning Seneca |
| Top-level folders | explicitly listed in `KNOWN_FOLDERS` |
| Desktop folders | explicitly listed in `DESKTOP_FOLDERS` |

---

## Output Structure

```
~/Y2S2_Semester_Backup/
├── _collection_log.txt      ← full log of copied/skipped/deleted items
├── _to_delete.txt           ← internal list used by --cleanup
├── top-level-projects/      ← known root-level project folders
├── Desktop/                 ← known Desktop folders
└── Downloads/               ← files found under Downloads/
    └── ...                  ← (mirrors your original folder structure)
```

---

## SSD Sync Command (manual)

If you want to sync manually without rerunning the script:

```bash
rsync -av --progress ~/Y2S2_Semester_Backup/ "/Volumes/X10 Pro/Y2S2_Semester_Backup/"
```

---

## Semester Reference

| Semester | Folder Name | Start | End |
|---|---|---|---|
| Y2S2 | `Y2S2_Semester_Backup` | 2025-09-01 | 2026-04-30 |
| Y3S1 | `Y3S1_Semester_Backup` | 2026-09-01 | 2027-04-30 |
| Y3S2 | `Y3S2_Semester_Backup` | 2027-01-01 | 2027-04-30 |
