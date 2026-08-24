local wezterm = require("wezterm")

local nf = wezterm.nerdfonts

local BAR_BG = "#282a36"
local HOME = os.getenv("HOME") or "~"

local GLYPH_LEFT = nf.ple_left_half_circle_thick or ""
local GLYPH_RIGHT = nf.ple_right_half_circle_thick or ""
local GLYPH_ADMIN = nf.md_shield_half_full or "󰞀"

local icons = {
  shell = nf.cod_terminal or "󰆍",
  mac = "󰀵",
  folder = nf.md_folder or "󰉋",
  yazi = nf.md_folder_eye or "󱞊",
  ranger = nf.md_file_tree or "󰙅",
  nvim = "",
  git = nf.dev_git or "",
  ssh = nf.md_ssh or "󰣀",
  hpc = nf.md_server or "󰒋",
  iap = nf.md_file_search or "󰱼",
  code = nf.md_code_braces or "󰅩",
  codex = nf.md_robot_happy or "󱜙",
  manual = nf.md_tag_text or "󰌪",
}

local M = {}

local manual_titles = {}

local palette = {
  active = {
    outer_bg = "#282a36",
    grad_bg_from = "#7f5d95",
    grad_bg_to = "#3d93a5",
    grad_fg_from = "#fff7ff",
    grad_fg_to = "#d8feff",
    alert_fg = "#ff6fb4",
    intensity = "Bold",
  },
  hover = {
    outer_bg = "#282a36",
    grad_bg_from = "#382f43",
    grad_bg_to = "#2b4552",
    grad_fg_from = "#ffc2e5",
    grad_fg_to = "#abecfb",
    alert_fg = "#ff72b6",
    intensity = "Bold",
  },
  default = {
    outer_bg = "#282a36",
    grad_bg_from = "#252837",
    grad_bg_to = "#22313c",
    grad_fg_from = "#b990b0",
    grad_fg_to = "#72b8c7",
    alert_fg = "#ff7fbd",
    intensity = "Normal",
  },
}

---@param bg string
---@param fg string
---@param text string
---@param intensity? "Bold"|"Half"|"Normal"
local function push(cells, bg, fg, text, intensity)
  table.insert(cells, { Background = { Color = bg } })
  table.insert(cells, { Foreground = { Color = fg } })
  if intensity then
    table.insert(cells, { Attribute = { Intensity = intensity } })
  end
  table.insert(cells, { Text = text })
  table.insert(cells, "ResetAttributes")
end

local function hex_to_rgb(hex)
  return {
    r = tonumber(hex:sub(2, 3), 16),
    g = tonumber(hex:sub(4, 5), 16),
    b = tonumber(hex:sub(6, 7), 16),
  }
end

local function rgb_to_hex(rgb)
  return string.format("#%02x%02x%02x", rgb.r, rgb.g, rgb.b)
end

local function blend_color(from, to, ratio)
  local a = hex_to_rgb(from)
  local b = hex_to_rgb(to)
  return rgb_to_hex({
    r = math.floor(a.r + (b.r - a.r) * ratio + 0.5),
    g = math.floor(a.g + (b.g - a.g) * ratio + 0.5),
    b = math.floor(a.b + (b.b - a.b) * ratio + 0.5),
  })
end

local function chars(text)
  local out = {}
  for _, code in utf8.codes(text) do
    table.insert(out, utf8.char(code))
  end
  return out
end

local function push_gradient(cells, text, bg_from, bg_to, fg_from, fg_to, intensity)
  local letters = chars(text)
  local total = #letters
  if total == 0 then
    return
  end

  for idx, ch in ipairs(letters) do
    local ratio = total == 1 and 0 or (idx - 1) / (total - 1)
    push(
      cells,
      blend_color(bg_from, bg_to, ratio),
      blend_color(fg_from, fg_to, ratio),
      ch,
      intensity
    )
  end
end

local function clean_process_name(process_name)
  process_name = process_name or ""
  local name = string.gsub(process_name, "(.*[/\\])(.*)", "%2")
  return name:gsub("%.exe$", "")
end

local function url_decode(value)
  if not value then
    return nil
  end
  return (value:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function normalize_cwd(raw_cwd)
  if not raw_cwd then
    return nil
  end

  local cwd = tostring(raw_cwd)
  cwd = cwd:gsub("[?#].*$", "")

  if cwd:match("^file://") or cwd:match("^ssh://") then
    cwd = cwd:gsub("^%a+://[^/]*", "")
  end

  cwd = url_decode(cwd)
  cwd = cwd:gsub("/$", "")

  if cwd == "" then
    return nil
  end

  return cwd
end

local function cwd_from_title(title)
  title = title or ""
  return title:match("Yazi:%s*(/.+)$")
    or title:match("Yazi%s+(.*/.+)$")
    or title:match("(%~/.+)$")
    or title:match("(/Users/[^%s]+/.+)$")
end

local function basename(path)
  if not path or path == "" then
    return ""
  end
  return path:match("([^/]+)$") or path
end

local function clean_segment(segment)
  local cleaned = (segment or ""):gsub("^[%d_]+", "")
  return cleaned ~= "" and cleaned or segment
end

local function current_dir_name(cwd, active_title)
  cwd = normalize_cwd(cwd) or cwd_from_title(active_title)

  if not cwd then
    return "cwd?"
  end

  cwd = cwd:gsub("^" .. HOME, "~")

  if cwd == "~" then
    return "~"
  end

  if cwd:match("_01_IAP") then
    local tail = cwd:match("_01_IAP/(.+)$") or basename(cwd)
    return clean_segment(basename(tail))
  end

  if cwd:match("IAP%-LACS") then
    local tail = cwd:match("IAP%-LACS/(.+)$") or basename(cwd)
    return clean_segment(basename(tail))
  end

  if cwd:match("%.config/wezterm") then
    local tail = cwd:match("%.config/wezterm/(.+)$")
    return tail and clean_segment(basename(tail)) or "wezterm"
  end

  if cwd:match("^~/Downloads") then
    return clean_segment(basename(cwd))
  end

  if cwd:match("^~/Documents") then
    local rest = cwd:match("^~/Documents/(.+)$")
    if not rest then
      return "Documents"
    end
    return clean_segment(basename(rest))
  end

  return clean_segment(basename(cwd))
end

local function is_admin_title(title)
  return title:match("^Administrator: ") ~= nil or title:match("%(Admin%)") ~= nil
end

local function detect_context(process_name, static_title, active_title, cwd, domain_name, tab_id)
  static_title = static_title or ""
  active_title = active_title or ""
  cwd = cwd or ""
  domain_name = domain_name or ""

  if manual_titles[tab_id] then
    return icons.manual
  end

  if static_title:len() > 0 then
    return icons.manual
  end

  if process_name == "codex" or active_title:lower():match("codex") or cwd:lower():match("codex") then
    return icons.codex
  elseif domain_name:upper():match("IAP") or active_title:upper():match("IAP") then
    return icons.iap
  elseif process_name == "ssh" then
    return icons.ssh
  elseif process_name == "expect" then
    return icons.ssh
  elseif process_name == "bash" and active_title:match("login%d+") then
    return icons.hpc
  elseif process_name == "nvim" or active_title:match("nvim") then
    return icons.nvim
  elseif process_name == "lazygit" or active_title:match("lazygit") then
    return icons.git
  elseif process_name == "yazi" or active_title:match("Yazi") then
    return icons.yazi
  elseif active_title == "ranger" or process_name == "ranger" then
    return icons.ranger
  elseif cwd:match("_01_IAP") or cwd:match("IAP%-LACS") or active_title:match("IAP") then
    return icons.iap
  elseif cwd:match("%.git") or active_title:match("git") then
    return icons.git
  elseif process_name == "zsh" or process_name == "bash" then
    return icons.mac
  end

  if process_name:len() > 0 then
    return icons.code
  end

  return icons.shell
end

local function text_width(text)
  return wezterm.column_width(text or "")
end

local function truncate(text, max_width)
  if max_width <= 0 then
    return ""
  end

  return wezterm.truncate_right(text, max_width)
end

local function fit_pill_text(icon, path, has_admin, max_width)
  local identity = has_admin and (GLYPH_ADMIN .. icon) or icon
  local spacious_prefix = "  " .. identity .. "  "
  local spacious_suffix = "  "
  local spacious_fixed_width = text_width(spacious_prefix .. spacious_suffix)

  if max_width >= spacious_fixed_width then
    return spacious_prefix
      .. truncate(path, max_width - spacious_fixed_width)
      .. spacious_suffix
  end

  local compact_prefix = " " .. identity .. " "
  local compact_suffix = " "
  local compact_fixed_width = text_width(compact_prefix .. compact_suffix)

  if max_width >= compact_fixed_width then
    return compact_prefix
      .. truncate(path, max_width - compact_fixed_width)
      .. compact_suffix
  end

  if text_width(identity) <= max_width then
    return identity
  end

  if text_width(icon) <= max_width then
    return icon
  end

  return string.rep(" ", max_width)
end

local function render_tab(tab, hover, max_width)
  local cells = {}
  local state = "default"
  if tab.is_active then
    state = "active"
  elseif hover then
    state = "hover"
  end

  local colors = palette[state]
  local pane = tab.active_pane
  local process_name = clean_process_name(pane.foreground_process_name)
  local active_title = pane.title or ""
  local cwd = normalize_cwd(pane.current_working_dir) or cwd_from_title(active_title)
  local domain_name = pane.domain_name or ""
  local admin = is_admin_title(active_title)
  local icon = detect_context(
    process_name,
    tab.tab_title,
    active_title,
    cwd,
    domain_name,
    tab.tab_id
  )
  local path = current_dir_name(cwd, active_title)
  max_width = math.max(0, math.floor(max_width or 0))

  local left_width = text_width(GLYPH_LEFT)
  local right_width = text_width(GLYPH_RIGHT)
  local edge_width = left_width + right_width

  if max_width < edge_width then
    if max_width > 0 then
      push(
        cells,
        colors.grad_bg_from,
        colors.grad_fg_from,
        string.rep(" ", max_width),
        colors.intensity
      )
    end
    return cells
  end

  local gap = ""
  if max_width >= edge_width + text_width(icon) + 1 then
    gap = " "
  end

  local pill_width = max_width - edge_width - text_width(gap)
  local pill_text = fit_pill_text(icon, path, admin, pill_width)

  if gap ~= "" then
    push(cells, colors.outer_bg, colors.outer_bg, gap)
  end
  push(cells, colors.outer_bg, colors.grad_bg_from, GLYPH_LEFT, "Bold")
  push_gradient(
    cells,
    pill_text,
    colors.grad_bg_from,
    colors.grad_bg_to,
    colors.grad_fg_from,
    colors.grad_fg_to,
    colors.intensity
  )
  push(cells, colors.outer_bg, colors.grad_bg_to, GLYPH_RIGHT, "Bold")

  return cells
end

M.setup = function()
  local enable_tab_bar = true

  wezterm.on("tabs.manual-update-tab-title", function(window, pane)
    window:perform_action(
      wezterm.action.PromptInputLine({
        description = wezterm.format({
          { Foreground = { Color = "#9be7ff" } },
          { Attribute = { Intensity = "Bold" } },
          { Text = "Rename tab" },
        }),
        action = wezterm.action_callback(function(_, _, line)
          if line and line:len() > 0 then
            local active_tab = window:active_tab()
            if active_tab then
              manual_titles[active_tab:tab_id()] = line
            end
          end
        end),
      }),
      pane
    )
  end)

  wezterm.on("tabs.reset-tab-title", function(window, _pane)
    local active_tab = window:active_tab()
    if active_tab then
      manual_titles[active_tab:tab_id()] = nil
    end
  end)

  wezterm.on("tabs.toggle-tab-bar", function(window, _pane)
    enable_tab_bar = not enable_tab_bar
    window:set_config_overrides({ enable_tab_bar = enable_tab_bar })
  end)

  wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, hover, max_width)
    return render_tab(tab, hover, max_width)
  end)
end

return M
