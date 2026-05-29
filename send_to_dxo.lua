--[[
  send_to_dxo.lua — Send green-labeled images to /mnt/photos/working/

  Adds a "DxO Workflow" panel to the Lighttable left panel.
  - Finds all green-labeled images in the library
  - Copies them to WORKING_DIR
  - Changes their label from green → blue ("queued for DxO")

  Note: Darktable 5.x uses per-color boolean fields (image.green, image.blue,
  etc.) rather than a single integer color_label field.

  Install:
    cp send_to_dxo.lua ~/.config/darktable/lua/
    Add to ~/.config/darktable/luarc:
      require "send_to_dxo"

  Author: Zac
--]]

local dt = require "darktable"

-- ── Configuration ─────────────────────────────────────────────────────────────
local WORKING_DIR = "/mnt/photos/working"

-- ── Helper: ensure working directory exists ───────────────────────────────────
local function ensure_dir(path)
  os.execute(string.format('mkdir -p "%s"', path))
end

-- ── Helper: copy a file ───────────────────────────────────────────────────────
local function copy_file(src, dest_dir)
  local cmd = string.format('cp "%s" "%s/"', src, dest_dir)
  local ok = os.execute(cmd)
  return ok == 0 or ok == true
end

-- ── Main function ─────────────────────────────────────────────────────────────
local function send_to_dxo()
  print("────────────────────────────────────")
  print("send_to_dxo: starting")
  print("send_to_dxo: destination → " .. WORKING_DIR)
  ensure_dir(WORKING_DIR)

  local sent    = 0
  local skipped = 0
  local errors  = 0
  local checked = 0

  for _, image in ipairs(dt.database) do
    checked = checked + 1
    if image.green then
      local src  = image.path .. "/" .. image.filename
      local dest = WORKING_DIR .. "/" .. image.filename

      local f = io.open(dest, "r")
      if f then
        f:close()
        print("  skip (already in working): " .. image.filename)
        skipped = skipped + 1
      else
        print("  copying: " .. image.filename)
        if copy_file(src, WORKING_DIR) then
          image.green = false
          image.blue  = true
          print("  ✓ sent + relabeled blue: " .. image.filename)
          sent = sent + 1
        else
          print("  ✗ ERROR copying: " .. src)
          dt.print_error("Failed to copy: " .. image.filename)
          errors = errors + 1
        end
      end
    end
  end

  print("────────────────────────────────────")
  print("send_to_dxo: checked " .. checked .. " images in library")
  local msg = string.format(
    "Send to DxO: %d sent, %d skipped (already there), %d errors → %s",
    sent, skipped, errors, WORKING_DIR
  )
  print(msg)
  print("────────────────────────────────────")
  dt.print(msg)
end

-- ── Clear working folder ──────────────────────────────────────────────────────
-- Removes all files from the working folder so you can start fresh
local function clear_working()
  local cmd = string.format('rm -f "%s"/*', WORKING_DIR)
  os.execute(cmd)
  dt.print("Working folder cleared: " .. WORKING_DIR)
end

-- ── Register UI module in Lighttable left panel ───────────────────────────────
dt.register_lib(
  "send_to_dxo",          -- internal name
  "DxO Workflow",         -- panel title
  true,                   -- expandable
  true,                   -- start expanded
  {
    [dt.gui.views.lighttable] = {
      "DT_UI_CONTAINER_PANEL_LEFT_CENTER", 99
    }
  },
  dt.new_widget("box") {
    orientation = "vertical",

    -- Description label
    dt.new_widget("label") {
      label = "Green → copy to working folder\nand mark blue (queued for DxO)",
      ellipsize = "none",
      halign = "start",
    },

    -- Spacer
    dt.new_widget("label") { label = "" },

    -- Send button
    dt.new_widget("button") {
      label    = "⟶  Send green to DxO",
      tooltip  = "Copy all green-labeled images to " .. WORKING_DIR .. " and relabel as blue",
      clicked_callback = send_to_dxo,
    },

    -- Spacer
    dt.new_widget("label") { label = "" },

    -- Clear button
    dt.new_widget("button") {
      label    = "✕  Clear working folder",
      tooltip  = "Remove all files from " .. WORKING_DIR,
      clicked_callback = clear_working,
    },

    -- Spacer
    dt.new_widget("label") { label = "" },

    -- Reminder label
    dt.new_widget("label") {
      label = "Color key:\n  Green  = ready to edit\n  Blue   = sent to DxO\n  Purple = done",
      ellipsize = "none",
      halign = "start",
    },
  }
)

dt.print_log("send_to_dxo: loaded")
