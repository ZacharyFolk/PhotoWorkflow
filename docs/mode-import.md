# Mode: Import

When you have new photos to bring into the system — fresh from a memory card, an SD dump from your phone, or a folder of scans.

---

## Goal

Get raw files onto the server in a predictable place with consistent naming, ready to be triaged into the archive.

```
Memory card → /mnt/photos/inbox/YYYY-MM-DD_shoot-name/
```

---

## Shoot Folder Naming Convention

**Format:** `YYYY-MM-DD_description`

- Lowercase only
- Hyphens within the description
- Underscore between date and description
- Keep the description short but specific

**Examples:**
```
2025-03-18_downtown-portraits
2025-04-05_product-shoot-shoes
2025-07-12_street-pike-place
2025-09-22_family-greenlake
```

> **No spaces or parentheses.** They break everything downstream — Darktable thumbnail generation, `photoframe.sh`, shell glob expansion. Always sanitize at import time.

---

## Option A — Drag and Drop via Windows Explorer

Quickest for one-off imports:

1. Insert memory card — appears as `D:\DCIM\` or similar
2. Open `Z:\inbox\` in another Explorer window
3. Create a new folder using the naming convention: `2025-03-18_description`
4. Copy all files from the card into it
5. Eject the card

---

## Option B — Darktable Copy & Import (Recommended)

Better than drag-and-drop — renames files consistently as they come in, and creates the filmroll automatically.

### One-time setup (in Darktable via VNC)

**Top bar → Import → From camera / from memory card**

Configure these settings once — Darktable remembers them:

| Setting | Value |
|---|---|
| Base directory | `/mnt/photos/inbox` |
| Filmroll / sub-folder | `$(EXIF_YEAR)-$(EXIF_MONTH)-$(EXIF_DAY)_$(JOBCODE)` |
| File naming | `$(EXIF_YEAR)$(EXIF_MONTH)$(EXIF_DAY)_$(SEQUENCE4).$(FILE_EXTENSION)` |
| Override existing files | **OFF** — never overwrite raw files |
| Create single filmroll | **ON** |
| Ignore JPEG if RAW exists | **ON** — drop JPEGs if RAW+JPEG mode |

### At import time

In the import dialog, type your shoot description into the **JOBCODE** field (e.g., `downtown-portraits`). It becomes the folder suffix.

### Result

- Folder created: `/mnt/photos/inbox/2025-03-18_downtown-portraits/`
- Files renamed: `20250318_0001.nef`, `20250318_0002.nef`, ...
- Filmroll appears in Darktable Lighttable immediately

### Why EXIF_YEAR, not YEAR?

`$(YEAR)` uses today's date — the day you import. `$(EXIF_YEAR)` uses the date the photo was actually taken. Always use the `EXIF_*` variants so old cards imported weeks later still sort correctly.

---

## After Import: Lock the Originals

Once files are in `inbox/`, make them read-only so nothing can accidentally overwrite or delete them:

```bash
chmod -R 444 /mnt/photos/inbox/2025-03-18_downtown-portraits
```

You can still open them in Darktable, DxO, or any viewer. You just can't modify or delete them by accident.

---

## Then: Triage into the Archive

The `inbox/` is a holding area, not your permanent library. Use `photo-triage.py` to move shoots into the date-organized `archive/`:

```bash
# Always preview first
python3 /mnt/photos/photo-triage.py --scan /mnt/photos/inbox --report

# Review the CSV that's generated, then move into archive
python3 /mnt/photos/photo-triage.py \
  --scan /mnt/photos/inbox \
  --dest /mnt/photos/archive \
  --organize \
  --move \
  --report
```

`--move` (not copy) is appropriate when space is tight. Without it the script copies files leaving originals in `inbox/`.

See [reference.md](reference.md) for full `photo-triage.py` options.

---

## Special Cases

### Film scans (SilverFast)

Film scans don't have shoot dates in EXIF — they have *scan* dates. The triage script handles this by sorting them into `film-scan/scanned-YYYY-MM/` folders.

You'll need to manually rename scan folders by film roll (e.g., `roll-tri-x-2023-summer-coney`) when you have the bandwidth. The script can't do this — only you know what's on each roll.

### Phone photos

If files are HEIC (iPhone default), Darktable needs `libheif1` to read them. See [setup-server.md](setup-server.md). The triage script categorizes them under `phone/YYYY/`.

### macOS junk files

If you're importing from a Mac or a drive that's been on a Mac, you'll get hidden `._*` files. Clean them up after import:

```bash
find /mnt/photos/inbox -name "._*" -delete
```

These are macOS metadata sidecars, not real images. Safe to delete.

---

## Done

After triage, your new shoot lives in `/mnt/photos/archive/digital/nikon/2025/2025-03/`. Next, see [mode-cull.md](mode-cull.md) to rate and organize it.
