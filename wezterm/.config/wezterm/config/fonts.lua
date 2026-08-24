local wezterm = require("wezterm")
local platform = require("utils.platform")

-- local font = 'Maple Mono SC NF'
local font_family = "JetBrains Mono"
-- local font_size = platform.is_mac and 15 or 12
local font_size = platform.is_mac and 26 or 13

-- 中文回退字体
local function font_stack(weight, italic)
  return wezterm.font_with_fallback({
    { family = font_family, weight = weight, italic = italic or false },
    { family = "Symbols Nerd Font Mono", weight = weight, italic = italic or false },
    { family = "LXGW WenKai Mono", weight = weight, italic = italic or false },
  })
end

return {
  font = font_stack("DemiBold"),
  font_size = font_size,
  font_rules = {
    {
      intensity = "Normal",
      italic = false,
      font = font_stack("DemiBold"),
    },
    {
      intensity = "Bold",
      italic = false,
      font = font_stack("Bold"),
    },
    {
      intensity = "Half",
      italic = false,
      font = font_stack("Medium"),
    },
    {
      intensity = "Normal",
      italic = true,
      font = font_stack("DemiBold", true),
    },
    {
      intensity = "Bold",
      italic = true,
      font = font_stack("Bold", true),
    },
  },
  line_height = 1.05,
  cell_width = 1.0,
  custom_block_glyphs = true,

  --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
  freetype_load_target = "HorizontalLcd", ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
  freetype_render_target = "HorizontalLcd", ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
}
