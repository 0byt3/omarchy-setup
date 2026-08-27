-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Route persistent workspaces 1–13 to the connected external display.
o.launch_on_start("nu " .. os.getenv("HOME") .. "/.config/hypr/workspace-monitor-router.nu")
