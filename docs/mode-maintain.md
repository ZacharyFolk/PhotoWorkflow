# Mode: Maintain

Backups, cleanup, archive hygiene. The boring but critical stuff that keeps the system reliable.

---

## Backup Strategy (The Most Important Thing)

You have 700+ GB of irreplaceable work. Without a backup strategy you are one drive failure away from losing all of it. **This is the single most important thing on this list.**

### The 3-2-1 Rule

- **3 copies** of important data
- On **2 different media** (e.g., server SSD and external HDD)
- With **1 offsite** (cloud or a drive kept somewhere else)

### Practical Setup

**Copy 1 — Live data on the server**
Your working library at `/mnt/photos/`.

**Copy 2 — External drive, rsync nightly**

Plug in an external USB drive. Mount it (e.g., at `/mnt/backup`). Set up nightly sync:

```bash
sudo crontab -e
```

Add:

```
0 3 * * * rsync -avh --delete /mnt/photos/ /mnt/backup/photos/ >> /var/log/photo-backup.log 2>&1
```

Runs every night at 3 AM. The `--delete` flag mirrors deletions too (so if you delete something on the live server it's removed from backup) — omit it if you want to keep deleted files in backup as a safety net.

**Copy 3 — Offsite**

Options:
- **Backblaze B2** — ~$6/month for 1 TB, simple CLI tool, encryption at rest
- **rclone to cloud** — works with Backblaze, Wasabi, Google Drive, etc.
- **Second physical drive** kept at a friend's house or office — cheapest but requires manual updates

For Backblaze B2 nightly sync:

```bash
# Install rclone
sudo apt install rclone -y
rclone config    # interactive setup for Backblaze B2

# Add to crontab
0 4 * * * rclone sync /mnt/photos/ b2:zac-photos-backup --log-file /var/log/photo-cloud-backup.log
```

### Verify Backups Work

Once a month, restore a random file from backup to confirm it actually works:

```bash
# Pick a random file from backup
ls /mnt/backup/photos/archive/digital/nikon/2024/2024-06/ | head -1

# Open it, verify it's intact
```

A backup you've never restored from is just a hope, not a backup.

---

## Cleaning Up the Library

### Remove macOS junk files

macOS leaves hidden `._*` files everywhere. They clutter the archive and confuse Darktable. Periodically:

```bash
# Count first
find /mnt/photos -name "._*" | wc -l

# Then delete
find /mnt/photos -name "._*" -delete
```

### Remove Thumbs.db (Windows junk)

Same for Windows:

```bash
find /mnt/photos -name "Thumbs.db" -delete
find /mnt/photos -name "desktop.ini" -delete
```

### Find orphaned XMP files

Sidecar XMP files without matching photos:

```bash
find /mnt/photos -name "*.xmp" | while read xmp; do
  photo="${xmp%.xmp}"
  [[ ! -f "$photo" ]] && echo "Orphan: $xmp"
done
```

Review the list. Delete with care — XMP files contain your edit history.

### Find duplicates with fdupes

After a triage pass, check for any leftover duplicates:

```bash
sudo apt install fdupes -y

# Summary
fdupes -r -m /mnt/photos/archive

# Full list to file for review
fdupes -r /mnt/photos/archive > dupes.txt
wc -l dupes.txt
```

Review `dupes.txt` and decide what to delete. Don't use `fdupes -d` blindly — review first.

---

## Clearing the Working Folder

After a DxO editing session, `/mnt/photos/working/` is full of staged files. Clear it manually or use the **Clear working folder** button in Darktable's DxO Workflow panel.

Originals are safe in `archive/` — `working/` is just a temporary copy.

```bash
rm -f /mnt/photos/working/*
```

---

## Clearing Old Exports

`exports/` can grow large since it holds DxO output. Move processed batches to a deeper archive every few weeks:

```bash
# Move everything older than 30 days to archive
find /mnt/photos/exports -type f -mtime +30 \
  -exec mv {} /mnt/photos/archive/old-exports/ \;
```

Or just review and delete what you no longer need.

---

## Film Scan Manual Sorting

Film scans landed in `/mnt/photos/archive/film-scan/scanned-YYYY-MM/` organized by scan date, not shoot date. When you have time:

1. Open a scanned-YYYY-MM folder
2. Identify which film roll each batch came from
3. Rename the folder to reflect the actual shoot:
   - `2023-07-coney-island-tri-x`
   - `2024-01-pdx-portra-400`
   - etc.

This is manual work — only you know what's on each roll. Not blocking, just a rainy-day project.

While you're at it, fix any old filename issues (spaces, parentheses, `Untitled` names from SilverFast).

---

## Checking Disk Space

```bash
df -h /mnt/photos
```

When you're getting tight (< 50 GB free), it's time to either:
- Move old exports to backup
- Cull harder — delete more rejects from `archive/`
- Add a bigger drive

---

## Darktable Database Maintenance

The Darktable database can bloat over time. Once every few months:

In Darktable: **Selected images → Compress database** (look under file menu or right-click).

Or from the command line:

```bash
sqlite3 ~/.config/darktable/library.db "VACUUM;"
```

Reclaims space and speeds up queries.

---

## Updating Software

### Darktable (via PPA, will update with apt)

```bash
sudo apt update
sudo apt upgrade darktable -y
```

### System packages

```bash
sudo apt update && sudo apt upgrade -y
```

After a Darktable major version update, your existing thumbnails may not be reusable — they'll regenerate automatically as needed.

---

## Periodic Health Check

Monthly review:

| Check | Command / where |
|---|---|
| Disk space | `df -h /mnt/photos` |
| Backup ran | `tail /var/log/photo-backup.log` |
| Cloud backup ran | `tail /var/log/photo-cloud-backup.log` |
| Darktable database size | `ls -lh ~/.config/darktable/library.db` |
| Orphaned files | The grep commands above |
| Random restore test | Pick a file from backup, open it |

Block out 30 minutes once a month for this. Cheap insurance.

---

## What Happens When Something Breaks?

Worst-case scenarios and recovery:

**Server drive dies:**
Buy a new drive, restore from external backup with `rsync /mnt/backup/photos/ /mnt/photos/`. Tens of minutes to a few hours depending on size.

**Backup drive fails too:**
Restore from cloud backup. Slower (limited by internet upload speed) but everything's there.

**Darktable database corrupted:**
Your edits are safe in XMP sidecars next to each photo. Delete the database, reimport the library — Darktable reads the XMPs and your ratings/edits come back.

**Accidentally deleted a folder:**
If the daily backup ran without `--delete` flag, it's still in backup. With `--delete` you have 24 hours before the next backup syncs the deletion.
