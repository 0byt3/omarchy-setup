-- Additional numbered workspace bindings.
-- SUPER + SHIFT + E is Omarchy's Email shortcut by default.
hl.unbind("SUPER + SHIFT + E")

local workspaces = {
  { key = "Q", number = "11" },
  { key = "E", number = "12" },
  { key = "R", number = "13" },
}

for _, workspace in ipairs(workspaces) do
  o.bind("SUPER + " .. workspace.key, "Switch to workspace " .. workspace.number, hl.dsp.focus({ workspace = workspace.number }))
  o.bind("SUPER + SHIFT + " .. workspace.key, "Move window to workspace " .. workspace.number, hl.dsp.window.move({ workspace = workspace.number }))
end
