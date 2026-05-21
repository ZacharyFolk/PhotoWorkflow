# PhotoWorkflow

A three-script pipeline for moving photos from camera to post — triage a messy inbox, hand-pick winners in Darktable, send them to DxO for editing, then frame and export for Instagram or web.

---

## The workflow

```
/mnt/photos/inbox          ← raw dump (camera cards, phone, scans)
        │
        ▼
  photo-triage.py          ← scan, detect source, dedupe, organize into archive
        │
        ▼
/mnt/photos/archive        ← clean, date-organized library
        │
  Browse in Darktable
  tag keepers green
        │
        ▼
  send_to_dxo.lua          ← copies green images to /mnt/photos/working/
  (Darktable plugin)         relabels them blue so you know they've been queued
        │
        ▼
  Open DxO PureRAW / PhotoLab
  point it at /mnt/photos/working/
  edit → export to /mnt/photos/exports/
        │
        ▼
  photoframe.sh            ← adds mat + inner rule, resizes for target
        │
        ▼
/mnt/photos/exports/framed/   ← grab from phone or Windows → post
        │
        ▼
  ✕ Clear working folder   ← back in Darktable: wipe /mnt/photos/working/
                              ready for the next batch
```

---

## Color label key (Darktable)

| Color  | Meaning                              |
|--------|--------------------------------------|
| Green  | Ready to send to DxO                 |
| Blue   | Sent to DxO — queued for editing     |
| Purple | Done — exported from DxO (set manually) |
| Yellow | Ignored throughout the pipeline      |

---

## Scripts

### 1. `photo-triage.py` — Inbox cleanup

Scans a folder of photos, reads EXIF metadata with `exiftool`, detects the source camera, finds duplicates, and organizes everything into a clean date-based archive. **Never modifies or deletes originals** — it copies (or optionally moves) by default.

**Dependencies**

```bash
sudo apt install exiftool
pip3 install tqdm          # optional — progress bar
```

**Archive structure produced**

```
archive/
  digital/nikon/2024/2024-03/
  digital/ricoh/2024/2024-03/
  phone/2024/2024-03/
  film-scan/scanned-2024-03/
  video/2024/2024-03/
  unknown/no-date/
```

**Usage**

```bash
# Step 1: scan and report only — touches nothing
python3 photo-triage.py --scan /mnt/photos/inbox --report

# Step 2: organize into archive (copy, originals untouched)
python3 photo-triage.py --scan /mnt/photos/inbox --organize --dest /mnt/photos/archive

# Find and flag duplicate files
python3 photo-triage.py --scan /mnt/photos/inbox --dupes

# Full run: report + organize + dedup
python3 photo-triage.py --scan /mnt/photos/inbox --report --organize --dupes --dest /mnt/photos/archive

# Move instead of copy (after culling, when space is tight — prompts YES confirmation)
python3 photo-triage.py --scan /mnt/photos/inbox --organize --move --dest /mnt/photos/archive
```

Always generates a `triage_report_YYYYMMDD_HHMMSS.csv` in the current directory listing every file, its detected source, date, and destination path.

---

### 2. `send_to_dxo.lua` — Darktable → DxO handoff

A Darktable Lua plugin that adds a **DxO Workflow** panel to the Lighttable left sidebar with two buttons.

**Install**

```bash
cp send_to_dxo.lua ~/.config/darktable/lua/

# Add to ~/.config/darktable/luarc:
require "send_to_dxo"
```

**Send green to DxO**

- Scans your entire Darktable library
- Finds every green-labeled image
- Copies those files to `/mnt/photos/working/`
- Relabels them blue — you can see at a glance what's been queued and what hasn't
- Shows a summary in Darktable's notification bar

**Clear working folder**

Wipes `/mnt/photos/working/` so you can start fresh for the next batch.

**Configuration** (top of the file)

```lua
local WORKING_DIR  = "/mnt/photos/working"   -- staging folder for DxO
local SOURCE_COLOR = 2   -- green  = ready to send
local QUEUED_COLOR = 3   -- blue   = sent, awaiting edit
local DONE_COLOR   = 4   -- purple = edited and exported (set manually)
```

---

### 3. `photoframe.sh` — Frame and export

Adds a mat and inner border rule to DxO exports, resizes for the target platform, and optionally adds a subtle text label (filename or custom text). Uses ImageMagick.

**Dependencies**

```bash
sudo apt install imagemagick
```

**Usage**

```bash
# Frame all exports for Instagram (square)
./photoframe.sh -p instagram-square ./exports/*.jpg

# Portrait format — best feed reach
./photoframe.sh -p instagram-portrait ./exports/*.jpg

# Landscape photo in portrait canvas (gallery look), cream mat
./photoframe.sh -p instagram-lap ./exports/landscape_shot.jpg

# Same but dark mat — suits moody/night work
./photoframe.sh -p instagram-lap-dark ./exports/*.jpg

# Web output (≤2400px, keeps EXIF)
./photoframe.sh -p web -o ~/site/photos ./exports/*.tif

# Web output, no borders (CMS / press kit)
./photoframe.sh -p web-clean -n ./exports/press_kit/*.jpg

# Custom label instead of filename
./photoframe.sh -p instagram-portrait -t "yoursite.com" ./exports/*.jpg

# No label at all
./photoframe.sh -p instagram-square -n ./exports/*.jpg
```

**Profiles**

| Profile              | Canvas     | Mat style             | EXIF |
|----------------------|------------|-----------------------|------|
| `instagram-square`   | 1080×1080  | Cream mat, fits any ratio | Stripped |
| `instagram-portrait` | 1080×1350  | Cream mat, 4:5 (best reach) | Stripped |
| `instagram-landscape`| 1080×566   | Cream mat, cinematic 1.91:1 | Stripped |
| `instagram-lap`      | 1080×1350  | Landscape in portrait, cream | Stripped |
| `instagram-lap-dark` | 1080×1350  | Landscape in portrait, dark | Stripped |
| `web`                | ≤2400px    | Cream mat, proportional | Kept |
| `web-clean`          | ≤2400px    | No borders, optimised | Kept |

Output goes to `./framed/` by default. Use `-o <dir>` to change it.

**Other options**

```
--overwrite     Replace existing output files
--dry-run       Print ImageMagick commands without running them
-v, --verbose   Show the full command per file
```

---

## Folder layout

```
/mnt/photos/
  inbox/          ← dump from camera cards / phone
  archive/        ← organized by source + date (photo-triage output)
  working/        ← staging area for DxO (send_to_dxo.lua writes here)
  exports/        ← DxO output
  exports/framed/ ← photoframe.sh output, ready to post
```

---

## Requirements summary

| Tool        | Install                          | Used by            |
|-------------|----------------------------------|--------------------|
| exiftool    | `sudo apt install exiftool`      | photo-triage.py    |
| tqdm        | `pip3 install tqdm`              | photo-triage.py (optional) |
| Darktable   | darktable.org                    | send_to_dxo.lua    |
| ImageMagick | `sudo apt install imagemagick`   | photoframe.sh      |
| DxO         | dxo.com                          | manual step        |
