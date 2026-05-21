# Client Setup (One-Time)

Setting up Windows, Mac, and iPhone to access the server. Do these once per machine.

---

## Windows (Primary Machine)

### Map the Samba share

1. Open **File Explorer**
2. Right-click **This PC** → **Map network drive**
3. Drive letter: `Z:` (or any free letter)
4. Folder: `\\192.168.x.x\PhotoWorkspace`
5. Check **Reconnect at sign-in** so it persists across reboots
6. Click **Finish**, enter your Samba username (`zac`) and password

`Z:\` now shows all of `/mnt/photos/`.

### Pin folders to Quick Access

In File Explorer's sidebar, drag these in for one-click access:

- `Z:\working\`  — DxO staging
- `Z:\exports\`  — DxO output
- `Z:\ready\`    — finished framed files

### TigerVNC Viewer (to access Darktable on the server)

1. Download **TigerVNC Viewer** for Windows from [tigervnc.org](https://tigervnc.org)
2. Run it
3. Connect to: `192.168.x.x:5901`
4. Enter your VNC password (the one you set with `vncpasswd`)

The XFCE desktop appears with Darktable available.

> **Tip:** Save the connection in TigerVNC — File → Save connection — so you don't have to type the address every time.

### DxO PhotoLab

DxO runs natively on Windows. Point it at `Z:\working\` when editing.

---

## Mac (Secondary Machine)

### Mount the Samba share

In Finder:
1. **⌘K** (Go → Connect to Server)
2. Enter: `smb://192.168.x.x/PhotoWorkspace`
3. Click **Connect**, enter Samba username (`zac`) and password
4. The share appears in Finder under **Locations** (sidebar)

### Auto-mount on login

To have the share connect automatically when you log in:

1. **System Settings → Users & Groups → Login Items**
2. Click **+** and add the mounted share

### TigerVNC Viewer

Either:
- **TigerVNC Viewer** from [tigervnc.org](https://tigervnc.org) (recommended — same as Windows)
- **RealVNC Viewer** from the Mac App Store (alternative)

Connect to: `192.168.x.x:5901`

Or use the built-in Mac Screen Sharing app:
- Finder → **⌘K** → `vnc://192.168.x.x:5901`

---

## iPhone

### Mount the Samba share in the Files app

1. Open **Files**
2. Tap **...** (three dots, top right) → **Connect to Server**
3. Enter: `smb://192.168.x.x/PhotoWorkspace`
4. Username: `zac`, Samba password
5. Tap **Connect**

The share appears under **Locations** in Files.

### Posting from iPhone to Instagram

The whole reason for iPhone access is grabbing finished photos for posting:

1. Open **Instagram** → new post → tap gallery icon
2. Tap the dropdown at the top (says "Recents")
3. Select **Files** from the list
4. Navigate to `PhotoWorkspace → ready → instagram-portrait/`
5. Pick the photo, post

No need to copy files to the camera roll first — Instagram reads them directly from the Files app.

---

## Remote Access (Outside the House)

If you've set up Tailscale on the server (see [setup-server.md](setup-server.md) section 8):

1. Install Tailscale on your client device (Windows/Mac/iPhone)
2. Log in with the same account as the server
3. Use the server's Tailscale IP (`100.x.x.x`) instead of `192.168.x.x` for both Samba and VNC

Works from any network, anywhere.

---

## What's Where, By Machine

| Task | Machine | App |
|---|---|---|
| Cull & rate library | Any | Darktable via VNC |
| Edit (RAW → JPEG/TIFF) | Windows | DxO PhotoLab |
| Frame for Instagram | Server | `photoframe` via SSH |
| Post to Instagram | iPhone | Files → Instagram |
| Browse archive | Any | Darktable via VNC, or Files/Explorer |

---

## Important: Only One Darktable at a Time

Darktable locks its database when running. If you connect via VNC from one machine, then connect from another machine and try to launch Darktable, you'll get:

```
the database lock file contains a pid that seems to be alive in your system
database is locked, probably another process is already using it
```

Either close Darktable on the first machine cleanly, or if VNC was just disconnected, kill the orphaned process on the server:

```bash
pkill darktable
rm ~/.config/darktable/lock
```

Then launch fresh with `dt`.

> Don't just close the VNC window — that leaves Darktable running on the server. Always exit Darktable from its **File → Quit** menu, then disconnect VNC.

---

## Next

Once all clients are set up, see [mode-import.md](mode-import.md) for the daily import workflow.
