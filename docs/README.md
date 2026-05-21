# Photo Workflow Documentation

Overview of the photo pipeline.

**Stack:** Ubuntu Server · Darktable (on server, via VNC) · DxO PhotoLab · ImageMagick
**Photo root:** `/mnt/photos/` · **Samba share:** `PhotoWorkspace` at `\\192.168.x.x\PhotoWorkspace`

---

### Setup (one-time)

| Doc | When to read it |
|---|---|
| **[setup-server.md](setup-server.md)** | Setting up the Ubuntu server: Samba, VNC, Darktable, tools |
| **[setup-clients.md](setup-clients.md)** | Setting up Windows, Mac, or iPhone to access the server |

### Daily operation modes

| Doc | When you're doing this |
|---|---|
| **[mode-import.md](mode-import.md)** | New memory card / new files to bring into the system |
| **[mode-cull.md](mode-cull.md)** | Sitting down to browse, rate, and organize images |
| **[mode-edit.md](mode-edit.md)** | Working through your green-labeled picks in DxO |
| **[mode-publish.md](mode-publish.md)** | Framing finished edits for Instagram, web, print |
| **[mode-maintain.md](mode-maintain.md)** | Housekeeping, backups, archive cleanup |

### Reference

| Doc | What's in it |
|---|---|
| **[reference.md](reference.md)** | Folder layout, naming conventions, color label workflow, all scripts |
| **[troubleshooting.md](troubleshooting.md)** | Every problem we've hit, with the fix |

---

## The Big Picture

The pipeline in one diagram:

```
┌──────────────────────────────────────────────────────────────────────┐
│  IMPORT          CULL              EDIT             PUBLISH          │
│                                                                       │
│  Card → inbox/   archive/  →  working/  →  exports/  →  ready/       │
│         (raw)    (organized)  (DxO       (DxO          (framed,      │
│                  triage)      staging)    output)       posted)      │
│                                                                       │
│            green label    blue label    purple label                 │
└──────────────────────────────────────────────────────────────────────┘
```

Color labels in Darktable drive the whole flow:

- **Green** — picked, ready to edit
- **Blue** — sent to DxO (set automatically by Lua script)
- **Purple** — done, exported (set manually after DxO)
- **Yellow** — ignored throughout

---

## Quickest Common Tasks

| I want to... | Go to |
|---|---|
| Bring photos from my camera in | [mode-import.md](mode-import.md) |
| Cull a shoot, mark winners | [mode-cull.md](mode-cull.md) |
| Send my picks to DxO for editing | [mode-edit.md](mode-edit.md) |
| Frame a JPEG for Instagram | [mode-publish.md](mode-publish.md) |
| Back up the server | [mode-maintain.md](mode-maintain.md) |
| Fix Darktable thumbnails being broken | [troubleshooting.md](troubleshooting.md) |
| Look up a script's options | [reference.md](reference.md) |
