# Mode: Edit

When you have a batch of green-labeled picks and you're ready to process them.

---

## Two Editing Paths

**Most images → DxO PhotoLab on Windows.**
DxO is your primary editor. DeepPRIME XD noise reduction, best-in-class lens corrections, fast results.

**Some images → Darktable directly.**
For clean low-ISO shots where DxO's strengths don't matter — landscapes in good light, studio work, etc. Edit in Darktable and skip the DxO trip.

---

## Path 1 — Edit in DxO (Main Path)

### Step 1: Send picks to DxO

In Darktable, open the **DxO Workflow** panel in the Lighttable left sidebar.

Click **⟶ Send green to DxO**. The Lua script:

1. Scans the entire library for green-labeled images
2. Copies them to `/mnt/photos/working/`
3. Relabels each one **blue** (queued for DxO)
4. Shows a summary at the bottom of Darktable

Now `/mnt/photos/working/` contains your whole batch as a flat folder — no nested year/month structure to navigate.

### Step 2: Open DxO

DxO runs on Windows. Point it at `Z:\working\` (your mapped Samba drive).

All your picks are right there. Browse, edit one at a time.

### Step 3: DxO Editing Workflow

For each image:

| Tab | What to do |
|---|---|
| **Detail** | Enable **DeepPRIME XD** noise reduction. The preview renders in the bottom-right corner. Zoom to 100% to evaluate. |
| **Light** | Verify lens corrections are auto-applied. Use Smart Lighting for tricky mixed-light scenes as a starting point. |
| Other tabs | Color, exposure, crop, etc. — whatever the image needs. |

### Step 4: Export from DxO

**File → Export to disk** with these settings (save as a preset):

| Preset 1: Master TIFF |  |
|---|---|
| Format | TIFF, 16-bit |
| Compression | LZW (lossless, smaller files) |
| Color space | Adobe RGB |
| Destination | `Z:\exports\` |
| Filename | `{ImageName}_master` |
| Resize | OFF |
| ICC Profile | Embed — ON |

| Preset 2: JPEG for Sharing |  |
|---|---|
| Format | JPEG |
| Quality | 92 |
| Color space | sRGB (required for web/social) |
| Destination | `Z:\exports\` |
| Filename | `{ImageName}_web` |
| Resize | Longest edge 3600px |

> **Filename hygiene matters.** DxO will sometimes name files like `Untitled (2) (3).tif` if you're not careful. Set explicit naming templates in your export presets — no spaces, no parentheses, no special characters. They break everything downstream.

### Step 5: Mark images Done

Back in Darktable, find the images you just edited (still blue-labeled). Select them, set the label to **purple** (`F10`).

Color flow complete: `green → blue → purple`.

### Step 6: Clear the working folder

When the batch is done, click **✕ Clear working folder** in the Darktable DxO Workflow panel. Resets `/mnt/photos/working/` to empty for the next batch.

The originals stay safe in `archive/` — `working/` is just a staging area.

---

## Path 2 — Edit Directly in Darktable

For images that don't need DxO's strengths.

### Open in Darkroom

Double-click any image in Lighttable. The Darkroom view opens.

### Recommended Module Order

Darktable processes modules in a fixed pipeline order. Work through them in this logical sequence:

| # | Module | What to do |
|---|---|---|
| 1 | **Exposure** | Set base exposure. `Ctrl`-drag in the image to adjust. Avoid clipping highlights unless intentional. |
| 2 | **White Balance** | Eyedropper on a neutral grey, or set to Camera reference if you used a grey card. |
| 3 | **Lens Correction** | Enable if not auto-enabled. Skip if DxO already corrected. |
| 4 | **Noise Reduction (Profiled)** | For moderate noise. Heavy noise → DxO instead. |
| 5 | **Filmic RGB** | Tone mapping. Adjust white/black exposure sliders. Leave contrast at default to start. |
| 6 | **Color Calibration** | Fine WB and channel mixing for tricky light. |
| 7 | **Tone Equalizer** | Luminosity-based dodging and burning. |
| 8 | **Local Contrast** | Micro-contrast / texture. Keep it subtle. |

### Save edits as Styles

For consistent looks across a shoot:

- Darkroom → bottom panel → **Styles → Create style from current settings**
- Name it descriptively: `Base - Scene Referred` or `High Contrast - Nikon D850`
- Apply to multiple images: Lighttable → select → right-click → **Styles → [your style]**

### Export from Darktable

Lighttable → right panel → **Export** (`Ctrl+E`)

Configure once, save as a preset:

| Setting | Value |
|---|---|
| Output location | `/mnt/photos/exports/` |
| File format | JPEG, Quality 92 |
| Max size | Longest edge 3600px |
| Color profile | sRGB IEC61966-2.1 |
| Filename | `$(FILE_NAME).jpg` |
| Output sharpening | Unsharp Mask 0.5 / 2 / 0 |

Mark images **purple** (`F10`) in Darktable when done.

---

## Filename Issues (Common Problem)

DxO sometimes generates messy filenames with spaces and parentheses (`strix (2) (5)_insta.jpg`). These break:

- `photoframe.sh` glob expansion
- Darktable thumbnail generation
- Many shell commands

### Prevention

Set DxO's filename template explicitly — no spaces or special chars. Use only `[a-zA-Z0-9_-]` characters.

### Cure (if it already happened)

Batch rename on the server:

```bash
cd /mnt/photos/exports

# Preview first
for f in *.jpg; do
  newname="${f// /_}"
  newname="${newname//(/}"
  newname="${newname//)/}"
  echo "$f → $newname"
done

# Actually rename
for f in *.jpg; do
  newname="${f// /_}"
  newname="${newname//(/}"
  newname="${newname//)/}"
  [[ "$f" != "$newname" ]] && mv "$f" "$newname"
done
```

---

## Done

You should now have edited files in `/mnt/photos/exports/`. Next: [mode-publish.md](mode-publish.md) to frame and share them.
