# Troubleshooting

Every problem we've actually hit, with the fix that worked.

---

## VNC Won't Connect

### Symptom
TigerVNC Viewer says "unable to connect to socket" or "connection refused"

### Diagnose
On the server:

```bash
ss -tlnp | grep 5901
```

### Cases

**Nothing shown:** VNC isn't running. Start it:
```bash
vncserver -depth 24 -geometry 1920x1080 -localhost no :1
```

**Listening on `127.0.0.1:5901` only:** VNC bound to localhost only. The `-localhost no` flag isn't being applied. Edit the systemd service:
```bash
sudo nano /etc/systemd/system/vncserver@.service
```
Make sure `ExecStart` includes `-localhost no`. Reload:
```bash
sudo systemctl daemon-reload
vncserver -kill :1
sudo systemctl start vncserver@1
```

**Listening on `0.0.0.0:5901`:** VNC is exposed. Check the firewall:
```bash
sudo ufw allow 5901/tcp
sudo ufw status
```

---

## VNC Authentication Fails

### Fix
Reset the password:

```bash
vncpasswd
```

Set a new password, then reconnect with TigerVNC using the new password.

---

## VNC Service Won't Start

### Symptom
```
Job for vncserver@1.service failed because the service did not take the steps required by its unit configuration
```

### Common causes

**Wrong `Type=`:** Should be `Type=simple`, not `Type=forking`. TigerVNC doesn't fork properly for systemd's forking mode.

**Missing `-fg`:** The `ExecStart` line needs the `-fg` flag to keep VNC in the foreground so systemd can track it.

**Stale lock files:** Kill any orphaned process:
```bash
vncserver -kill :1
```

Working `vncserver@.service`:
```ini
[Unit]
Description=TigerVNC server
After=network.target

[Service]
Type=simple
User=zac
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -fg -depth 24 -geometry 1920x1080 -localhost no :%i
ExecStop=/usr/bin/vncserver -kill :%i
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## Darktable: "Database is Locked"

### Symptom
```
the database lock file contains a pid that seems to be alive in your system: 142176
database is locked, probably another process is already using it
```

### Cause
Darktable is still running somewhere (or wasn't shut down cleanly last time). Common when VNC sessions were just disconnected without closing Darktable first.

### Fix
```bash
pkill darktable
rm ~/.config/darktable/lock
dt
```

### Prevent
Always exit Darktable from **File → Quit** before disconnecting VNC. Don't just close the VNC window.

---

## Skull Icons on Thumbnails

### Symptom
Some (or many) images in Darktable show a skull-and-crossbones icon instead of a thumbnail.

### Cause
Darktable can't decode the file. Common reasons:

1. **HEIC phone files** without HEIF support installed
2. **Filenames with spaces or parentheses** confusing the thumbnail generator
3. **macOS `._` junk files** that aren't real images
4. **Corrupted files**

### Fix HEIC support
```bash
sudo apt install libheif1 heif-gdk-pixbuf -y
```
Then restart Darktable.

### Fix filenames
```bash
# Preview which files have problematic names
find /mnt/photos/archive -name "*[() ]*"

# Sanitize them — remove spaces and parens
find /mnt/photos/archive -name "*[() ]*" | while read f; do
  dir=$(dirname "$f")
  base=$(basename "$f")
  newname=$(echo "$base" | tr ' ' '_' | tr -d '()')
  [[ "$base" != "$newname" ]] && mv "$f" "$dir/$newname"
done
```

### Delete macOS junk
```bash
find /mnt/photos -name "._*" -delete
```

### Force Darktable to refresh
```bash
pkill darktable
rm -rf ~/.cache/darktable/
dt
```
Clears the thumbnail cache — Darktable rebuilds it on next open.

---

## Darktable Thumbnails Generate Slowly

### Symptom
Scrolling through Lighttable shows "working..." spinners; thumbnails take forever to render.

### Fix
Pre-generate all thumbnails upfront:

```bash
darktable-generate-cache --max-mip 2
```

Let it run overnight for a large library. After that browsing is instant. The cache lives at `~/.cache/darktable/` on the server — local to where Darktable runs, no Samba latency.

---

## Darktable Version Too Old (3.x)

### Symptom
UI doesn't match current Darktable documentation; missing features; can't read newer file formats.

### Fix
Update to current version via the maintained PPA:

```bash
sudo apt remove darktable -y
sudo add-apt-repository ppa:ubuntuhandbook1/darktable
sudo apt update
sudo apt install darktable -y
darktable --version    # should be 5.x
```

---

## photoframe.sh Only Processes One File

### Symptom
```
photoframe -p instagram-portrait -o ./ready /mnt/photos/exports/*.jpg
━━━━━━━━━━━━━━━━━━
  ✓  DSC_0166.jpg
[and nothing else, only one file processed]
```

### Cause
Old version of `photoframe.sh` had a bug — `set -euo pipefail` combined with `(( count++ ))` made it exit after the first file (because `(( 0++ ))` returns exit code 1, which `set -e` treats as a failure).

### Fix
Get the updated version of `photoframe.sh` and replace the one in `/usr/local/bin/photoframe`. The fix is to use `count=$((count + 1))` instead of `(( count++ ))`.

---

## photoframe.sh Skips Files Silently

### Symptom
Files don't appear in output, no error shown.

### Cause
Output files already exist and `--overwrite` isn't set. The script silently skips them.

### Fix
```bash
photoframe -p instagram-portrait --overwrite -o ./ready /mnt/photos/exports/*.jpg
```

---

## Filenames with Spaces Break photoframe

### Symptom
Glob expands but the script processes the wrong files or only some files.

### Cause
Shell glob expansion treats spaces in filenames as argument separators. Filenames like `strix (2) (5)_insta.jpg` get split apart.

### Fix
Batch rename first to remove the spaces and parens:

```bash
cd /mnt/photos/exports

for f in *.jpg; do
  newname="${f// /_}"
  newname="${newname//(/}"
  newname="${newname//)/}"
  [[ "$f" != "$newname" ]] && mv "$f" "$newname"
done
```

Then run `photoframe` normally. Better: set DxO's filename template to never use spaces or parens.

---

## DxO Creates Files with Spaces / Parentheses

### Symptom
Files exported from DxO have names like `Untitled (2) (5).tif` or `image (3) copy.jpg`.

### Fix
In DxO, edit your export preset:
- Set a strict filename template: `{ImageName}_{Date}` or just `{ImageName}`
- Avoid the default which may include collision suffixes with parens

If you've already exported a batch with bad names, batch-rename them (see above).

---

## Darktable Doesn't See New Files in a Folder

### Symptom
You added files to a folder via Samba or DxO export, but Darktable doesn't show them in the filmroll.

### Fix
Right-click the filmroll in the left panel → look for **Search filmroll** or restart Darktable. In some versions there's no explicit "rescan" button; closing and reopening Darktable is the most reliable approach.

---

## Samba: Permission Denied

### Symptom
Can browse the share but can't write to it from Windows / Mac.

### Diagnose
Check filesystem ownership on the server:

```bash
ls -la /mnt/photos
```

Should show `zac:zac` as owner.

### Fix
```bash
sudo chown -R zac:zac /mnt/photos
```

And verify the Samba config has `writable = yes` and your user listed in `valid users`:

```bash
sudo nano /etc/samba/smb.conf
sudo systemctl restart smbd
```

---

## Samba: Can't Connect at All

### Diagnose
```bash
sudo systemctl status smbd
sudo ufw status
```

### Fix
```bash
sudo systemctl restart smbd
sudo ufw allow Samba
```

Also check the user exists in Samba:
```bash
sudo smbpasswd -a zac
```

---

## Phone Photos Show Up as Skulls

### Cause
HEIC support not installed.

### Fix
```bash
sudo apt install libheif1 heif-gdk-pixbuf -y
```
Restart Darktable.

---

## Backup Drive Filled Up

### Diagnose
```bash
df -h /mnt/backup
```

### Fix options
- Get a bigger drive
- Switch from full mirror to incremental snapshots (e.g., `rsnapshot`)
- Exclude large/replaceable things from backup (videos, exports/, etc.)
- Add `--exclude` patterns to your rsync command:
  ```bash
  rsync -avh --delete \
    --exclude='exports/' \
    --exclude='working/' \
    --exclude='ready/' \
    /mnt/photos/ /mnt/backup/photos/
  ```
  (These can all be regenerated from `archive/` if needed)

---

## XMP Sidecars Not Updating

### Symptom
You rate or edit an image in Darktable, but the XMP file alongside it doesn't update.

### Fix
Preferences → Storage:
- **Write sidecar XMP files** → ON
- **Automatically apply XMP** → ON

Without these, your edits only live in the Darktable database — vulnerable to corruption and not portable across machines.

---

## Lost Edits — Database Corruption

### Symptom
Darktable won't start, database errors on launch.

### Fix
**Your edits are safe in XMP sidecars** (assuming you turned on the preference above). To recover:

```bash
# Backup the corrupted database
mv ~/.config/darktable/library.db ~/.config/darktable/library.db.broken

# Restart Darktable — it creates a fresh database
dt
```

Then re-import your library folder. Darktable reads the XMP files and your ratings/edits come back.

---

## Right-Click Doesn't Work in Darktable Over VNC

### Cause
TigerVNC sometimes intercepts right-click events.

### Fix attempts
1. In TigerVNC viewer: **Options → Input** — check mouse button mapping
2. Use keyboard shortcuts instead of context menus
3. Try a different VNC viewer (RealVNC, NoMachine)

---

## When All Else Fails

```bash
# Restart everything
sudo systemctl restart smbd
sudo systemctl restart vncserver@1
pkill darktable
rm ~/.config/darktable/lock
```

Reconnect via VNC, launch Darktable fresh.
