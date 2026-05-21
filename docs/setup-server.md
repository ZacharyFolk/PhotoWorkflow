# Server Setup (One-Time)

Everything that needs to be set up on the Ubuntu server. Do these once, then forget about them.

**Server hostname:** `jellyfin`  ·  **User:** `zac`  ·  **Photo root:** `/mnt/photos/`

---

## 1. Samba — File Sharing

The Ubuntu server shares `/mnt/photos/` so Windows, Mac, and iPhone can browse and edit files over the network.

### Install

```bash
sudo apt install samba -y
sudo smbpasswd -a zac    # set the Samba password (separate from Linux password)
```

### Configure shares

```bash
sudo nano /etc/samba/smb.conf
```

Add these blocks at the bottom of the file:

```ini
[PhotoWorkspace]
   path = /mnt/photos
   browseable = yes
   writable = yes
   valid users = zac
   create mask = 0755
   directory mask = 0755

[CloudMedia]
   path = /mnt/cloud_media
   browseable = yes
   writable = yes
   valid users = zac
```

Restart Samba after any config change:

```bash
sudo systemctl restart smbd
```

### Firewall

```bash
sudo ufw allow Samba
```

> **Adding a new share later:** Edit `/etc/samba/smb.conf`, add another `[ShareName]` block following the same pattern, restart `smbd`. Don't share `/` (the root filesystem) — make a separate share for any specific folder you need.

---

## 2. VNC — Remote Desktop Access

Lets you run Darktable's GUI on the server while controlling it from Windows, Mac, or anywhere else. Critical for the centralized Darktable setup.

### Install lightweight desktop and VNC

```bash
sudo apt update
sudo apt install xfce4 xfce4-terminal dbus-x11 tigervnc-standalone-server -y
```

XFCE is a minimal desktop environment — much lighter than full Ubuntu desktop.

### Set the VNC password

```bash
vncpasswd
```

Enter the password twice. Say **no** to the view-only password prompt.

### Configure the VNC startup script

```bash
mkdir -p ~/.vnc
nano ~/.vnc/xstartup
```

Contents:

```bash
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
```

Make it executable:

```bash
chmod +x ~/.vnc/xstartup
```

### Create the systemd service

```bash
sudo nano /etc/systemd/system/vncserver@.service
```

Contents (replace `zac` with your username in both places):

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

> **Critical details — easy to get wrong:**
> - `Type=simple` (not `forking`) — TigerVNC doesn't fork properly for systemd's forking mode
> - `-fg` flag — keeps VNC in foreground so systemd can track the process
> - `-localhost no` — binds to all network interfaces (without this, VNC only listens on localhost and you can't connect from other machines)

Enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vncserver@1
sudo systemctl status vncserver@1    # should show: active (running)
```

### Firewall

```bash
sudo ufw allow 5901/tcp
```

VNC runs on port 5901 for display `:1`.

### Verify

```bash
ss -tlnp | grep 5901
```

Should show `0.0.0.0:5901` (not `127.0.0.1:5901`). If it shows localhost only, the `-localhost no` flag isn't taking effect.

---

## 3. Darktable on the Server

Run Darktable on the server itself, accessed via VNC. This gives you:
- Central thumbnail cache (generated once, fast forever)
- Central ratings database
- Same library visible from any device

### Install the current version (not the old apt one)

Ubuntu's default Darktable is years out of date. Get the current version from the maintained PPA:

```bash
sudo apt-get remove darktable -y   # if old version installed
sudo add-apt-repository ppa:ubuntuhandbook1/darktable
sudo apt update
sudo apt install darktable -y
darktable --version    # confirm 5.x
```

### Install HEIC support (for phone photos)

Phone photos from iOS are HEIC. Without this, they show up as broken/skull thumbnails:

```bash
sudo apt install libheif1 heif-gdk-pixbuf -y
```

### Convenience alias

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
alias dt='DISPLAY=:1 darktable &'
```

Reload:

```bash
source ~/.zshrc
```

Now just type `dt` to launch Darktable on the VNC display.

### One-time Darktable preferences

After connecting via VNC and opening Darktable, set these in **Preferences**:

| Section | Setting | Value |
|---|---|---|
| Storage | Write sidecar XMP files | **ON** — critical for portable ratings |
| Storage | On database change, automatically apply XMP | **ON** |
| Lighttable | Number of images in filmroll | 100–200 |
| Processing | Default workflow | Scene-referred (filmic) |

### Pre-generate all thumbnails

For a large library you don't want to wait for thumbnails to render as you scroll. Pre-generate them all at once:

```bash
darktable-generate-cache --max-mip 2
```

`--max-mip 2` covers small, medium, and Lighttable display sizes. Let it run overnight for a big archive.

---

## 4. The send_to_dxo.lua Script

A custom Lua script that adds a **DxO Workflow** panel to Darktable's Lighttable sidebar. One-click sends all green-labeled images to a staging folder for DxO editing.

### Install

```bash
mkdir -p ~/.config/darktable/lua
cp send_to_dxo.lua ~/.config/darktable/lua/

# Add to luarc so it auto-loads
echo 'require "send_to_dxo"' >> ~/.config/darktable/luarc
```

Restart Darktable. You'll see a new **DxO Workflow** panel in the Lighttable left sidebar.

The script reads/writes to `/mnt/photos/working/` — make sure that folder exists:

```bash
mkdir -p /mnt/photos/working
```

See [reference.md](reference.md) for what the script does in detail.

---

## 5. The photoframe.sh Script

Bash script that adds borders and a label to JPEG/TIFF exports, producing finished files for Instagram, web, and print.

### Install

```bash
sudo apt install imagemagick fonts-dejavu -y

# Place the script somewhere on PATH
sudo cp photoframe.sh /usr/local/bin/photoframe
sudo chmod +x /usr/local/bin/photoframe
```

Now you can run `photoframe` from anywhere on the server. See [reference.md](reference.md) for full options or run `photoframe --help`.

---

## 6. The photo-triage.py Script

Python script for triaging a messy/legacy library — reads EXIF, detects source, finds duplicates, organizes into a clean date-based structure.

### Install dependencies

```bash
sudo apt install exiftool python3-pip -y
pip3 install tqdm    # optional, gives you a progress bar
```

Place the script somewhere convenient:

```bash
cp photo-triage.py /mnt/photos/photo-triage.py
chmod +x /mnt/photos/photo-triage.py
```

See [reference.md](reference.md) for full usage or run `python3 photo-triage.py --help`.

---

## 7. Folder Structure

Create the directory layout once:

```bash
sudo mkdir -p /mnt/photos/{inbox,archive,working,exports,ready}
sudo mkdir -p /mnt/photos/ready/{instagram-square,instagram-portrait,instagram-landscape,web,web-clean}
sudo chown -R zac:zac /mnt/photos
```

See [reference.md](reference.md) for what each folder is for.

---

## 8. (Optional) Tailscale — Remote Access Outside the House

If you want to VNC into the server from outside your home network (sauna, coffee shop, on the road):

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Authenticate via the URL it prints. Install Tailscale on your laptop/phone, log in with the same account. Every device gets a stable private IP like `100.x.x.x` — VNC into that instead of your local IP.

No port forwarding, no dynamic DNS, no router fiddling. Just works.

---

## 9. (Optional) Watcher Service

If you want files dropped into `drop/instagram-portrait/` etc. to be automatically processed by `photoframe.sh`, set up the watcher service. See [reference.md](reference.md) for the script and systemd unit.

In practice the manual workflow (DxO export → run `photoframe` on the result) tends to work better day-to-day. The watcher is optional.

---

## Done

Once all of this is set up, you're ready to actually use the system. See [setup-clients.md](setup-clients.md) for setting up Windows/Mac/iPhone access, or jump to [mode-import.md](mode-import.md) for the first daily workflow.
