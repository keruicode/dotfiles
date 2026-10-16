local wezterm = require('wezterm')
local platform = require('utils.platform')
local backdrops = require('utils.backdrops')
local act = wezterm.action

local mod = {}

if platform.is_mac then
   mod.SUPER = 'SUPER'
   mod.SUPER_REV = 'SUPER|CTRL'
elseif platform.is_win or platform.is_linux then
   mod.SUPER = 'ALT' -- to not conflict with Windows key shortcuts
   mod.SUPER_REV = 'ALT|CTRL'
end

-- stylua: ignore
local keys = {
   -- misc/useful --
   { key = 'F1', mods = 'NONE', action = 'ActivateCopyMode' },
   { key = 'F2', mods = 'NONE', action = act.ActivateCommandPalette },
   { key = 'F3', mods = 'NONE', action = act.ShowLauncher },
   { key = 'f', mods = 'CMD',    action = act.ToggleFullScreen },
-- 添加这一行，让 Cmd+r 发送 Ctrl+r
   { key = 'r', mods = 'CMD', action = act.SendKey { key = 'r', mods = 'CTRL' } },
--   {
--      key = 'u',
--      mods = mod.SUPER,
--      action = wezterm.action.QuickSelectArgs({
--         label = 'open url',
--         patterns = {
--            '\\((https?://\\S+)\\)',
--            '\\[(https?://\\S+)\\]',
--            '\\{(https?://\\S+)\\}',
--            '<(https?://\\S+)>',
--            '\\bhttps?://\\S+[)/a-zA-Z0-9-]+'
--         },
--         action = wezterm.action_callback(function(window, pane)
--            local url = window:get_selection_text_for_pane(pane)
--            wezterm.log_info('opening: ' .. url)
--            wezterm.open_with(url)
--         end),
--      }),
--   },

   -- cursor movement --
   { key = 'a',  mods = mod.SUPER,     action = act.SendString '\x1bOH' },
   { key = 'e', mods = mod.SUPER,     action = act.SendString '\x1bOF' },
   { key = 'Backspace',  mods = mod.SUPER,     action = act.SendString '\x15' },

   -- copy/paste --
   { key = 'c',          mods = 'CMD',  action = act.CopyTo('Clipboard') },
   { key = 'v',          mods = 'CMD',  action = act.PasteFrom('Clipboard') },

   -- tabs --
   -- tabs: spawn+close
   { key = 't',          mods = mod.SUPER,     action = act.SpawnTab('DefaultDomain') },
   { key = 't',          mods = mod.SUPER_REV, action = act.SpawnTab({ DomainName = 'WSL:Mac' }) },
   { key = 'D',          mods = 'CMD|SHIFT', action = act.CloseCurrentTab({ confirm = false }) },

   -- tabs: navigation
   { key = 'n',          mods = 'CMD',     action = act.ActivateTabRelative(-1) },
   { key = 'i',          mods = 'CMD',     action = act.ActivateTabRelative(1) },
   -- { key = 'N',          mods = 'CMD|SHIFT', action = act.MoveTabRelative(-1) },
   -- { key = 'I',         mods = 'CMD|SHIFT', action = act.MoveTabRelative(1) },

   -- tab: title
   { key = '0',          mods = mod.SUPER,     action = act.EmitEvent('tabs.manual-update-tab-title') },
   { key = '0',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.reset-tab-title') },

   -- tab: hide tab-bar
   { key = '9',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.toggle-tab-bar'), },

   -- tab: hide the WezTerm application
   { key = 'h', mods = 'CMD', action = wezterm.action.HideApplication },

   -- window --
   -- spawn windows
   { key = 'Enter',          mods = mod.SUPER,     action = act.SpawnWindow },

   -- background controls --
   {
      key = 'b',
      mods = 'ALT|CTRL|SHIFT',
      action = wezterm.action_callback(function(window, pane)
         backdrops:show_category_selector(window, pane)
      end),
   },
   {
      key = [[/]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:random(window)
      end),
   },
   {
      key = [[,]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_back(window)
      end),
   },
   {
      key = [[.]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_forward(window)
      end),
   },
   {
      key = [[/]],
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, pane)
         backdrops:show_image_selector(window, pane)
      end),
   },
   {
      key = 'b',
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:toggle_category(window)
      end),
   },
   {
      key = 'b',
      mods = mod.SUPER_REV .. '|SHIFT',
      action = wezterm.action_callback(function(window, pane)
         backdrops:show_category_selector(window, pane)
      end),
   },
   {
      key = 'b',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:toggle_focus(window)
      end)
   },

   -- panes --
   -- panes: split panes
   {
      key = [[\]],
      mods = mod.SUPER,
      action = act.SplitVertical({ domain = 'CurrentPaneDomain' }),
   },
   {
      key = [[\]],
      mods = "CMD|SHIFT",
      action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
   },

   -- panes: zoom+close pane
   -- { key = 'Enter', mods = mod.SUPER,     action = act.TogglePaneZoomState },
   { key = 'w',     mods = mod.SUPER,     action = act.CloseCurrentPane({ confirm = false }) },

   -- panes: navigation
   { key = 'u',     mods = "CMD|SHIFT", action = act.ActivatePaneDirection('Up') },
   { key = 'e',     mods = "CMD|SHIFT", action = act.ActivatePaneDirection('Down') },
   { key = 'n',     mods = "CMD|SHIFT", action = act.ActivatePaneDirection('Left') },
   { key = 'i',     mods = "CMD|SHIFT", action = act.ActivatePaneDirection('Right') },
   {
      key = 'p',
      mods = mod.SUPER_REV,
      action = act.PaneSelect({ alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus' }),
   },

  -- cmd+l: clear terminal and scroll active
  {
      key = "l",
      mods = "CMD",
      action = wezterm.action.Multiple({
          --wezterm.action.ClearScrollback("ScrollbackOnly"),
          wezterm.action.SendString("\x0c"),
      }),
  },


   -- key-tables --
   -- resizes fonts
   {
      key = 'f',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_font',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
   -- resize panes
   {
      key = 'p',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_pane',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
}

-- stylua: ignore
local key_tables = {
   resize_font = {
      { key = 'k',      action = act.IncreaseFontSize },
      { key = 'j',      action = act.DecreaseFontSize },
      { key = 'r',      action = act.ResetFontSize },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
   },
   resize_pane = {
      { key = 'k',      action = act.AdjustPaneSize({ 'Up', 1 }) },
      { key = 'j',      action = act.AdjustPaneSize({ 'Down', 1 }) },
      { key = 'h',      action = act.AdjustPaneSize({ 'Left', 1 }) },
      { key = 'l',      action = act.AdjustPaneSize({ 'Right', 1 }) },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
   },
}

local mouse_bindings = {
   -- Ctrl-click will open the link under the mouse cursor
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CMD',
      action = act.OpenLinkAtMouseCursor,
   },
}

-- 增加 cmd+1、cmd+2 等快捷键来切换标签页
for i = 1, 9 do
  table.insert(keys, {
    key = tostring(i),
    mods = 'CMD',
    action = act.ActivateTab(i - 1)
  })
end


return {
   disable_default_key_bindings = true,
   leader = { key = 'Space', mods = mod.SUPER_REV },
   keys = keys,
   key_tables = key_tables,
   mouse_bindings = mouse_bindings,
}
