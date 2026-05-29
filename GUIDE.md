# Photo Workflow Guide

**Stack:** Ubuntu Server · Darktable (Windows) · DxO PhotoLab · ImageMagick  
**Primary machine:** Windows — accessing server via Samba (`\\192.168.x.x\PhotoWorkspace`)  
**Server user:** `Zac` · **Photos root:** `/mnt/photos/`

---

## Table of Contents

1. [Folder Structure](#1-folder-structure)
2. [Step 1 — Import: Getting Files onto the Server](#2-step-1--import-getting-files-onto-the-server)
3. [Step 2 — Triage: Organize the Inbox](#3-step-2--triage-organize-the-inbox)
4. [Step 3 — Adding a Shoot to Darktable](#4-step-3--adding-a-shoot-to-darktable)
5. [Step 4 — Culling](#5-step-4--culling)
6. [Step 5 — Sending Picks to DxO](#6-step-5--sending-picks-to-dxo)
7. [Step 6 — Editing in Darktable](#7-step-6--editing-in-darktable)
8. [Step 7 — Exporting from Darktable](#8-step-7--exporting-from-darktable)
9. [Step 8 — Framing with photoframe.sh](#9-step-8--framing-with-photoframesh)
10. [Step 9 — Collecting Finished Files on Windows](#10-step-9--collecting-finished-files-on-windows)
11. [Quick Reference Cheat Sheet](#11-quick-reference-cheat-sheet)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Folder Structure

```
/mnt/photos/
├── inbox/                        ← Raw files from card. READ-ONLY after import.
│   └── 2025-03-18_beach/         ← One folder per shoot
│
├── archive/                      ← Clean, date-organized library (photo-triage.py output)
│   ├── digital/nikon/2025/2025-03/
│   ├── digital/ricoh/2025/2025-03/
│   ├── phone/2025/2025-03/
│   ├── film-scan/scanned-2025-03/
│   └── video/2025/2025-03/
│
├── working/                      ← DxO staging area (send_to_dxo.lua writes here)
│
├── exports/                      ← DxO output lands here
│
└── ready/                        ← Framed files from photoframe.sh — grab from here
    ├── instagram-portrait/
    ├── instagram-square/
    ├── web/
    └── ...
```

### Samba Access from Windows

The entire `/mnt/photos/` root is shared as `PhotoWorkspace`.

| From Windows | Path |
|---|---|
| Full share | `\\192.168.x.x\PhotoWorkspace` |
| Inbox | `\\192.168.x.x\PhotoWorkspace\inbox\` |
| Working (DxO staging) | `\\192.168.x.x\PhotoWorkspace\working\` |
| Exports (DxO output) | `\\192.168.x.x\PhotoWorkspace\exports\` |
| Ready (finished files) | `\\192.168.x.x\PhotoWorkspace\ready\` |

> **Tip:** Map this as a network drive in Windows Explorer (right-click **This PC → Map network drive**). Pin `Z:\working\`, `Z:\exports\`, and `Z:\ready\` to Quick Access.

---

### Shoot Naming Convention

Format: `YYYY-MM-DD_description`

```
2025-03-18_downtown-portraits
2025-03-22_family-session-greenlake
2025-04-05_product-shoot-shoes
```

Lowercase, hyphens within the description, underscore between date and description.

---

## 2. Step 1 — Import: Getting Files onto the Server

### Option A — Drag & Drop via Windows Explorer

1. Insert your memory card (appears as `D:\DCIM\` or similar)
2. Open `Z:\inbox\` in another Explorer window
3. Create a new folder: `2025-03-18_description`
4. Copy all files from the card into that folder
5. Eject the card when done

---

### Option B — Darktable Copy & Import (Recommended)

Better than drag-and-drop — Darktable renames files consistently and creates the filmroll immediately.

**In Darktable:** Top bar → **Import** → **From camera / from memory card**

Configure these settings once — Darktable saves them:

| Setting | Value |
|---|---|
| **Base directory** | `Z:\inbox` |
| **Filmroll / sub-folder** | `$(EXIF_YEAR)-$(EXIF_MONTH)-$(EXIF_DAY)_$(JOBCODE)` |
| **File naming** | `$(EXIF_YEAR)$(EXIF_MONTH)$(EXIF_DAY)_$(SEQUENCE4).$(FILE_EXTENSION)` |
| **Override existing files** | OFF |
| **Create single filmroll** | ON |
| **Ignore JPEG if RAW exists** | ON |

At import time, type your shoot description into the **JOBCODE** field. This becomes the folder name suffix.

**Result:**
- Folder: `Z:\inbox\2025-03-18_downtown-portraits\`
- Files: `20250318_0001.nef`, `20250318_0002.nef`, ...
- Filmroll created in Darktable automatically

---

### After Import: Protect Your Originals

```bash
chmod -R 444 /mnt/photos/inbox/2025-03-18_downtown-portraits
```

Makes all files read-only. You can still open and view them — you just cannot overwrite or delete them by accident.

---

## 3. Step 2 — Triage: Organize the Inbox

`photo-triage.py` scans your inbox, reads EXIF metadata, detects which camera each file came from, finds duplicates, and copies everything into a clean date-organized archive. It never modifies originals.

**Dependencies (server):**
```bash
sudo apt install exiftool
pip3 install tqdm   # optional — progress bar
```

**Usage:**

```bash
# First: scan and report only — touches nothing
python3 photo-triage.py --scan /mnt/photos/inbox --report

# Review the generated CSV, then organize into archive
python3 photo-triage.py --scan /mnt/photos/inbox --organize --dest /mnt/photos/archive

# Flag and report duplicates
python3 photo-triage.py --scan /mnt/photos/inbox --dupes

# Full run
python3 photo-triage.py --scan /mnt/photos/inbox --report --organize --dupes --dest /mnt/photos/archive
```

Always generates a `triage_report_YYYYMMDD_HHMMSS.csv` showing every file, its detected source, date, and destination path. Review it before running `--organize`.

> **Film scans** are organized by scan date (not shoot date) under `film-scan/scanned-YYYY-MM/`. You will need to rename these manually by film roll.

---

## 4. Step 3 — Adding a Shoot to Darktable

Darktable indexes files where they sit and writes edits as `.xmp` sidecar files alongside the RAWs. It does not move your files.

### If you used Copy & Import (Option B)

The filmroll is already created. In **Lighttable**, look at the left panel under **Film Rolls** — the new import appears at the top.

### If you dragged files manually (Option A)

In **Lighttable:**
1. Click **Import** → **Add to library**
2. Navigate to `Z:\inbox\2025-03-18_description\`
3. Click **Import**

### Adding a batch from archive

After running `photo-triage.py` to move a new batch into `archive/`, tell Darktable about it the same way:

1. Click **Import** → **Add to library**
2. Navigate to the relevant folder inside `Z:\archive\`
3. Click **Import** (check **Import recursively** only if you want a whole year/month tree at once — but per-folder keeps filmrolls manageable)

---

### Pre-generating the thumbnail cache

After importing a large batch, Darktable will render thumbnails on demand as you scroll — which is slow. To build them all at once, run this on the server:

```bash
darktable-generate-cache --max-mip 2
```

This walks your entire library and pre-generates thumbnails into `~/.cache/darktable/`. The `--max-mip 2` flag covers the small, medium, and main Lighttable display sizes — everything you need for browsing and culling. For a large library it takes a while; run it in `tmux` or leave it overnight. Once done, scrolling through Lighttable is instant. You only pay this cost once per batch.

```bash
# Run inside tmux so it survives if your SSH session drops
tmux new -s thumbs
darktable-generate-cache --max-mip 2
# Ctrl+B then D to detach and leave it running
```

---

### One-Time Darktable Preferences

**Preferences** (gear icon, top right):

| Preference | Setting |
|---|---|
| **Storage → XMP sidecar files** | ON — edits exist as real files on disk, not only in the database |
| **Storage → On database change** | Automatically apply XMP — ON |
| **Lighttable → Number of images in filmroll** | 100–200 for faster culling |
| **Processing → Default workflow** | Scene-referred (filmic) |

---

## 5. Step 4 — Culling

Cull before editing anything. Two passes keeps it fast.

### Color Label Key

These labels drive the DxO handoff — use them consistently.

| Color | Key | Meaning |
|---|---|---|
| Green | `F8` | Pick — ready to send to DxO |
| Blue | (set automatically) | Sent to DxO — queued for editing |
| Purple | `F10` | Done — exported from DxO |
| Yellow | `F7` | Skip — ignored throughout the pipeline |

---

### Pass 1 — Reject Failures

Move through images quickly:

| Key | Action |
|---|---|
| `R` | Reject — out of focus, bad exposure, blinked eyes |
| `→` / `←` | Next / previous image |
| `Z` | Zoom in to check sharpness |

Work fast. When in doubt, leave it — you can reject later.

---

### Pass 2 — Rate the Keepers

Filter to hide rejected images (Filter → Reject → Hide rejected), then rate what remains:

| Key | Stars | Meaning |
|---|---|---|
| `F1` | ★ | Technically OK |
| `F2` | ★★ | Good — would share if nothing better |
| `F3` | ★★★ | Strong — editing this one |
| `F4` | ★★★★ | Best of session — portfolio candidate |

Filter to **3 stars and above**. That is your edit queue. Label those images **green** (`F8`) to mark them ready for DxO.

---

## 6. Step 5 — Sending Picks to DxO

`send_to_dxo.lua` adds a **DxO Workflow** panel to the Darktable Lighttable left sidebar.

### Install (once)

```bash
cp send_to_dxo.lua ~/.config/darktable/lua/

# Add to ~/.config/darktable/luarc:
require "send_to_dxo"
```

### Send green to DxO

Click **⟶ Send green to DxO** in the panel. This:

- Scans the entire Darktable library for green-labeled images
- Copies them to `/mnt/photos/working/`
- Relabels each one **blue** — so you can see in Darktable what's been queued and what hasn't
- Shows a summary in Darktable's notification bar

### Edit in DxO

1. Open DxO PhotoLab
2. Point it at `Z:\working\` — all your picks are there in one flat folder
3. Apply DeepPRIME XD noise reduction, lens corrections, Smart Lighting as needed
4. Export: **File → Export to disk**

| Setting | Value |
|---|---|
| **Format** | TIFF, 16-bit |
| **Color space** | Adobe RGB |
| **Output folder** | `Z:\exports\` |
| **Filename** | Keep original name or add `_dxo` suffix |
| **Resize** | OFF — full resolution at this stage |

### Clear working folder

When you're done with a batch, click **✕ Clear working folder** in the same Darktable panel. This wipes `/mnt/photos/working/` so the next batch starts clean. The originals are safe in `inbox/` — the working folder is just a temporary staging area.

> **Tip:** Mark images **purple** (`F10`) in Darktable once you've finished editing and exporting them from DxO. That closes the loop — green → blue → purple.

---

## 7. Step 6 — Editing in Darktable

For images that don't need DxO (clean light, low ISO), edit directly in Darktable. Double-click any image in Lighttable to open the **Darkroom**.

### Recommended Module Order

| # | Module | What to do |
|---|---|---|
| 1 | **Exposure** | Set base exposure. Hold `Ctrl` and drag in the image. Avoid clipping highlights unless intentional |
| 2 | **White Balance** | Eyedropper on a neutral grey, or **Camera reference** if you shot a grey card |
| 3 | **Lens Correction** | Enable if not auto-enabled. Skip if processed through DxO first |
| 4 | **Noise Reduction (Profiled)** | For moderate noise. For heavy noise, use DxO instead |
| 5 | **Filmic RGB** | Tone mapping. Adjust white/black exposure sliders. Leave contrast at default to start |
| 6 | **Color Calibration** | Fine white balance and channel mixing for tricky light |
| 7 | **Tone Equalizer** | Luminosity-based dodging and burning |
| 8 | **Local Contrast** | Micro-contrast / texture — keep it subtle |

### Saving Edits as Styles

Once you have a solid base edit, save it as a Style so you can apply it to similar shots instantly.

- Darkroom → bottom panel → **Styles → Create style from current settings**
- Name it clearly: `Base - Scene Referred` or `High Contrast - Nikon`
- Lighttable → select multiple images → right-click → **Styles → [your style]**

---

## 8. Step 7 — Exporting from Darktable

Use this for archive masters or for images edited entirely in Darktable (not via DxO).

**Open Export:** Lighttable → right panel → **Export** (or `Ctrl+E`)

### Export Preset — Archive Master (TIFF)

| Setting | Value |
|---|---|
| **Output location** | `Z:\exports\2025-03-18_description\` |
| **File format** | TIFF, 16-bit, LZW compression |
| **Color profile** | Adobe RGB |
| **Filename** | `$(FILE_NAME)_master.tif` |
| **Max size** | None — full resolution |

**Save preset as:** `→ Archive Master (TIFF)`

---

### Export Preset — Web / Social (JPEG)

Use this when exporting images for framing directly from Darktable (rather than from DxO).

| Setting | Value |
|---|---|
| **Output location** | `Z:\exports\` |
| **File format** | JPEG, Quality 92 |
| **Max size (longest edge)** | 3600px — gives photoframe.sh room to work |
| **Color profile** | sRGB IEC61966-2.1 |
| **Filename** | `$(FILE_NAME).jpg` |
| **Output sharpening** | Unsharp Mask: Amount 0.5, Radius 2, Threshold 0 |

**Save preset as:** `→ Web / Social (JPEG)`

---

## 9. Step 8 — Framing with photoframe.sh

`photoframe.sh` takes exports from `/mnt/photos/exports/` and adds a mat, inner border rule, and optional label. Run it manually on the server (or via SSH) after DxO or Darktable has finished exporting.

**Dependencies:**
```bash
sudo apt install imagemagick
```

**Usage:**

```bash
# Instagram portrait — 1080×1350, cream mat (best feed reach)
./photoframe.sh -p instagram-portrait -o /mnt/photos/ready/instagram-portrait /mnt/photos/exports/*.jpg

# Instagram square — 1080×1080, fits any aspect ratio
./photoframe.sh -p instagram-square -o /mnt/photos/ready/instagram-square /mnt/photos/exports/*.jpg

# Landscape in portrait canvas — gallery look, cream mat
./photoframe.sh -p instagram-lap -o /mnt/photos/ready/instagram-portrait /mnt/photos/exports/landscape.jpg

# Same but dark mat — moody / night work
./photoframe.sh -p instagram-lap-dark -o /mnt/photos/ready/instagram-portrait /mnt/photos/exports/night.jpg

# Web output — framed, ≤2400px, keeps EXIF
./photoframe.sh -p web -o /mnt/photos/ready/web /mnt/photos/exports/*.tif

# Web — no borders, just resized (CMS / press kit)
./photoframe.sh -p web-clean -o /mnt/photos/ready/web /mnt/photos/exports/*.jpg

# Custom label (e.g. your site URL) instead of filename
./photoframe.sh -p instagram-portrait -t "yoursite.com" -o /mnt/photos/ready/instagram-portrait /mnt/photos/exports/*.jpg

# No label at all
./photoframe.sh -p instagram-portrait -n -o /mnt/photos/ready/instagram-portrait /mnt/photos/exports/*.jpg
```

### Profiles

| Profile | Canvas | Mat | EXIF |
|---|---|---|---|
| `instagram-square` | 1080×1080 | Cream, fits any ratio | Stripped |
| `instagram-portrait` | 1080×1350 | Cream, 4:5 | Stripped |
| `instagram-landscape` | 1080×566 | Cream, cinematic 1.91:1 | Stripped |
| `instagram-lap` | 1080×1350 | Landscape in portrait, cream mat | Stripped |
| `instagram-lap-dark` | 1080×1350 | Landscape in portrait, dark mat | Stripped |
| `web` | ≤2400px | Cream mat, proportional | Kept |
| `web-clean` | ≤2400px | No borders | Kept |

---

## 10. Step 9 — Collecting Finished Files on Windows

Open `Z:\ready\` in Windows Explorer and navigate to the relevant subfolder.

| Profile used | Files in |
|---|---|
| Instagram portrait | `Z:\ready\instagram-portrait\` |
| Instagram square | `Z:\ready\instagram-square\` |
| Web | `Z:\ready\web\` |

Files are named the same as your DxO or Darktable exports, so they're traceable back to the source.

---

## 11. Quick Reference Cheat Sheet

| # | Step | What you do |
|---|---|---|
| 1 | **Import** | Drag card → `Z:\inbox\YYYY-MM-DD_description\` OR use Darktable Copy & Import |
| 2 | **Protect** | SSH: `chmod -R 444 /mnt/photos/inbox/SHOOT-NAME` |
| 3 | **Triage** | `python3 photo-triage.py --scan /mnt/photos/inbox --report --organize --dest /mnt/photos/archive` |
| 4 | **Add to Darktable** | Lighttable → click filmroll (or Import → Add to library) |
| 5 | **Cull Pass 1** | `R` = reject failures. Arrow keys to move. `Z` to zoom-check focus |
| 6 | **Cull Pass 2** | `F1`–`F4` for stars. Filter to 3+. Label keepers **green** (`F8`) |
| 7 | **Send to DxO** | Darktable DxO Workflow panel → **⟶ Send green to DxO** |
| 8 | **Edit in DxO** | Point DxO at `Z:\working\` → DeepPRIME XD → export TIFF to `Z:\exports\` |
| 9 | **Clear staging** | Darktable panel → **✕ Clear working folder** when the batch is done |
| 10 | **Frame** | `photoframe.sh -p instagram-portrait -o /mnt/photos/ready/instagram-portrait /mnt/photos/exports/*.jpg` |
| 11 | **Collect** | Open `Z:\ready\` → grab finished files |

---

## 12. Troubleshooting

| Problem | Fix |
|---|---|
| **photo-triage.py: exiftool not found** | `sudo apt install exiftool` |
| **send_to_dxo.lua not loading in Darktable** | Check `~/.config/darktable/luarc` contains `require "send_to_dxo"` and the file is in `~/.config/darktable/lua/` |
| **"Send green to DxO" sends nothing** | Confirm images are labeled green (`F8`) in Lighttable — not just starred |
| **DxO can't see files in working/** | Check Samba is running: `sudo systemctl status smbd`. Check `/mnt/photos/working/` ownership: `ls -la /mnt/photos/` |
| **ImageMagick font error in photoframe.sh** | `sudo apt install fonts-dejavu` — or list available fonts with `convert -list font` and update the font name in the script |
| **Colours look wrong on phone** | Ensure export color profile is **sRGB**, not Adobe RGB — Instagram and most phones expect sRGB |
| **Instagram rejects the file** | Must be JPEG. Confirm you used an `instagram-*` profile, not `web` or `web-clean` |
| **Darktable does not see new TIFF from DxO** | Right-click filmroll in left panel → **Rescan for new images** |
| **XMP sidecar not updating** | Preferences → confirm **Write sidecar XMP files** ON and **Automatically apply XMP** ON |
| **Samba access denied from Windows** | `sudo smbpasswd -a Zac` to ensure the user exists in Samba |

---

*Zac's photo server · `/mnt/photos/` · Samba share: `PhotoWorkspace`*
