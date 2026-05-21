# Mode: Publish

When you have edited files in `/mnt/photos/exports/` and you want to frame them for sharing — Instagram, web, or print.

---

## Goal

```
exports/  →  photoframe.sh  →  ready/  →  Instagram / web / print
```

---

## Running photoframe

Connect to the server (SSH or VNC terminal), then:

### Instagram portrait (4:5, best feed reach)

```bash
photoframe -p instagram-portrait \
  -o /mnt/photos/ready/instagram-portrait \
  /mnt/photos/exports/*.jpg
```

### Instagram square (1:1, fits any aspect ratio)

```bash
photoframe -p instagram-square \
  -o /mnt/photos/ready/instagram-square \
  /mnt/photos/exports/*.jpg
```

### Web (≤2400px, framed, keeps EXIF)

```bash
photoframe -p web \
  -o /mnt/photos/ready/web \
  /mnt/photos/exports/*.tif
```

### Web clean (no borders, just resized)

```bash
photoframe -p web-clean \
  -o /mnt/photos/ready/web-clean \
  /mnt/photos/exports/*.jpg
```

---

## All Profile Options

| Profile | Canvas | Mat | Use case |
|---|---|---|---|
| `instagram-square` | 1080×1080 | Cream | Square posts, fits any source ratio |
| `instagram-portrait` | 1080×1350 | Cream | Best feed reach (4:5) |
| `instagram-landscape` | 1080×566 | Cream | Cinematic 1.91:1 |
| `web` | ≤2400px | Cream, proportional | Website, blog, gallery |
| `web-clean` | ≤2400px | No mat | CMS uploads, press kit |

---

## Useful Flags

| Flag | What it does |
|---|---|
| `-n` | No text label at all |
| `-t "yoursite.com"` | Custom label instead of filename |
| `--overwrite` | Replace existing output files |
| `--dry-run` | Show what would happen without doing it |
| `-v` | Verbose — show the full ImageMagick command per file |
| `-h` | Help |

---

## Quick Reminders

### Always quote globs with spaces

If filenames have spaces, the shell glob can split incorrectly. The proper fix is to never have spaces in filenames — sanitize at export time. But as a workaround:

```bash
find /mnt/photos/exports/ -maxdepth 1 -name "*.jpg" -print0 | \
  xargs -0 photoframe -p instagram-portrait -o /mnt/photos/ready/instagram-portrait
```

### Run from the right directory

Use absolute paths to avoid confusion:

```bash
photoframe -p web -o /mnt/photos/ready/web /mnt/photos/exports/*.jpg
```

Not:

```bash
photoframe -p web -o ./ready /exports/*.jpg     # confusing, error-prone
```

---

## Where the Borders Came From

The framing style is a gallery print look — small black inner rule tight around the image, then a wide cream mat around that.

For Instagram profiles where the canvas is a fixed size, the image is fit into the content area first with the black border tight against it, then the mat fills the rest of the canvas. This means portrait images on a 4:5 canvas get slightly wider mat on the sides than top/bottom — that's intentional and looks deliberate, like a gallery frame.

If you want perfectly even borders, crop the source image to match the canvas ratio in DxO/Darktable before exporting.

---

## Custom Labels for Specific Posts

The default label is the filename. Two ways to change it:

### Per-run custom text

```bash
photoframe -p instagram-portrait -t "your.site" \
  -o /mnt/photos/ready/instagram-portrait \
  /mnt/photos/exports/sunset.jpg
```

### Suppress completely

```bash
photoframe -p instagram-portrait -n \
  -o /mnt/photos/ready/instagram-portrait \
  /mnt/photos/exports/sunset.jpg
```

The label is intentionally subtle — small warm grey text in the bottom mat. Deters casual reuse without garishly stamping the image.

---

## Collecting Finished Files

### On Windows

Open `Z:\ready\` in Explorer. The relevant subfolder contains your framed files.

### On Mac

Mount the share (`smb://192.168.x.x/PhotoWorkspace`) → navigate to `ready/`.

### On iPhone (for posting)

1. Files app → `PhotoWorkspace → ready → instagram-portrait/`
2. Instagram → new post → gallery dropdown → **Files** → select your photo
3. Post

No need to copy files to the camera roll first.

---

## Optional: Automate with the Watcher Service

If you'd rather skip the manual `photoframe` step, the watcher service can auto-process anything dropped into `drop/instagram-portrait/`, etc. See [reference.md](reference.md) for the watcher script and systemd setup.

In practice the manual workflow is fine — you review your edits before framing anyway, and explicit beats magic for most one-off batches.

---

## Done

You've gone from raw card to framed, ready-to-post image. See [mode-maintain.md](mode-maintain.md) for backups and cleanup.
