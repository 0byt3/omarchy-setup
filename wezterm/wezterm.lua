local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Omarchy regenerates this from ~/.config/omarchy/themed/wezterm.lua.tpl on
-- every theme change, so it is absent until a theme has been applied once.
-- local theme_colors = wezterm.home_dir .. "/.local/state/omarchy/current/theme/wezterm.lua"
-- local ok, colors = pcall(dofile, theme_colors)
-- if ok and type(colors) == "table" then
--     config.colors = colors
-- end
-- -- dofile is invisible to the config watcher, so ask for it explicitly.
-- wezterm.add_to_config_reload_watch_list(theme_colors)

-- config.font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Regular" })
-- config.font_size = 9

-- Minimal UI: Hyprland draws the frame, so WezTerm draws no chrome of its own.
config.window_decorations = "NONE"
config.window_padding = { left = 14, right = 14, top = 14, bottom = 14 }
config.enable_tab_bar = false
config.use_fancy_tab_bar = false
config.enable_scroll_bar = false
config.window_close_confirmation = "NeverPrompt"
config.window_background_opacity = 0.85
config.audible_bell = "Disabled"
config.default_cursor_style = "SteadyBlock"
config.adjust_window_size_when_changing_font_size = false

-- Packaged builds update with the system, so skip the upstream version check.
config.check_for_updates = false
config.mux_enable_ssh_agent = false

return config
