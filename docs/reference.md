# Reference

Folder layout, naming conventions, color labels, and complete script documentation.

---

## Folder Structure

```
/mnt/photos/
├── inbox/                          ← Raw imports. Lock as read-only after import.
│   └── 2025-03-18_shoot-name/
│
├── archive/                        ← Organized library (photo-triage.py output)
│   ├── digital/
│   │   ├── nikon/YYYY/YYYY-MM/
│   │   ├── ricoh/YYYY/YYYY-MM/
│   │   └── (other cameras)/
│   ├── phone/YYYY/YYYY-MM/         ← iPhone, Android, etc.
│   ├── film-scan/scanned-YYYY-MM/  ← By scan date, manual rename by roll later
│   ├── video/YYYY/YYYY-MM/
│   ├── unknown/                    ← Files with no usable EXIF
│   └── date-uncertain/             ← File mtime fallback (unreliable date)
│
├── working/                        ← DxO staging (Lua script writes here)
│
├── exports/                        ← DxO output, Darktable exports
│
├── drop/                           ← (Optional) watcher service input folders
│   ├── instagram-square/
│   ├── instagram-portrait/
│   ├── web/
│   └── web-clean/
│
└── ready/                          ← Framed, finished files for posting
    ├── instagram-square/
    ├── instagram-portrait/
    ├── instagram-landscape/
    ├── web/
    └── web-clean/
```

### What each folder is for

| Folder | Purpose | Contents |
|---|---|---|
| `inbox/` | Holding area for new imports | RAW files, just landed from cards |
| `archive/` | Permanent library | All your work, organized by date and source |
| `working/` | DxO staging | Flat folder, picks from a single batch |
| `exports/` | DxO/Darktable output | Edited TIFFs and JPEGs |
| `ready/` | Final output | Framed, ready to share |

---

## Shoot Folder Naming Convention

**Format:** `YYYY-MM-DD_description`

- Lowercase only
- Hyphens within the description
- Underscore between date and description
- **No spaces, no parentheses, no special characters**

### Examples

```
2025-03-18_downtown-portraits
2025-04-05_product-shoot-shoes
2025-07-12_street-pike-place
2025-09-22_family-greenlake
```

### Why no spaces or parens?

They break:
- Shell glob expansion
- Darktable's thumbnail generator
- `photoframe.sh` argument parsing
- Many basic Unix commands

Sanitize at import time. Pay the price once, not every time you touch a file.

---

## Darktable Color Label Workflow

The system runs on color labels. Use them consistently:

| Color | Shortcut | Meaning |
|---|---|---|
| **Red** | `F6` | Reserved — use however you want |
| **Yellow** | `F7` | Skip — ignored throughout the pipeline |
| **Green** | `F8` | **Pick** — ready to send to DxO |
| **Blue** | `F9` (or auto) | Sent to DxO — queued for editing |
| **Purple** | `F10` | **Done** — exported from DxO |

### The Flow

```
unrated  →  GREEN (pick)  →  BLUE (in DxO)  →  PURPLE (done)
                                  ↑
                          set automatically by Lua script
```

Yellow images are ignored by `send_to_dxo.lua`, by smart collections, and by visual scanning. Use it for shots you've decided against but don't want to outright reject.

---

## Star Rating Convention

| Stars | Meaning |
|---|---|
| ★ (`F1`) | Technically OK, maybe usable |
| ★★ (`F2`) | Good — would share if nothing better |
| ★★★ (`F3`) | Strong — definitely editing this one |
| ★★★★ (`F4`) | Best of the session — portfolio candidate |
| ★★★★★ (`F5`) | Exceptional — use sparingly |

**Reject** (`R`) for outright failures — out of focus, blinked eyes, etc.

Filter your edit queue to 3+ stars. Apply green label to picks.

---

## Scripts

### `photoframe.sh`

Adds borders and a label to images. Produces finished files for Instagram, web, print.

**Location:** `/usr/local/bin/photoframe`

**Usage:**
```bash
photoframe -p <profile> [options] <input_files>
```

**Profiles:**

| Profile | Canvas | Mat color | EXIF stripped |
|---|---|---|---|
| `instagram-square` | 1080×1080 | Cream | Yes |
| `instagram-portrait` | 1080×1350 | Cream | Yes |
| `instagram-landscape` | 1080×566 | Cream | Yes |
| `web` | ≤2400px | Cream | No |
| `web-clean` | ≤2400px | None | No |

**Options:**

| Flag | Description |
|---|---|
| `-p <name>` | Profile (required) |
| `-o <dir>` | Output directory (default: `./framed`) |
| `-t <text>` | Custom label text (default: filename) |
| `-n` | No label |
| `--overwrite` | Replace existing output files |
| `--dry-run` | Show commands without executing |
| `-v` | Verbose |
| `-h` | Help |

**Examples:**
```bash
# Instagram portrait, no label
photoframe -p instagram-portrait -n -o /mnt/photos/ready/instagram-portrait /mnt/photos/exports/*.jpg

# Web with custom site URL label
photoframe -p web -t "yoursite.com" -o /mnt/photos/ready/web /mnt/photos/exports/*.tif
```

---

### `photo-triage.py`

Scans a folder of mixed files, reads EXIF, detects camera source, finds duplicates, organizes into clean date-based structure.

**Location:** `/mnt/photos/photo-triage.py`

**Usage:**
```bash
python3 photo-triage.py --scan <dir> [options]
```

**Required:**

| Flag | Description |
|---|---|
| `--scan <dir>` | Directory to scan |

**Actions:**

| Flag | Description |
|---|---|
| `--report` | Generate CSV report (always done) |
| `--organize` | Copy/move files into clean structure (requires `--dest`) |
| `--dest <dir>` | Destination directory for organized files |
| `--move` | Move files instead of copying (faster, saves space — requires `--organize`) |
| `--dupes` | Hash files to detect exact duplicates |

**Safety:**
- `--move` requires typing `YES` to confirm
- Without `--organize`, the script never touches files — scan only
- Always generates a CSV report you can review before committing

**Output structure (when organizing):**
```
<dest>/digital/nikon/YYYY/YYYY-MM/
<dest>/digital/ricoh/YYYY/YYYY-MM/
<dest>/phone/YYYY/YYYY-MM/
<dest>/film-scan/scanned-YYYY-MM/
<dest>/video/YYYY/YYYY-MM/
<dest>/unknown/no-date/
```

**Example:**
```bash
# Scan and report only
python3 photo-triage.py --scan /mnt/photos/inbox --report

# Organize into archive, move files (after culling)
python3 photo-triage.py --scan /mnt/photos/inbox \
  --dest /mnt/photos/archive --organize --move --report
```

---

### `send_to_dxo.lua`

Darktable Lua script. Adds **DxO Workflow** panel to the Lighttable left sidebar.

**Location:** `~/.config/darktable/lua/send_to_dxo.lua`

**Buttons:**

| Button | What it does |
|---|---|
| **⟶ Send green to DxO** | Copies all green-labeled images to `/mnt/photos/working/` and relabels them blue |
| **✕ Clear working folder** | Wipes `/mnt/photos/working/` (originals untouched in archive) |

**Configuration (top of the file):**
```lua
local WORKING_DIR  = "/mnt/photos/working"
local SOURCE_COLOR = 2   -- green
local QUEUED_COLOR = 3   -- blue
local DONE_COLOR   = 4   -- purple (set manually after DxO)
```

To install:
```bash
mkdir -p ~/.config/darktable/lua
cp send_to_dxo.lua ~/.config/darktable/lua/
echo 'require "send_to_dxo"' >> ~/.config/darktable/luarc
```

Restart Darktable.

---

## Cheat Sheet

```
┌─ DAILY WORKFLOW ──────────────────────────────────────────────┐
│                                                                │
│  1.  Card → inbox/        Darktable Copy & Import             │
│                                                                │
│  2.  Lock originals       chmod -R 444 /mnt/photos/inbox/...  │
│                                                                │
│  3.  Triage to archive    photo-triage.py --organize --move    │
│                                                                │
│  4.  Cull in Darktable    R/F1-F4 (stars), F8 green for picks │
│                                                                │
│  5.  Send to DxO          DxO Workflow panel → button         │
│                                                                │
│  6.  Edit in DxO          Z:\working\ → DeepPRIME XD          │
│                                                                │
│  7.  Export from DxO      Z:\exports\ with templated names    │
│                                                                │
│  8.  Mark done            F10 (purple) on edited images       │
│                                                                │
│  9.  Frame                photoframe -p instagram-portrait    │
│                                                                │
│  10. Post                 iPhone Files → Instagram            │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## Useful Aliases

Add to `~/.zshrc` on the server:

```bash
# Launch Darktable on VNC display
alias dt='DISPLAY=:1 darktable &'

# Find a file in the archive
alias dtfind='find /mnt/photos/archive -name'

# Show disk usage
alias photodisk='df -h /mnt/photos'

# Watch backup log
alias bktail='tail -f /var/log/photo-backup.log'

# Restart VNC
alias vncrestart='vncserver -kill :1 && vncserver -depth 24 -geometry 1920x1080 -localhost no :1'

# Pre-generate thumbnails
alias dtcache='darktable-generate-cache --max-mip 2'

# Clear macOS junk files
alias photoclean='find /mnt/photos -name "._*" -delete -o -name "Thumbs.db" -delete'
```

---

## Watcher Service (Optional)

If you want files dropped into `drop/instagram-portrait/` to be automatically framed without running `photoframe` manually.

### Watcher script (`/usr/local/bin/photo-watcher`)

```bash
#!/usr/bin/env bash
PHOTOS_ROOT="/mnt/photos"
DROP="$PHOTOS_ROOT/drop"
READY="$PHOTOS_ROOT/ready"
LOG="/var/log/photoframe.log"
PROFILES=(instagram-square instagram-portrait instagram-landscape web web-clean)

echo "[$(date)] photo-watcher started" >> "$LOG"

inotifywait -m -r -e close_write --format '%w%f' \
  "${PROFILES[@]/#/$DROP/}" 2>/dev/null | \
while read -r filepath; do
  profile=$(echo "$filepath" | awk -F"$DROP/" '{print $2}' | cut -d'/' -f1)
  filename=$(basename "$filepath")
  [[ "$filename" == .* || "$filename" == Thumbs.db ]] && continue
  [[ "${filename,,}" =~ \.(jpg|jpeg|tif|tiff|png)$ ]] || continue

  echo "[$(date)] $profile ← $filename" >> "$LOG"
  photoframe -p "$profile" -t "yoursite.com" \
    -o "$READY/$profile" "$filepath" >> "$LOG" 2>&1
done
```

### Systemd service (`/etc/systemd/system/photo-watcher.service`)

```ini
[Unit]
Description=Photo framing watcher
After=network.target

[Service]
ExecStart=/usr/local/bin/photo-watcher
Restart=always
RestartSec=5
User=zac

[Install]
WantedBy=multi-user.target
```

Install dependencies and enable:

```bash
sudo apt install inotify-tools -y
sudo systemctl daemon-reload
sudo systemctl enable --now photo-watcher
```
