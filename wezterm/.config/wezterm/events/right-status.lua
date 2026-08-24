local wezterm = require("wezterm")

local M = {}

M.setup = function()
  wezterm.on("update-right-status", function(window, _pane)
    window:set_right_status("")
  end)
end

return M
