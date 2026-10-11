-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Float and center markdown viewers, PDFs, and images 20% larger than the
-- standard 875×600 floating size. Drop the shared tag so its size does not win.
o.window("^(md-view|md-viewer|imv|org.gnome.Evince|org.gnome.NautilusPreviewer)$", { tag = "-floating-window" })
o.window("^(md-view|md-viewer|imv|org.gnome.Evince|org.gnome.NautilusPreviewer)$", { float = true })
o.window("^(md-view|md-viewer|imv|org.gnome.Evince|org.gnome.NautilusPreviewer)$", { center = true })
o.window("^(md-view|md-viewer|imv|org.gnome.Evince|org.gnome.NautilusPreviewer)$", { size = { 1050, 720 } })

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Prefer ~/.local/lib/omarchy-overrides/bin so user wrappers (Cursor as
-- the default agent) win over packaged omarchy-* commands. Reload-safe.
do
    local override = os.getenv("HOME") .. "/.local/lib/omarchy-overrides/bin"
    local kept = {}
    for entry in (os.getenv("PATH") or "/usr/local/bin:/usr/bin"):gmatch("[^:]+") do
        if entry ~= override then table.insert(kept, entry) end
    end
    table.insert(kept, 1, override)
    hl.env("PATH", table.concat(kept, ":"))
end

hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("JAVA_HOME", "/usr/lib/jvm/default")
