-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
hl.monitor({ output = "DP-6", mode = "3840x2160", position = "0x0", scale = 1.25 })
hl.monitor({ output = "DP-7", mode = "3840x2160", position = "0x0", scale = 1.25 })
hl.monitor({ output = "DP-2", mode = "3440x1440", position = "0x0", scale = 1.25 })


-- Workspace 0 is reserved for the laptop display. Workspaces 1–13 persist
-- regardless of content; workspace-monitor-router.nu assigns them to an
-- attached external display, or falls back to eDP-1 when none is available.
hl.workspace_rule({ workspace = "0", monitor = "eDP-1", persistent = true })

for workspace = 1, 13 do
    hl.workspace_rule({ workspace = tostring(workspace), persistent = true })
end


-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
