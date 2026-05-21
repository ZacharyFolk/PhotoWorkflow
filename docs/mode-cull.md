# Mode: Cull

When you sit down to browse images, rate them, and decide what's worth editing. This is the mode you spend the most time in.

---

## Where Culling Happens

**Darktable, running on the server, accessed via VNC.**

This is the only place — not Windows Darktable, not FastRawViewer. The point of the server setup is that all your ratings, color labels, and thumbnails are stored centrally. Cull on Windows tonight, see the same ratings on Mac tomorrow.

From any machine: connect via TigerVNC to `192.168.x.x:5901`, then in a terminal type `dt` to launch Darktable.

---

## The Color Label Workflow

This is the heart of the whole system. Use color labels consistently:

| Color | Shortcut | Meaning | Set by |
|---|---|---|---|
| **Green** | `F8` | **Pick** — ready to send to DxO | You, during culling |
| **Blue** | (auto) | Sent to DxO — queued for editing | The Lua script |
| **Purple** | `F10` | **Done** — exported from DxO | You, after editing |
| **Yellow** | `F7` | Skip — ignore in the pipeline | You, optional |
| **Red** | `F6` | Reserved — use however you want | You |

```
unrated  →  green (pick)  →  blue (in DxO)  →  purple (done)
```

Yellow images are ignored everywhere — by `send_to_dxo.lua`, by smart collections, by your eye when scanning the library.

---

## Two-Pass Culling Method

### Pass 1 — Reject Failures (Fast)

Open the filmroll in Lighttable. Move through quickly using the keyboard:

| Key | Action |
|---|---|
| `R` | Reject — out of focus, bad exposure, blinked eyes |
| `→` `←` | Next / previous image |
| `Z` or `T` | Zoom in to check sharpness |

**Work fast.** This pass is about eliminating, not selecting. When in doubt, leave it — you can reject later. Don't agonize.

---

### Pass 2 — Rate the Keepers

Filter out rejects: **left panel → Collections → Filter → Hide rejected**.

Now rate what remains:

| Key | Stars | Meaning |
|---|---|---|
| `F1` | ★ | Technically OK |
| `F2` | ★★ | Good — would share if nothing better |
| `F3` | ★★★ | Strong — editing this one |
| `F4` | ★★★★ | Best of session — portfolio candidate |
| `F5` | ★★★★★ | Exceptional — use sparingly |

Filter to **3 stars and above**. That's your edit queue. Label those **green** (`F8`) — they're ready for DxO.

---

## Browsing the Archive

The `archive/` is organized into collections you can navigate from Darktable's left sidebar:

```
archive/
├── digital/nikon/YYYY/YYYY-MM/   ← bulk of your work
├── digital/ricoh/YYYY/YYYY-MM/
├── phone/YYYY/YYYY-MM/
├── film-scan/scanned-YYYY-MM/    ← scan date, not shoot date
└── video/YYYY/YYYY-MM/
```

### One-time: import the archive into Darktable

**Lighttable → Import → Add to library → `/mnt/photos/archive/`** (check **recursive directory**).

Darktable scans everything and creates filmrolls — one per leaf folder. Thousands of images appear in the library.

### Browse by year / shoot

In the left sidebar:
- **Collections → folder** — browse the archive tree
- **Collections → date** — browse by capture date

Folders that show as collections are clickable — click a year, click a month, see those images.

---

## Smart Collections (Highly Recommended)

Create saved filters for common views. In the left sidebar → **Collections → +** → create a new collection.

Useful smart collections to set up once:

| Name | Filter rule |
|---|---|
| **Ready to send** | Color label = green |
| **Queued in DxO** | Color label = blue |
| **Done** | Color label = purple |
| **Edit queue (3+ stars, no label)** | Stars ≥ 3 AND no color label |
| **Recent imports** | Imported in the last 7 days |

Now culling is one click — open "Edit queue" to see what still needs ratings, "Ready to send" to see what's queued for DxO.

---

## Pre-generating Thumbnails

If you've just imported a big chunk, scrolling through it triggers slow thumbnail generation. Pre-generate all of them in advance:

```bash
darktable-generate-cache --max-mip 2
```

Let it run overnight. After that, browsing is instant.

---

## Common Culling Annoyances

### "Working..." spinner on every image

Thumbnails being generated on the fly. Either let it churn through (it caches as it goes) or run `darktable-generate-cache` to pre-build them.

### Skull icons everywhere

Darktable can't read those files. Likely causes:
- **HEIC phone files** — need `libheif1` package installed (see [setup-server.md](setup-server.md))
- **Spaces / parentheses in filenames** — rename them (see [troubleshooting.md](troubleshooting.md))
- **macOS `._` files** — junk metadata files, delete with `find ... -name "._*" -delete`

### Right-click does nothing

VNC sometimes intercepts right-click. Use keyboard shortcuts instead, or check TigerVNC's Options → Input settings.

### Can't see where a file lives on disk

In Darktable: select image → left panel → **Image information** → shows full path.

Quick terminal lookup:
```bash
find /mnt/photos/archive -name "DSC_1234.NEF"
```

---

## When You're Done Culling

You should have a batch of green-labeled images ready for editing. Move on to [mode-edit.md](mode-edit.md) — one click in the DxO Workflow panel sends them all to DxO.
